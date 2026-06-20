import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/report_model.dart';

/// 通報レコードの送信先（運営オペレーション用）。
///
/// 本番は Firestore の `reports` コレクション等へ送る（docs/backend 参照）。
/// 既定はローカル実装で、端末内に蓄積して運営フローの検証に使える。
abstract class ReportSink {
  Future<void> submit(ReportModel report);

  /// 蓄積済みの通報一覧（運営/デバッグ用）。
  Future<List<ReportModel>> all();

  /// 審査ステータスを更新する（運営オペレーション）。
  Future<void> updateStatus(String reportId, ReportStatus status);
}

/// SharedPreferences にJSONで蓄積するローカル実装。
class LocalReportSink implements ReportSink {
  static const _key = 'reports_v1';

  @override
  Future<void> submit(ReportModel report) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    list.add(jsonEncode(report.toJson()));
    await prefs.setStringList(_key, list);
  }

  @override
  Future<List<ReportModel>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    return list
        .map((e) => ReportModel.fromJson(
            jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> updateStatus(String reportId, ReportStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await all();
    final updated = reports
        .map((r) => r.id == reportId ? r.copyWith(status: status) : r)
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList(_key, updated);
  }
}
