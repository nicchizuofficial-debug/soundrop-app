import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// ログインID（ユーザー名）＋パスワードでのアカウント登録／ログインを扱う。
///
/// ログインIDは一意。ログイン状態は保持し、最終アクセスから [sessionTtl]
/// （既定30日）を超えて未アクセスの場合のみ失効する。
/// 既定はローカル実装。Firebase 版は docs/backend/firebase_auth_service.dart 参照。
abstract class AuthService {
  /// 現在ログイン中のユーザー（未ログイン／セッション失効なら null）。
  Future<AppUser?> currentUser();

  /// 新規登録（ログインIDは一意）。
  Future<AppUser> signUp({
    required String username,
    required String password,
    required String displayName,
    String email,
  });

  /// ログインID＋パスワードでログイン。
  Future<AppUser> signIn({
    required String username,
    required String password,
  });

  /// パスワード再設定メールを送信する。
  Future<void> sendPasswordReset({required String username});

  /// プロフィール（表示名・ログインID・自己紹介・画像）を更新。
  Future<AppUser> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  });

  Future<void> signOut();

  /// アカウントを削除（退会）。App Store の要件。
  Future<void> deleteAccount();
}

/// SharedPreferences 実装（プロトタイプ用。パスワードは平文保存のため本番不可）。
class LocalAuthService implements AuthService {
  /// 未アクセスでセッションが失効するまでの期間。
  static const Duration sessionTtl = Duration(days: 30);

  static const _usersKey = 'auth_users_v2'; // username(lower) -> record
  static const _currentKey = 'auth_current_username_v2';
  static const _lastActiveKey = 'auth_last_active_v2';

  Future<Map<String, dynamic>> _users(SharedPreferences p) async {
    final raw = p.getString(_usersKey);
    if (raw == null || raw.isEmpty) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _norm(String username) =>
      username.replaceAll('@', '').trim().toLowerCase();

  AppUser _toUser(String key, Map<String, dynamic> m) => AppUser(
        uid: m['uid'] as String,
        email: m['email'] as String? ?? '',
        displayName: m['displayName'] as String? ?? key,
        username: key,
        bio: m['bio'] as String? ?? '',
        avatarPath: m['avatarPath'] as String? ?? '',
      );

  Future<void> _touch(SharedPreferences p) =>
      p.setString(_lastActiveKey, DateTime.now().toIso8601String());

  @override
  Future<AppUser?> currentUser() async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString(_currentKey);
    if (key == null) return null;

    // 最終アクセスから30日超で失効。
    final lastStr = p.getString(_lastActiveKey);
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null && DateTime.now().difference(last) > sessionTtl) {
        await signOut();
        return null;
      }
    }

    final users = await _users(p);
    final m = users[key] as Map<String, dynamic>?;
    if (m == null) return null;
    await _touch(p); // アクセスのたびに延長
    return _toUser(key, m);
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
    required String displayName,
    String email = '',
  }) async {
    final p = await SharedPreferences.getInstance();
    final users = await _users(p);
    final key = _norm(username);
    if (key.isEmpty) {
      throw AuthException('ログインIDを入力してください');
    }
    if (password.length < 6) {
      throw AuthException('パスワードは6文字以上にしてください');
    }
    if (users.containsKey(key)) {
      throw AuthException('このログインIDは既に使われています');
    }
    final uid = 'u_${DateTime.now().millisecondsSinceEpoch}_'
        '${Random().nextInt(1 << 30)}';
    users[key] = {
      'uid': uid,
      'password': password,
      'displayName': displayName.trim().isEmpty ? key : displayName.trim(),
      'email': email.trim(),
      'bio': '',
    };
    await p.setString(_usersKey, jsonEncode(users));
    await p.setString(_currentKey, key);
    await _touch(p);
    return _toUser(key, users[key] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final p = await SharedPreferences.getInstance();
    final users = await _users(p);
    final key = _norm(username);
    final m = users[key] as Map<String, dynamic>?;
    if (m == null) {
      throw AuthException('このログインIDは登録されていません');
    }
    if (m['password'] != password) {
      throw AuthException('パスワードが違います');
    }
    await p.setString(_currentKey, key);
    await _touch(p);
    return _toUser(key, m);
  }

  @override
  Future<void> sendPasswordReset({required String username}) async {
    // ローカル（デモ）モードはメール送信基盤が無いため未対応。
    throw AuthException(
        'ローカルモードではパスワード再設定に対応していません。Firebaseモードでご利用ください');
  }

  @override
  Future<AppUser> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  }) async {
    final p = await SharedPreferences.getInstance();
    final users = await _users(p);
    final cur = p.getString(_currentKey);
    if (cur == null) throw AuthException('ログインが必要です');
    final m = users[cur] as Map<String, dynamic>?;
    if (m == null) throw AuthException('ユーザーが見つかりません');

    if (displayName != null && displayName.trim().isNotEmpty) {
      m['displayName'] = displayName.trim();
    }
    if (bio != null) m['bio'] = bio.trim();
    if (avatarPath != null) m['avatarPath'] = avatarPath;

    var newKey = cur;
    if (username != null && _norm(username).isNotEmpty &&
        _norm(username) != cur) {
      newKey = _norm(username);
      if (users.containsKey(newKey)) {
        throw AuthException('このログインIDは既に使われています');
      }
      users.remove(cur);
      await p.setString(_currentKey, newKey);
    }
    users[newKey] = m;
    await p.setString(_usersKey, jsonEncode(users));
    await _touch(p);
    return _toUser(newKey, m);
  }

  @override
  Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_currentKey);
    await p.remove(_lastActiveKey);
  }

  @override
  Future<void> deleteAccount() async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString(_currentKey);
    if (key != null) {
      final users = await _users(p);
      final uid = (users[key] as Map<String, dynamic>?)?['uid'] as String?;
      users.remove(key);
      await p.setString(_usersKey, jsonEncode(users));
      if (uid != null) await p.remove('following_$uid'); // フォロー情報も削除
    }
    await p.remove(_currentKey);
    await p.remove(_lastActiveKey);
  }
}
