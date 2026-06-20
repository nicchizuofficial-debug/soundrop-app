# Mac 無しで iOS を App Store に出す（Codemagic + TestFlight）

Developer Program 加入済み・Windows のみ・無料枠で進める手順。
ビルド設定は [`codemagic.yaml`](../codemagic.yaml)。

---
## 全体像
```
コードを GitHub に置く → App Store Connect でアプリ作成 → API キー発行
→ Codemagic にリポジトリ＆APIキー登録 → ビルド実行（クラウドのMac）
→ TestFlight に自動配信 → 実機で確認 → 審査提出
```
Mac が要る「ビルド」だけ Codemagic のクラウド Mac が肩代わりします。

---
## 1. アプリのコードを GitHub に置く（プライベートでOK）
Codemagic は GitHub のコードを取り込んでビルドします。まだ未プッシュなので：

1. https://github.com/new で新規リポジトリ作成（例 `soundrop-app`、**Private** 推奨）
2. PC で（プロジェクト直下 `C:\claude_SoundDrop`）:
   ```powershell
   cd C:\claude_SoundDrop
   git init
   git add .
   git commit -m "SounDrop initial"
   git branch -M main
   git remote add origin https://github.com/<ユーザー名>/soundrop-app.git
   git push -u origin main
   ```
   - ⚠️ 署名鍵（`android/key.properties` `*.jks`）は `.gitignore` 済みで**上がりません**（正しい挙動）。
   - `lib/firebase_options.dart` は公開クライアント設定なので含めてOK。

> Git 操作は私（Claude）が代行も可能です。希望すれば言ってください。

## 2. App Store Connect でアプリを作成
1. https://appstoreconnect.apple.com → 「マイアプリ」→ ＋ →「新規アプリ」
2. プラットフォーム=iOS、名前=SounDrop、主要言語=日本語
3. **バンドルID**：`com.nicchizu.soundDrop`
   - 一覧に無ければ、先に https://developer.apple.com/account → Identifiers で
     `com.nicchizu.soundDrop` を登録（Codemagic の自動署名でも登録可）
4. SKU=任意（例 `soundrop`）
5. 作成後、表示される **Apple ID（数字）** を控える

## 3. App Store Connect API キーを発行
1. App Store Connect →「ユーザーとアクセス」→「**統合（Integrations）**」→「App Store Connect API」
2. 「+」でキー生成。アクセス権=**App Manager**
3. ダウンロードされる **`.p8` ファイル**、**Issuer ID**、**Key ID** を保存
   （.p8 は一度しかDLできないので必ず保存）

## 4. Codemagic を設定
1. https://codemagic.io/ に **GitHub アカウントでサインアップ**
2. 「Add application」→ さっきの `soundrop-app` リポジトリを選択 → Flutter
3. 「Teams / Integrations」→ **App Store Connect** を追加：
   - 名前を **`SounDrop_ASC_Key`** にする（← codemagic.yaml と一致させる）
   - Issuer ID / Key ID / .p8 を入力
4. リポジトリに `codemagic.yaml` があるので、Codemagic が自動認識
5. 「Start new build」→ ワークフロー **ios-beta** を選んで実行

## 5. ビルド〜TestFlight
- 10〜20分でクラウドの Mac がビルド＆署名し、**TestFlight に自動アップロード**
- App Store Connect →「TestFlight」でビルドを確認
- 自分の iPhone に TestFlight アプリを入れてテスト配信を受け取る

## 6. 審査提出（公開）
TestFlight で問題なければ App Store Connect で：
- スクリーンショット（6.7インチ=1290×2796 等）、説明文（[appstore_metadata.md](appstore_metadata.md)）、
  App Privacy（収集データ申告）、年齢レーティングを入力
- ビルドを選択して「審査に提出」

---
## つまずきポイント
- **自動署名が失敗** → App Store Connect でアプリ（Bundle ID）が作成済みか確認。
  API キーの権限が App Manager 以上か確認。
- **TestFlight に出ない** → `submit_to_testflight: true` と integration 名（`SounDrop_ASC_Key`）の一致を確認。
- **無料枠** → 月500分。iOSビルド1回〜20分なので β なら十分。
- **スクショ** → Mac不要。実機iPhoneのスクショ、または画像ツールで 1290×2796 を用意。
