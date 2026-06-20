# SounDrop（MVPプロトタイプ）

時間差・位置情報連動型の音声ドロップアプリ。防犯のための **タイムロック（時間差公開）** と
**GPSアンロック（現地解禁）**、個人開発で実現可能なマネタイズ（**ワープチケット** / **投げ銭**）を実装。

> アイコン/スプラッシュはダークネイビー＋ピンク→ブルーのブランドカラー。
> アイコン画像は `tool/generate_icon.js`（Nodeのみ・依存ゼロ）で生成しています。

## 構成

| ファイル | 役割 |
|---|---|
| `lib/models/pin_model.dart` | データモデル（座標・公開時刻・投げ銭・ギフト数など） |
| `lib/data/dummy_pins.dart` | デモ用ダミーピン（仙台駅周辺・公開済み/未公開を混在） |
| `lib/state/pin_provider.dart` | 状態管理＋ロジック（時間フィルタ/距離判定/解禁/ドロップ/課金/同期） |
| `lib/services/pin_data_source.dart` | データソース抽象（ローカル/Firebase を差し替え） |
| `lib/services/local_pin_data_source.dart` | SharedPreferences 実装（既定・オフライン） |
| `lib/services/settings_store.dart` | 所持チケット・ブロック/通報の保存 |
| `lib/services/auth_service.dart` | 匿名認証の抽象＋ローカル実装（uid 発行） |
| `lib/services/purchase_gateway.dart` / `purchase_service.dart` | 課金の抽象と in_app_purchase 実装 |
| `lib/utils/geo_utils.dart` | Haversine 距離計算（純粋関数・テスト可能） |
| `lib/app_config.dart` | バックエンド/認証の選択（`createPinDataSource` / `createAuthService`） |
| `lib/theme/app_theme.dart` | アイコン準拠のダークテーマ＋ブランドグラデーション |
| `lib/widgets/sound_drop_logo.dart` | ピン×波形のロゴ（CustomPaint・画像不要） |
| `lib/widgets/app_icons.dart` | ブランドグラデのアイコン（ワープ/鍵/応援/現在地） |
| `lib/widgets/mini_waveform.dart` | ミニ波形プレビュー（録音実波形 or IDベース装飾） |
| `lib/widgets/map_pin.dart` | 地図ピン（状態別・ブランドグラデのWidgetマーカー） |
| `lib/screens/map_screen.dart` | 地図・位置情報バナー・ボトムシート（ワープ/投げ銭/通報）・導線 |
| `lib/screens/drop_screen.dart` | 録音・波形・最大60秒・試聴・タイムロック設定 |
| `lib/screens/my_drops_screen.dart` | マイドロップ管理＋公開中一覧（再生/削除/通報/ブロック） |
| `lib/screens/moderation_screen.dart` | 運営用モデレーション（通報一覧・審査ステータス・投稿削除） |
| `lib/screens/splash_screen.dart` | 起動スプラッシュ（ロゴ→認証/地図へ振り分け） |
| `lib/screens/auth_screen.dart` | メール登録／ログイン（必須） |
| `lib/screens/accounts_screen.dart` | アカウントを探してフォロー／解除 |
| `lib/services/auth_service.dart` / `lib/models/app_user.dart` | メール認証とユーザーモデル |
| `lib/widgets/audio_player_widget.dart` | just_audio 再生プレイヤー |
| `lib/widgets/waveform.dart` | 録音中の振幅波形（CustomPaint） |
| `test/` | 単体＋ウィジェットテスト（geo/model/provider/画面操作、フェイク使用） |
| `docs/backend/` | Firebase(Firestore/Auth) 実装と有効化ガイド |
| `demo/index.html` | **ブラウザで動くデモ**（Flutter不要・すぐ確認できる） |

## 認証・安全機能・デザイン

- **匿名認証**: 起動時に `AuthService` で匿名uidを取得。投稿の所有者を `ownerId` で判定し、
  マルチユーザー（Firebase同期）でも「自分の投稿」を正しく扱う（`PinProvider.isMine`）。
- **通報/ブロック**: 他人の投稿を通報（即時非表示）・投稿者をブロック（以降非表示）。
  `SettingsStore` に永続化し、`visiblePins` で安全フィルタ。自分の投稿は保護される。
- **位置情報権限のUX**: 許可なし/サービスオフ時に地図上部へ説明バナーを表示し、再許可・設定誘導。
- **デザイン**: アプリアイコン（ダークネイビー＋ピンク→ブルー）に合わせたテーマと
  グラデーションロゴ／ボタンを `lib/theme` ・ `SoundDropLogo` で実装。

