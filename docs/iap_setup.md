# アプリ内課金（投げ銭・ワープ）セットアップ

クライアントは [purchase_service.dart](../lib/services/purchase_service.dart)（`in_app_purchase`）で
**消費型アイテム**を扱います。商品IDは以下。

| 商品ID | 種別 | 内容 |
|---|---|---|
| `warp_ticket_3pack` | 消費型 | ワープチケット 3枚 |
| `tip_coffee_100` / `tip_coffee_300` / `tip_coffee_500` | 消費型 | 応援（投げ銭）100/300/500円 |

## App Store Connect（iOS）
1. App 内課金 → **消費型** を上記IDで作成、価格設定、表示名・説明、審査用スクショ。
2. 税・銀行口座（Paid Apps契約）を有効化。
3. サンドボックステスターで動作確認。
4. **課金は審査対象**：審査ビルドで実際に購入→付与まで動く必要あり（モック不可）。

## Google Play（Android）
- Play Console → 収益化 → アプリ内アイテム（消費型）を同じIDで作成。

## 本番の必須要件：サーバーでレシート検証
クライアントの購入完了だけで付与せず、**サーバーで検証**してから付与する。
- iOS: App Store Server API / verifyReceipt（非推奨化のため Server API 推奨）
- Android: Google Play Developer API で purchaseToken を検証
- フロー: 購入 → トークン/レシートをサーバーへ → 検証OK → `gifts`記録＆`balance`加算 →
  クライアントへ反映 → `completePurchase`（消費）

> 現状の `purchaseTip`/`purchaseWarpPack` はストア未接続時にモック配布へフォールバックします。
> 本番では「検証済みのみ付与」に変更してください（フォールバックは無効化）。

## 投げ銭の換金（クリエイター送金）
- 換金する場合：残高台帳＋ Stripe Connect 等で出金、KYC、手数料、税務、資金決済法の整理が必要。
- 当面は **換金なし（アプリ内エール/バッジ）** にするとリスク最小。換金は後日 v1.1+ で。

## 一時的に課金UIを隠す
`--dart-define=ENABLE_TIPPING=false` で投げ銭UIを非表示にできます（[app_config.dart](../lib/app_config.dart)）。
