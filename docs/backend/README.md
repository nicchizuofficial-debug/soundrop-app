# Firebase バックエンド有効化ガイド

デフォルトはローカル永続化（`LocalPinDataSource`）で、Firebase 設定なしでも
アプリ／デモが動きます。他ユーザー投稿のリアルタイム同期を行いたい場合に、
以下の手順で Firestore 実装へ切り替えます。

## 収益化（応援の検証・台帳・出金）
`functions/` に以下を同梱（雛形）。詳細は [docs/payouts.md](../payouts.md)。
- `gifts.js`：`verifyAndCreditGift`（IAPレシート検証→`gifts`記帳→`balances`加算）
- `stripe.js`：`createConnectOnboardingLink` / `getBalance` / `requestPayout`（Stripe Connect）
- アプリ側：`GiftBackend`/`PayoutService` は `lib/services/firebase_*.dart` に同梱済み
  （`USE_FIREBASE=true` で自動使用）

必要な環境変数（Secret Manager 等で設定）:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set APPLE_SHARED_SECRET   # iOS verifyReceipt 用
# 任意: APP_RETURN_URL / APP_REFRESH_URL（Connect オンボーディングの戻り先）
```
依存追加：`cd functions && npm i`（stripe を含む）。リージョンは `asia-northeast1` を想定。

> ⚠ 出金（送金）は **資金決済法・税務**等の確認後に本番有効化すること。
> v1 は「換金なし（見える化のみ）」を推奨。

## 設計

`PinDataSource` インターフェース（[lib/services/pin_data_source.dart](../../lib/services/pin_data_source.dart)）を
2通りで実装します。

```
PinProvider ──> PinDataSource ──┬── LocalPinDataSource  (SharedPreferences / 既定)
                                └── FirebasePinDataSource (Firestore / 本ガイド)
```

UI・状態管理は実装に依存しないため、切り替えは `createPinDataSource()`
（[lib/app_config.dart](../../lib/app_config.dart)）の1行だけです。

## 手順（コードは組み込み済み。あなたの作業は設定のみ）

Firebase 実装は **すでに `lib/services/firebase_*.dart` に組み込み済み**で、
`app_config.dart` の `createX()` が `USE_FIREBASE=true` のとき自動でそれらを使います。
`main.dart` も `useFirebase` 時に `Firebase.initializeApp()` を呼びます。

あなたの作業：
1. Firebase プロジェクト作成（Console）→ **Authentication: メール/パスワード を有効化**、
   **Firestore**・**Storage** を作成。
2. 依存解決：`flutter pub get`（firebase_* は pubspec 追加済み）。
3. ネイティブ構成を生成：
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure   # GoogleService-Info.plist / google-services.json を配置
   ```
4. 起動／ビルド：
   ```bash
   flutter run --dart-define=USE_FIREBASE=true
   # 本番: flutter build ipa --dart-define=USE_FIREBASE=true --dart-define=MAPTILER_KEY=...
   ```
5. 収益化を使う場合：`functions/` をデプロイし Secrets を設定（下記「収益化」節）。

> Web で使う場合のみ `firebase_options.dart` を生成し、`main.dart` の
> `Firebase.initializeApp()` に `options: DefaultFirebaseOptions.currentPlatform` を渡してください。
> モバイルはネイティブ設定ファイルだけで動きます。

## Firestore セキュリティルール（最小例）

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /pins/{pinId} {
      allow read: if true;            // 公開フィルタはクライアント側 visibleAt で実施
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null;
    }
  }
}
```

> 本番では公開時刻(visibleAt)前のピン座標をサーバー側で隠す（Cloud Functions で
> マスクする等）と、防犯目的のタイムロックがより強固になります。

## 本番化のための残課題

- `isUnlocked` / `isOwn` をユーザー単位サブコレクションへ分離。
- 投げ銭・ワープ解禁数の加算を `FieldValue.increment` / トランザクション化。
- 課金レシートのサーバー側検証（Cloud Functions）後に配布。
