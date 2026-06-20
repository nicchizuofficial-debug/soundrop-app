import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report_model.dart';
import 'report_sink.dart';

/// Firestore の `reports` コレクションへ通報を送る。
/// クライアントは作成のみ（read/update はルールで運営ツールに限定する想定）。
class FirebaseReportSink implements ReportSink {
  FirebaseReportSink({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('reports');

  final CollectionReference<Map<String, dynamic>> _col;

  @override
  Future<void> submit(ReportModel report) =>
      _col.doc(report.id).set(report.toJson());

  @override
  Future<List<ReportModel>> all() async {
    throw UnsupportedError('reports の一覧取得は運営ツール（Admin SDK）でのみ可能です');
  }

  @override
  Future<void> updateStatus(String reportId, ReportStatus status) =>
      _col.doc(reportId).update({'status': status.name});
}
