// Stripe Connect（Express）でのクリエイター出金 雛形（Callable Functions）。
//
// 環境変数: STRIPE_SECRET_KEY（テストは sk_test_..., 本番 sk_live_...）
//   firebase functions:config もしくは Secret Manager で設定。
// 必要パッケージ: stripe
//
// 提供関数:
//   createConnectOnboardingLink → Express口座作成＋本人確認(KYC)のURLを返す
//   getBalance                  → balances/{uid} を返す（pending/available）
//   requestPayout               → pending を Stripe へ送金（連結口座へ transfer）
//
// ※ 法務（資金移動業/資金決済法・税務）の確認後に本番有効化すること。

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('./admin');
const Stripe = require('stripe');

function stripe() {
  return Stripe(process.env.STRIPE_SECRET_KEY);
}

// アプリのスキーム（オンボーディング完了後の戻り先）。
const RETURN_URL = process.env.APP_RETURN_URL || 'https://sounddrop.app/connect/return';
const REFRESH_URL = process.env.APP_REFRESH_URL || 'https://sounddrop.app/connect/refresh';

exports.createConnectOnboardingLink = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'login required');
  const s = stripe();

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  let accountId = snap.data()?.stripeAccountId;

  // 未作成なら Express アカウントを作成（日本）。
  if (!accountId) {
    const acct = await s.accounts.create({
      type: 'express',
      country: 'JP',
      capabilities: { transfers: { requested: true } },
      business_type: 'individual',
      metadata: { uid },
    });
    accountId = acct.id;
    await userRef.set({ stripeAccountId: accountId }, { merge: true });
  }

  // 本人確認(KYC)等のオンボーディングリンク。
  const link = await s.accountLinks.create({
    account: accountId,
    refresh_url: REFRESH_URL,
    return_url: RETURN_URL,
    type: 'account_onboarding',
  });
  return { url: link.url };
});

exports.getBalance = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'login required');
  const bal = (await db.collection('balances').doc(uid).get()).data() || {};
  return {
    pending: bal.pending || 0,
    available: bal.available || 0,
    lifetime: bal.lifetime || 0,
    currency: 'JPY',
  };
});

exports.requestPayout = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'login required');
  const s = stripe();

  const userSnap = await db.collection('users').doc(uid).get();
  const accountId = userSnap.data()?.stripeAccountId;
  if (!accountId) {
    throw new HttpsError('failed-precondition', '受け取り設定が未完了です');
  }
  const acct = await s.accounts.retrieve(accountId);
  if (!acct.payouts_enabled) {
    throw new HttpsError('failed-precondition', '本人確認が未完了です');
  }

  const balRef = db.collection('balances').doc(uid);
  const amount = await db.runTransaction(async (t) => {
    const b = (await t.get(balRef)).data() || {};
    const payable = b.pending || 0;
    const MIN = 1000; // 最低出金額（円）
    if (payable < MIN) {
      throw new HttpsError('failed-precondition', `最低出金額は¥${MIN}です`);
    }
    t.set(balRef, { pending: 0, paidOut: FieldValue.increment(payable) },
        { merge: true });
    return payable;
  });

  // 連結口座へ送金（JPYはゼロ十進通貨：そのままの整数）。
  const transfer = await s.transfers.create({
    amount,
    currency: 'jpy',
    destination: accountId,
    metadata: { uid },
  });
  return { ok: true, amount, transferId: transfer.id };
});
