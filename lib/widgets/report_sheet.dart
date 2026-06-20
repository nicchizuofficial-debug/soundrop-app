import 'package:flutter/material.dart';

import '../models/report_model.dart';

/// 通報理由を選ぶボトムシート。選ばれた理由を返す（キャンセルで null）。
Future<ReportReason?> showReportReasonSheet(BuildContext context) {
  return showModalBottomSheet<ReportReason>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('通報の理由を選択',
                    style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('運営が内容を確認します。緊急時は警察にご連絡ください。',
                    style: Theme.of(sheetContext).textTheme.bodySmall),
              ],
            ),
          ),
          for (final reason in ReportReason.values)
            ListTile(
              leading: Icon(_iconFor(reason)),
              title: Text(reason.label),
              onTap: () => Navigator.pop(sheetContext, reason),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

IconData _iconFor(ReportReason r) => switch (r) {
      ReportReason.stalking => Icons.warning_amber,
      ReportReason.harassment => Icons.report_gmailerrorred,
      ReportReason.privacy => Icons.lock_person,
      ReportReason.sexual => Icons.block,
      ReportReason.spam => Icons.campaign,
      ReportReason.other => Icons.more_horiz,
    };
