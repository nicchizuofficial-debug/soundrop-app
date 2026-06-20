# 通報・モデレーション データ設計（運営オペレーション）

防犯（待ち伏せ・付きまとい）を最優先に、通報を受けて運営が審査・対応する流れを定義する。

## 通報フロー

```
[ユーザー] 通報（理由選択）
   └─> ReportModel を ReportSink.submit() で送信
        └─> reports コレクションに status:"pending" で追加
   └─> 端末ローカルで即時非表示（通報者には二度と出さない）

[運営ツール] reports を一覧（pending を優先）
   └─> 内容確認（音声・位置・作者の通報履歴）
   └─> 対応:
        - dismissed : 問題なし
        - actioned  : 投稿削除 / 作者へ警告 / アカウント停止
   └─> status を更新し、必要なら pins / users を更新
```

## データモデル

### reports（通報）

| フィールド | 型 | 説明 |
|---|---|---|
| `id` | string | 通報ID |
| `pinId` | string | 対象ピン |
| `reportedOwnerId` | string | 通報された投稿の作者uid |
| `reporterId` | string | 通報者uid |
| `reason` | string | `stalking`/`harassment`/`privacy`/`sexual`/`spam`/`other` |
| `note` | string | 自由記述（任意） |
| `createdAt` | timestamp | 通報日時 |
| `status` | string | `pending`/`reviewing`/`actioned`/`dismissed` |

実体は [lib/models/report_model.dart](../lib/models/report_model.dart)。

### 自動非表示（Cloud Functions 雛形）

実装雛形: [docs/backend/functions/index.js](backend/functions/index.js)

- `reports/{id}` 作成をトリガに同一 `pinId` の**ユニーク通報者数**を集計。
- しきい値（既定3人）超で `pins/{id}.hidden = true`（クライアントの `visiblePins` が除外）。
- `stalking`（待ち伏せ）は**1件でも即非表示＋優先審査**（`priority:"high"`）。
- 重複通報（同一ユーザー×同一ピン）はユニーク集計で無効化。
- 作者の累計被通報数を `users/{uid}.reportedCount` に加算（累積でアカウント制限の材料）。
- 運営が `dismissed` にしたら、他に有効な通報が無ければ自動で表示を戻す例も同梱。

クライアント側は `PinModel.hidden` を見て地図/一覧から除外する（実装済み）。

デプロイ:
```bash
cd docs/backend/functions && npm i
firebase deploy --only functions
```

## 権限（Firestore ルール例）

```
match /reports/{id} {
  allow create: if request.auth != null
                && request.resource.data.reporterId == request.auth.uid;
  allow read, update, delete: if false; // 運営はAdmin SDK経由のみ
}
```

クライアントは「作成のみ」。閲覧・更新は Admin SDK（運営ツール/Functions）に限定する。

## クライアント実装

- 抽象: [lib/services/report_sink.dart](../lib/services/report_sink.dart)（`ReportSink`）
- 既定: `LocalReportSink`（端末内に蓄積。`all()` で運営フロー検証に使える）
- Firebase: [docs/backend/firebase_report_sink.dart](backend/firebase_report_sink.dart)
- 理由選択UI: [lib/widgets/report_sheet.dart](../lib/widgets/report_sheet.dart)
