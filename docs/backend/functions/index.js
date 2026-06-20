// SounDrop 通報モデレーション Cloud Functions（設計雛形 / Firebase Functions v2）
//
// 目的:
//  - 通報が一定数を超えたピンを自動で非表示（pins/{id}.hidden = true）
//  - 「待ち伏せ・付きまとい(stalking)」は1件でも即エスカレーション
//  - 重複通報（同一ユーザー×同一ピン）はカウントしない
//
// デプロイ:
//   cd docs/backend/functions && npm i && firebase deploy --only functions
//
// 想定コレクション（docs/moderation.md 参照）:
//   reports/{reportId} : { pinId, reportedOwnerId, reporterId, reason, status, createdAt }
//   pins/{pinId}       : { ..., hidden: bool, reportCount: number }
//   users/{uid}        : { actionedCount, blockedUntil, ... }

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { FieldValue } = require('firebase-admin/firestore');
const { db } = require('./admin');

// 収益化（投げ銭検証・台帳）と出金（Stripe Connect）の関数を公開。
Object.assign(exports, require('./gifts'), require('./stripe'));

// 自動非表示のしきい値（ユニーク通報者数）。
const AUTO_HIDE_THRESHOLD = 3;

exports.onReportCreated = onDocumentCreated('reports/{reportId}', async (event) => {
  const report = event.data?.data();
  if (!report) return;
  const { pinId, reason, reportedOwnerId } = report;
  if (!pinId) return;

  // 同一ピンへの通報を集計（ユニークな通報者数を数える）。
  const snap = await db.collection('reports').where('pinId', '==', pinId).get();
  const reporters = new Set();
  let hasStalking = false;
  snap.forEach((d) => {
    const r = d.data();
    if (r.reporterId) reporters.add(r.reporterId);
    if (r.reason === 'stalking') hasStalking = true;
  });
  const uniqueReporters = reporters.size;

  const pinRef = db.collection('pins').doc(pinId);

  // 待ち伏せは即エスカレーション、それ以外は閾値で自動非表示。
  const shouldHide = hasStalking || uniqueReporters >= AUTO_HIDE_THRESHOLD;

  await pinRef.set(
    {
      reportCount: uniqueReporters,
      hidden: shouldHide,
      lastReportedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // 重大カテゴリは審査キューを優先扱いに（運営ツールでフィルタ）。
  if (hasStalking) {
    await event.data.ref.set({ priority: 'high' }, { merge: true });
  }

  // 作者の累計被通報数を加算（累積でアカウント制限の判断材料に）。
  if (reportedOwnerId) {
    await db.collection('users').doc(reportedOwnerId).set(
      { reportedCount: FieldValue.increment(1) },
      { merge: true }
    );
  }
});

// 運営が status を 'dismissed' に更新したら自動非表示を解除する例。
exports.onReportUpdated = require('firebase-functions/v2/firestore')
  .onDocumentUpdated('reports/{reportId}', async (event) => {
    const after = event.data?.after.data();
    if (!after || after.status !== 'dismissed') return;
    // 同ピンに他の有効な通報が無ければ表示を戻す（簡易例）。
    const snap = await db.collection('reports')
      .where('pinId', '==', after.pinId).get();
    const stillFlagged = snap.docs.some((d) => {
      const r = d.data();
      return r.status !== 'dismissed';
    });
    if (!stillFlagged) {
      await db.collection('pins').doc(after.pinId)
        .set({ hidden: false }, { merge: true });
    }
  });