## アカウント＆フォロー（必須）

- **アカウント登録必須**：起動時に [auth_screen.dart](lib/screens/auth_screen.dart) で
  新規登録（表示名・**ログインID（一意）**・メール任意・パスワード）／ログイン（**ログインID＋パスワード**）。
  [auth_service.dart](lib/services/auth_service.dart) のローカル実装、Firebase版は docs。
- **セッション保持**：ログイン状態を維持し、**最終アクセスから30日**未アクセスで失効
  （`LocalAuthService.sessionTtl`、アクセス毎に延長）。未ログインは
  [splash_screen.dart](lib/screens/splash_screen.dart) が認証画面へ誘導。
- **フォロー中だけ表示**：`visiblePins` は **自分の投稿＋フォロー中アカウントの公開ドロップのみ**。
  [accounts_screen.dart](lib/screens/accounts_screen.dart)（地図の👤）でフォロー、ピン詳細からも解除可能。
  フォロー先が無いときは地図に誘導カードを表示。`SettingsStore.loadFollowing(uid)` でユーザー単位に永続化。
- AppBar のアカウントメニューから**ログアウト**。

## 実装済みのコア体験

1. **時間フィルタリング** … フォロー中の `now >= visibleAt` のピンのみ地図に描画（`PinProvider.visiblePins`）。
2. **距離計算 / 50m判定** … `Geolocator.distanceBetween` で半径内かを判定（`isWithinUnlockRange`）。
3. **マネタイズUI（モック）**
   - 遠方ピンをタップ → 「歩いて近づく」/「ワープチケットで解禁」を選ぶボトムシート。
   - 解禁済みピンをタップ → 再生ボタン＋「応援を贈る（投げ銭）」ボタン。
4. **保存（お気に入り）** … 解禁したドロップを保存し「ピン一覧 > 保存済み」タブで再生
   （`PinProvider.toggleSaved`、`SettingsStore` に永続化）。
5. **アイコン** … 地図ピンはブランドグラデ本体＋状態色グリフ（鍵＝藍/解禁＝青緑/公開待ち＝橙）。
   解禁状態はドット付きチップで表示。

## すぐ見られるデモ（Flutter不要）

`demo/index.html` をブラウザで開くと、アプリのコア体験をそのまま操作できます。

```powershell
start demo\index.html   # Windows
```

- 地図をタップして自分の📍を移動 → ピンに **50m以内**で近づくと鍵(🔒→🔓)が開く
- 遠いピンは **ワープチケット⚡** で即解禁（在庫0なら購入モック）
- 解禁後に再生＆ **☕投げ銭**（合計額が増える）
- **🎙ドロップ**：録音モック→タイムロック（デモ用に10秒後/30秒後あり）→ 自分の📍に投稿。
  公開待ち(⏳)は時間経過で自動的に公開へ変わる
- **☰** でマイドロップ／公開中の一覧（再生・削除）
- アイコンは Flutter 版に合わせて SVG（グラデのピン×波形・⚡鍵・💜応援・現在地ドット）に更新済み

> 注: `demo/index.html` は Flutter とは別実装のHTMLモックです。`lib/` 側のUI変更は
> 自動反映されないため、デモにも同等の見た目を別途反映しています。

## テスト

```bash
flutter test
```

- **ロジック**: `geo_utils`（距離）、`PinModel`（タイムロック/JSON）、`PinProvider`
  （公開フィルタ/ドロップ/解禁/課金フォールバック/通報・ブロック）。
- **ウィジェット**: `MapScreen`（GoogleMapをモック注入し、ピンタップ→ワープ解禁→
  投げ銭→通報の一連を検証）、`MyDropsScreen`（タブ/空状態/削除/通報）、`SoundDropLogo`/`Waveform`。
- いずれも `test/fakes.dart` のフェイク（データソース/設定/課金/認証/通報）で端末不要。
  `MapScreen` は `mapViewBuilder` で地図ビューを差し替え可能にしてある。

## バックエンド（Firebase 同期）

既定はローカル永続化のみ。他ユーザー投稿のリアルタイム同期は
[docs/backend/README.md](docs/backend/README.md) の手順で Firestore 実装へ切替できます
（`PinDataSource` を差し替えるだけ）。

## アイコン / スプラッシュ

