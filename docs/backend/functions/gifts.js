// 応援（投げ銭）/ワープの購入を検証して台帳に記帳する Callable Functions（雛形）。
//
// フロー: アプリで IAP 購入 → 本関数にレシート/トークンを渡す
//   → Apple/Google で検証 → gifts 記帳 → balances/{toUid} に net を加算
//   → 二重計上防止（transactionId をドキュメントIDに使用）
//
// ※ 本番運用前にエラー処理・返金(リフ ァンド)・通知連携・レート制限を追加すること。

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('./admin');

// 商品ID → 金額（円）。投げ銭のみ。ワープは収益化対象外なら別管理。
const TIP_AMOUNT = {
  tip_coffee_100: 100,
  tip_coffee_300: 300,
  tip_coffee_500: 500,
};

// 手数料率（docs/payouts.md と一致させる）。
const STORE_FEE = 0.30; // Apple/Google（実際はプラン/国で変動）
const PLATFORM_FEE = 0.10; // 運営

// ---- Apple レシート検証（簡易・verifyReceipt 版）----
// 本番は App Store Server API（JWT）推奨。ここでは最小実装。
async function verifyApple(receiptData, productId) {
  const body = {
    'receipt-data': receiptData,
    password: process.env.APPLE_SHARED_SECRET,
    'exclude-old-transactions': true,
  };
  async function post(url) {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return r.json();
  }
  let res = await post('https://buy.itunes.apple.com/verifyReceipt');
  if (res.status === 21007) {
    // サンドボックスのレシート → サンドボックスへ。
    res = await post('https://sandbox.itunes.apple.com/verifyReceipt');
  }
  if (res.status !== 0) throw new HttpsError('failed-precondition', 'apple verify failed: ' + res.status);
  const items = [
    ...(res.receipt?.in_app || []),
    ...(res.latest_receipt_info || []),
  ];
  const tx = items.find((i) => i.product_id === productId);
  if (!tx) throw new HttpsError('failed-precondition', 'product not in receipt');
  return tx.transaction_id;
}

// ---- Google Play 検証（雛形）----
// 実際は googleapis (androidpublisher) で purchases.products.get を検証。
async function verifyGoogle(purchaseToken, productId) {
  // TODO: androidpublisher で検証し、purchaseState===0(購入済) を確認。
  // ここでは雛形のため purchaseToken を一意IDとして扱う。
  if (!purchaseToken) throw new HttpsError('invalid-argument', 'no token');
  return purchaseToken;
}

exports.verifyAndCreditGift = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'login required');

  const { platform, productId, receiptData, purchaseToken, pinId, toUid } =
    req.data || {};
  if (!TIP_AMOUNT[productId]) {
    throw new HttpsError('invalid-argument', 'unknown product');
  }
  if (!toUid || toUid === uid) {
    throw new HttpsError('failed-precondition', '自分への応援はできません');
  }

  // 1) レシート検証 → 一意な取引ID取得。
  const txId =
    platform === 'ios'
      ? await verifyApple(receiptData, productId)
      : await verifyGoogle(purchaseToken, productId);

  const gross = TIP_AMOUNT[productId];
  const storeFee = Math.round(gross * STORE_FEE);
  const platformFee = Math.round(gross * (1 - STORE_FEE) * PLATFORM_FEE);
  const net = gross - storeFee - platformFee;

  // 2) 二重計上防止：gifts/{txId} を作成（既存なら冪等に終了）。
  const giftRef = db.collection('gifts').doc(`${platform}_${txId}`);
  const balRef = db.collection('balances').doc(toUid);

  await db.runTransaction(async (t) => {
    const existing = await t.get(giftRef);
    if (existing.exists) return; // 既に処理済み
    t.set(giftRef, {
      pinId: pinId || null,
      fromUid: uid,
      toUid,
      productId,
      gross,
      storeFee,
      platformFee,
      net,
      currency: 'JPY',
      platform,
      createdAt: FieldValue.serverTimestamp(),
      status: 'credited',
    });
    t.set(
      balRef,
      {
        pending: FieldValue.increment(net),
        lifetime: FieldValue.increment(net),
      },
      { merge: true }
    );
    // ピンの集計（表示用）。
    if (pinId) {
      t.set(
        db.collection('pins').doc(pinId),
        {
          totalTipAmount: FieldValue.increment(gross),
          giftCount: FieldValue.increment(1),
        },
        { merge: true }
      );
    }
  });

  return { ok: true, net, gross };
});
