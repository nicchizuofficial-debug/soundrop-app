import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import 'account_directory.dart';

/// Firestore の `users` コレクションから実際のアカウント一覧を取得する。
/// 「アカウントを探す」の検索候補や、他ユーザーのプロフィール表示に使う。
class FirebaseAccountDirectory implements AccountDirectory {
  FirebaseAccountDirectory({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('users');

  final CollectionReference<Map<String, dynamic>> _col;

  @override
  Future<List<Account>> all() async {
    final snap = await _col.get();
    return snap.docs.map((d) {
      final m = d.data();
      return Account(
        uid: d.id,
        username: m['username'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        bio: m['bio'] as String? ?? '',
        avatarPath: m['avatarUrl'] as String? ?? '',
      );
    }).toList();
  }
}
