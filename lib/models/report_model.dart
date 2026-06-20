/// 通報理由。防犯（待ち伏せ・付きまとい）を最上位に置く。
enum ReportReason {
  stalking('待ち伏せ・付きまといの恐れ'),
  harassment('迷惑行為・嫌がらせ'),
  privacy('個人情報・プライバシー侵害'),
  sexual('性的・不適切な内容'),
  spam('スパム・宣伝'),
  other('その他');

  final String label;
  const ReportReason(this.label);

  static ReportReason fromName(String name) =>
      ReportReason.values.firstWhere((r) => r.name == name,
          orElse: () => ReportReason.other);
}

/// 通報の審査ステータス（運営オペレーション用）。
enum ReportStatus { pending, reviewing, actioned, dismissed }

/// 1件の通報レコード。運営（モデレーション）が扱うデータ単位。
///
/// クライアントは送信のみ。審査・対応（投稿削除/警告/アカBAN）は
/// 運営側ツール（バックエンド）で `status` を更新して進める。
class ReportModel {
  final String id;
  final String pinId;
  final String reportedOwnerId; // 通報された投稿の作者
  final String reporterId; // 通報者
  final ReportReason reason;
  final String note; // 自由記述（任意）
  final DateTime createdAt;
  final ReportStatus status;

  const ReportModel({
    required this.id,
    required this.pinId,
    required this.reportedOwnerId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.note = '',
    this.status = ReportStatus.pending,
  });

  ReportModel copyWith({ReportStatus? status, String? note}) => ReportModel(
        id: id,
        pinId: pinId,
        reportedOwnerId: reportedOwnerId,
        reporterId: reporterId,
        reason: reason,
        note: note ?? this.note,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pinId': pinId,
        'reportedOwnerId': reportedOwnerId,
        'reporterId': reporterId,
        'reason': reason.name,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as String,
        pinId: json['pinId'] as String,
        reportedOwnerId: json['reportedOwnerId'] as String? ?? '',
        reporterId: json['reporterId'] as String? ?? '',
        reason: ReportReason.fromName(json['reason'] as String? ?? 'other'),
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: ReportStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? 'pending'),
          orElse: () => ReportStatus.pending,
        ),
      );
}
