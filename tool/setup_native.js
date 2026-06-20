// `flutter create .` の後に実行して、Android/iOS のネイティブ設定を自動投入する。
//   - 位置情報・マイク・写真ライブラリ権限
//   - 表示名「SounDrop」
// 地図は OpenStreetMap（flutter_map）なので Maps APIキーは不要。
// 何度実行しても重複しない（idempotent）。
//
// 実行: node tool/setup_native.js

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const APP_NAME = 'SounDrop';

function read(p) {
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
}
function write(p, s) {
  fs.writeFileSync(p, s);
  console.log('  updated', path.relative(ROOT, p));
}
function skip(reason) {
  console.log('  skip:', reason);
}

// ---------------- Android ----------------
function setupAndroid() {
  console.log('[Android]');
  const manifestPath = path.join(
    ROOT, 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
  let m = read(manifestPath);
  if (!m) return skip('AndroidManifest.xml が無い（先に flutter create . を実行）');

  // 権限（<manifest ...> の直後に追加）
  const perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.RECORD_AUDIO',
  ];
  for (const p of perms) {
    if (!m.includes(p)) {
      m = m.replace(/(<manifest[^>]*>)/,
        `$1\n    <uses-permission android:name="${p}"/>`);
    }
  }

  // 地図は OpenStreetMap（flutter_map）なので Maps APIキーは不要。

  // 表示名
  m = m.replace(/android:label="[^"]*"/, `android:label="${APP_NAME}"`);

  write(manifestPath, m);
}

// ---------------- iOS ----------------
function setupIos() {
  console.log('[iOS]');
  const plistPath = path.join(ROOT, 'ios', 'Runner', 'Info.plist');
  let plist = read(plistPath);
  if (!plist) return skip('Info.plist が無い（先に flutter create . を実行）');

  const entries = [
    ['NSLocationWhenInUseUsageDescription',
      '近くの音声ドロップを解禁し、現在地に投稿するために使用します'],
    ['NSMicrophoneUsageDescription', '音声を録音してドロップするために使用します'],
    ['NSPhotoLibraryUsageDescription', 'プロフィール画像の設定に使用します'],
    ['CFBundleDisplayName', APP_NAME],
  ];
  for (const [key, val] of entries) {
    if (plist.includes(`<key>${key}</key>`)) {
      // CFBundleDisplayName は値を更新
      if (key === 'CFBundleDisplayName') {
        plist = plist.replace(
          /(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)/,
          `$1${val}$2`);
      }
      continue;
    }
    plist = plist.replace(/(\s*)<\/dict>\s*<\/plist>\s*$/,
      `\n\t<key>${key}</key>\n\t<string>${val}</string>\n</dict>\n</plist>\n`);
  }
  // 輸出コンプライアンス：標準暗号(HTTPS)のみ → 非該当（boolean）。
  if (!plist.includes('ITSAppUsesNonExemptEncryption')) {
    plist = plist.replace(/(\s*)<\/dict>\s*<\/plist>\s*$/,
      `\n\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n</dict>\n</plist>\n`);
  }
  write(plistPath, plist);
  // 地図は OpenStreetMap（flutter_map）なので AppDelegate への Maps 初期化は不要。
}

console.log('SounDrop native setup（地図は OpenStreetMap／APIキー不要）');
setupAndroid();
setupIos();
console.log('完了。権限と表示名を設定しました。');
