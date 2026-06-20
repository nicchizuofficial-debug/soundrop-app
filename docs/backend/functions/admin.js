// Firebase Admin の初期化を一度だけ行い、Firestore を共有する。
const { initializeApp, getApps } = require('firebase-admin/app');
if (!getApps().length) initializeApp();
const { getFirestore } = require('firebase-admin/firestore');

module.exports = { db: getFirestore() };
