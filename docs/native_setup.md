# ネイティブ設定メモ（`flutter create .` 後）

リポジトリには `android/` `ios/` が含まれていません（Dartコードとデモ中心）。
実機/エミュレータで動かすには、一度プラットフォームを生成してから権限・表示名を設定します。
**地図は OpenStreetMap（flutter_map）なので Maps APIキーは不要**です。

## クイック手順

```bash
flutter create .                       # android/ ios/ web/ を生成
node tool/generate_icon.js             # アイコンPNG生成（独自PNGを使う場合は不要）
node tool/setup_native.js              # 権限・表示名を自動投入
flutter pub get
dart run flutter_launcher_icons        # アプリアイコン
dart run flutter_native_splash:create  # スプラッシュ
flutter run
```

## `setup_native.js` が行う変更

### Android (`android/app/src/main/AndroidManifest.xml`)
- 権限を追加: `INTERNET` / `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` / `RECORD_AUDIO`
- `android:label` を `SounDrop` に変更

### iOS (`ios/Runner/Info.plist`)
- `NSLocationWhenInUseUsageDescription` / `NSMicrophoneUsageDescription` /
  `NSPhotoLibraryUsageDescription` を追加
- `CFBundleDisplayName` を `SounDrop` に

> スクリプトは冪等（再実行しても重複しません）。生成直後の標準ファイル構造を前提にしています。
> テンプレートが変わって差し込めない場合は、本書の各項目を手動で追記してください。

## 手動で行う場合（参考）

**Android** — `<manifest>` 直下:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**iOS** — `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key><string>...</string>
<key>NSMicrophoneUsageDescription</key><string>...</string>
<key>NSPhotoLibraryUsageDescription</key><string>...</string>
```

## 地図タイルについて
- 既定は OpenStreetMap 公式タイル（`https://tile.openstreetmap.org/...`）。
- 本番で利用が多い場合は OSM の利用規約に従い、MapTiler / Stadia Maps などの
  タイルプロバイダ（無料枠あり）へ `TileLayer.urlTemplate` を変更してください。

## 注意
- Android は最低 SDK 21 以上、iOS は録音/位置情報のため実機推奨。
- インターネット接続が必要（地図タイル取得のため）。
