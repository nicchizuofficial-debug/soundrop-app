# App Store リリース チェックリスト（SounDrop）

## 0. 事前（あなた側）
- [ ] Apple Developer Program 登録（$99/年）
- [ ] App 名「SounDrop」の空き確認、Bundle ID 決定（例: com.yourco.sounddrop）
- [ ] **プライバシーポリシー URL**（公開ページ）。雛形: `lib/legal/legal_texts.dart` を元にWeb公開
- [ ] スクリーンショット（6.7"/6.5"/5.5" 等）、アプリ説明、キーワード、サポートURL
- [ ] 年齢レーティング（UGC・位置情報あり）

## 1. プロジェクト生成・設定
```bash
flutter create .
node tool/setup_native.js     # 位置/マイク/写真 権限・表示名
node tool/generate_icon.js    # （独自PNG使用時は不要）
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## 2. 審査ブロッカー（実装状況）
- [x] **アカウント削除（退会）**：設定 → アカウントを削除（実装済み）
- [x] **利用規約・プライバシー同意**：新規登録時にチェック必須＋設定からリンク（実装済み）
- [x] **UGC対策**：通報・ブロック・運営モデレーション・規約での禁止事項（実装済み）
- [x] 位置情報は When-In-Use のみ／用途文あり
- [ ] **バックエンド同期（重要）**：他ユーザーの投稿が見える状態にする
      （ローカルのみだと「機能していない」と却下されやすい）→ `--dart-define=USE_FIREBASE=true`
      ＋ docs/backend の手順で Firestore/Storage/Auth を接続
- [ ] **アプリ内課金（投げ銭/ワープ）**：
      - App Store Connect で消費型アイテムを登録（docs/iap_setup.md）
      - **サーバーでレシート検証**してから付与（本番要件）
      - 価格・内容・復元/返金の扱いを明記
      - 一時的に隠す場合 `--dart-define=ENABLE_TIPPING=false`

## 3. App Privacy（データ申告）
- 収集: アカウント情報、ユーザーコンテンツ、位置情報、購入履歴
- 用途: アプリ機能、安全対策。トラッキングは行わない（している場合は申告）

## 4. ビルド & 提出

### β版（課金を外して公開・推奨スタート）
`ENABLE_PURCHASES=false` で **投げ銭（応援）・ワープ購入・収益画面をすべて非表示**にします。
IAPの審査・送金・資金決済法の論点を回避でき、最短で出せます。
```bash
flutter build ipa \
  --dart-define=USE_FIREBASE=true \
  --dart-define=MAPTILER_KEY=xxxxx \
  --dart-define=ENABLE_PURCHASES=false
```
- 課金関連コード（IAP/検証/出金/Stripe）はそのまま残るので、**フラグを戻すだけで再開**できます。
- ワープは初期付与チケットで体験可能（購入導線は「準備中」表示）。

### 製品版（税理士・弁護士の確認後／課金ON）
```bash
flutter build ipa \
  --dart-define=USE_FIREBASE=true \
  --dart-define=MAPTILER_KEY=xxxxx \
  --dart-define=ENABLE_PURCHASES=true
```
→ App Store Connect で消費型IAP登録＋サーバーレシート検証（docs/iap_setup.md）、
　出金は docs/payouts.md / operator_legal.md の体制を整えてから解放。

- Xcode で署名 → Archive → App Store Connect へアップロード → TestFlight → 審査提出

## 5. よくある却下理由（対策済みかチェック）
- 4.2 最小機能：ダミー/ローカルのみ → **バックエンド接続必須**
- 5.1.1 アカウント削除が無い → **実装済み**
- 3.1.1 デジタル課金が外部決済 → **IAP必須（本アプリはIAP）**
- 1.2 UGCの安全策が無い → 通報/ブロック/モデレーション/規約で対応済み
- 5.1.5 位置情報の用途不明 → 用途文で明記