```bash
node tool/generate_icon.js          # assets/icon/*.png を生成
flutter pub get
dart run flutter_launcher_icons     # 各プラットフォームのアプリアイコン生成
dart run flutter_native_splash:create  # 起動スプラッシュ生成
```

生成されるアイコン（出し分け）:
- `app_icon_framed.png` — 外周の角丸グラデフレーム付き（共有アイコン忠実・**既定**）
- `app_icon.png` — フレーム無し（四角内モチーフのみ）
- `app_icon_foreground.png` — Android Adaptive 前景（透過・セーフゾーン縮小）

`pubspec.yaml` の `flutter_launcher_icons.image_path` を切り替えれば出し分けできます。
アプリ内アイコン（ワープ⚡/鍵/応援💜/現在地）はブランドグラデで統一、地図ピンは
状態別（未解禁/解禁/公開待ち）のカスタム画像です。

- アプリ内スプラッシュ（[lib/screens/splash_screen.dart](lib/screens/splash_screen.dart)）は
  フレーム付きロゴをフェードイン表示し、データ読込完了で**クロスフェードで地図へ遷移**します。
- 録音時の実振幅をダウンサンプルして `PinModel.waveform` に保存し、ピン詳細の
  ミニ波形を**実データで描画**します（無い場合はIDベースの装飾波形にフォールバック）。
- ドロップ確認画面で録音波形を見ながら **RangeSlider でトリミング**可能。元ファイルは
  再エンコードせず、`trimStartMs/trimEndMs` を保存して再生時に `ClippingAudioSource` で切り出します。
- ロゴは `SoundDropLogo`（CustomPaint）で、ストア用ラスターは上記スクリプトのPNGを使用。

## App Store リリース準備

審査ブロッカー対応を実装済み（詳細・手順: [docs/app_store_release.md](docs/app_store_release.md)）。
- **アカウント削除（退会）**：設定 → アカウントを削除（投稿・フォロー等も削除）。
- **利用規約・プライバシー同意**：新規登録時に同意必須＋設定からいつでも閲覧
  （本文雛形: [lib/legal/legal_texts.dart](lib/legal/legal_texts.dart) → 公開URL化）。
- **UGC安全策**：通報・ブロック・運営モデレーション・規約の禁止事項。
- **アプリ内課金**：投げ銭/ワープ（実StoreKit、`ENABLE_TIPPING` で出し分け）。
  本番はサーバーレシート検証必須（[docs/iap_setup.md](docs/iap_setup.md)）。
- **要対応（あなた側）**：Apple Developer 登録／署名／スクショ／プライバシーポリシーURL、
  そして**バックエンド接続**（`--dart-define=USE_FIREBASE=true`／docs/backend）。

## 設定・プライバシー（X等を参考）

地図右上のアカウントメニュー →「設定」（[settings_screen.dart](lib/screens/settings_screen.dart)）。
- **ブロックしたアカウント一覧**（[blocked_accounts_screen.dart](lib/screens/blocked_accounts_screen.dart)）：表示・**解除**。
- **非公開アカウント**（フォロー承認制）、**公開範囲**（フォロワー/相互のみ）、
  **見つけやすさ**（ユーザー名/メール検索の可否）、**位置情報の精度**（正確/約100mぼかし）。
- 設定は `PrivacySettings`（[privacy_settings.dart](lib/models/privacy_settings.dart)）として永続化。
  **位置ぼかしはドロップ時に実際に座標を丸めて防犯に反映**。

## 安全機能・モデレーション

通報は理由を選んで送信（[report_sheet.dart](lib/widgets/report_sheet.dart)）。
構造化レコード（`ReportModel`）を `ReportSink` 経由で運営審査キューへ送り、端末では即時非表示。
運営は [moderation_screen.dart](lib/screens/moderation_screen.dart)（ピン一覧画面の🛡から）で
通報一覧を**ステータスチップ＋理由の折りたたみメニュー・並び替え・件数バッジ**で確認し、
通報タイルのタップで**詳細ダイアログ（音声再生・波形・地図プレビュー・対応ボタン）**を開けます。
**複数選択して一括で却下/対応/削除**でき、選択モード中は「選択中のみ表示」フィルタも連動。
通報詳細の地図プレビューは flutter_map + OpenStreetMap（APIキー不要）。
通報が閾値を超えたピンは自動で非表示（`PinModel.hidden`）。集計は Cloud Functions 雛形
[docs/backend/functions/index.js](docs/backend/functions/index.js)（待ち伏せは1件で即非表示）。
データ設計・審査フロー・Firestoreルールは [docs/moderation.md](docs/moderation.md) を参照。

## 地図（OpenStreetMap・無料）

地図は **`flutter_map`**（Google Maps 不使用）。タイル提供元は [map_tiles.dart](lib/config/map_tiles.dart)
で一元管理し、ダークスタイルでアプリの紺テーマに統一。
- 地図画面: [map_screen.dart](lib/screens/map_screen.dart)（マーカーは自作Widget
  [map_pin.dart](lib/widgets/map_pin.dart)、現在地に50m解禁圏のCircle）。通報詳細プレビューも flutter_map。

### タイル提供元の切替（リリース前に推奨）
OSM公式タイルの大量利用は規約違反になりやすいため、本番は **MapTiler / Stadia**（無料枠＋キー）を推奨。
キーはコミットせず **ビルド時に注入**します（未設定なら開発用に CARTO Dark へ自動フォールバック）。

```bash
# MapTiler（DataViz Dark）
flutter run --dart-define=MAPTILER_KEY=xxxxx
# もしくは Stadia（Alidade Smooth Dark）
flutter run --dart-define=STADIA_KEY=xxxxx
```

デモ（HTML）は `demo/index.html` 内の `const MAPTILER_KEY = ''` にキーを入れると MapTiler、空ならCARTO。

全国〜世界規模で**料金を定額に抑える**には、自前配信（Protomaps PMTiles + Cloudflare R2）が有効です。
アプリは `--dart-define=TILE_URL=...` を指すだけで切替できます（詳細: [docs/map_hosting.md](docs/map_hosting.md)）。

## セットアップ

`android/` `ios/` を生成し、権限・表示名を自動投入できます
（詳細: [docs/native_setup.md](docs/native_setup.md)）。**地図のAPIキーは不要**。

```bash
flutter create .                       # プラットフォーム生成
node tool/generate_icon.js             # アイコンPNG（※あなたのPNGを使う場合は不要）
node tool/setup_native.js              # 位置/マイク/写真 権限・表示名を自動投入
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run
```

`setup_native.js` が AndroidManifest / Info.plist を編集します
（位置情報・マイク・写真ライブラリ権限、表示名 SounDrop）。手動設定の参考も native_setup.md に記載。

### ダミーピンの音声アセット

`dummy_pins.dart` は `assets/audio/sample1.m4a` 等を参照します。試聴したい場合は
そのパスに音声ファイルを置き、`pubspec.yaml` の `assets:` を有効化してください。
未配置でもアプリは動作し、プレイヤーは「読み込めませんでした」と表示します。
ユーザーが録音したドロップは実ファイルなので、そのまま再生できます。

## 永続化

投稿（ピン）・解禁状態・所持ワープチケットは `SharedPreferences` に JSON で保存され、
再起動後も残ります（`PinRepository`）。初回起動時のみデモ用ダミーピンを投入します。
録音ファイルはアプリのドキュメントディレクトリに保存され、パスをピンに記録します。

> 保存データをリセットしたい場合はアプリを再インストールするか、`pins_v1` /
> `warp_tickets_v1` / `seeded_v1` のキーを削除してください。

## アプリ内課金（in_app_purchase）

`PurchaseService` が消費型アイテムを扱います。ストアに以下の商品IDを登録してください。

| 商品ID | 種別 | 内容 |
|---|---|---|
| `warp_ticket_3pack` | 消費型 | ワープチケット3枚 |
| `tip_coffee_100` / `tip_coffee_300` / `tip_coffee_500` | 消費型 | 投げ銭 100/300/500円 |

- **App Store Connect / Google Play Console** で同IDの消費型アイテムを作成。
- Android はサンプルで `BILLING` 権限が必要（`in_app_purchase` が自動付与）。
- **未設定でもデモは動作**します：ストアが利用不可・商品未取得のときは
  `PinProvider` がモック配布へフォールバックします（`buy*` が false を返す経路）。

## 本実装への拡張ポイント

- **バックエンド化:** 現状はローカル永続化。Firebase/Supabase 等へ移行し、他ユーザーの
  ピン同期・`isOwn`/`isUnlocked` のユーザー単位管理を行う。
- **領収書検証:** 課金はサーバー側でレシート検証して配布するのが本番構成。
- **状態管理:** 規模拡大時は Provider → Riverpod へ移行しやすい構造にしてあります。
