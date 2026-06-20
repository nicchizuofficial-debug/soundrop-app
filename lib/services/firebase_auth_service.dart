import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'auth_service.dart';

/// Firebase Authentication（メール/パスワード）でログインID運用する実装。
///
/// Firebase Auth はメール必須のため、ログインID(username)→メール のマッピングを
/// Firestore に持たせる:
///   usernames/{usernameLower} = { email, uid }   // 一意制約＆ID→メール解決
///   users/{uid}              = { username, displayName, email, bio, avatarUrl, lastActiveAt }
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration sessionTtl = Duration(days: 30);

  String _norm(String u) => u.replaceAll('@', '').trim().toLowerCase();

  Future<AppUser> _profile(User u) async {
    final doc = await _db.collection('users').doc(u.uid).get();
    final m = doc.data() ?? {};
    return AppUser(
      uid: u.uid,
      email: u.email ?? (m['email'] as String? ?? ''),
      displayName: m['displayName'] as String? ?? (u.displayName ?? ''),
      username: m['username'] as String? ?? '',
      bio: m['bio'] as String? ?? '',
      avatarPath: m['avatarUrl'] as String? ?? '',
    );
  }

  @override
  Future<AppUser?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    final last = (snap.data()?['lastActiveAt'] as Timestamp?)?.toDate();
    if (last != null && DateTime.now().difference(last) > sessionTtl) {
      await _auth.signOut();
      return null;
    }
    await ref.set({'lastActiveAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    return _profile(u);
  }

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
    required String displayName,
    String email = '',
  }) async {
    final id = _norm(username);
    if (id.isEmpty) throw AuthException('ログインIDを入力してください');
    if (password.length < 6) throw AuthException('パスワードは6文字以上にしてください');
    final unameRef = _db.collection('usernames').doc(id);
    if ((await unameRef.get()).exists) {
      throw AuthException('このログインIDは既に使われています');
    }
    final mail = email.trim().isEmpty ? '$id@sounddrop.app' : email.trim();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: mail, password: password);
      final uid = cred.user!.uid;
      final name = displayName.trim().isEmpty ? id : displayName.trim();
      await cred.user!.updateDisplayName(name);
      await unameRef.set({'email': mail, 'uid': uid});
      await _db.collection('users').doc(uid).set({
        'username': id,
        'displayName': name,
        'email': mail,
        'bio': '',
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      return _profile(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_msg(e));
    }
  }

  @override
  Future<AppUser> signIn({
    required String username,
    required String password,
  }) async {
    final id = _norm(username);
    final doc = await _db.collection('usernames').doc(id).get();
    final email = doc.data()?['email'] as String?;
    if (email == null) throw AuthException('このログインIDは登録されていません');
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _db.collection('users').doc(cred.user!.uid).set(
          {'lastActiveAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      return _profile(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code == 'wrong-password' ||
              e.code == 'invalid-credential'
          ? 'パスワードが違います'
          : _msg(e));
    }
  }

  @override
  Future<AppUser> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException('ログインが必要です');
    final ref = _db.collection('users').doc(u.uid);
    final cur = (await ref.get()).data() ?? {};
    final data = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      data['displayName'] = displayName.trim();
      await u.updateDisplayName(displayName.trim());
    }
    if (bio != null) data['bio'] = bio.trim();
    if (avatarPath != null) data['avatarUrl'] = avatarPath; // 必要なら Storage URL に
    if (username != null &&
        _norm(username).isNotEmpty &&
        _norm(username) != cur['username']) {
      final id = _norm(username);
      final unameRef = _db.collection('usernames').doc(id);
      if ((await unameRef.get()).exists) {
        throw AuthException('このログインIDは既に使われています');
      }
      await unameRef.set({'email': u.email, 'uid': u.uid});
      if (cur['username'] != null) {
        await _db
            .collection('usernames')
            .doc(cur['username'] as String)
            .delete();
      }
      data['username'] = id;
    }
    if (data.isNotEmpty) await ref.set(data, SetOptions(merge: true));
    return _profile(u);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final uid = u.uid;
    final username =
        (await _db.collection('users').doc(uid).get()).data()?['username']
            as String?;
    if (username != null) {
      await _db.collection('usernames').doc(username).delete();
    }
    await _db.collection('users').doc(uid).delete();
    await u.delete();
  }

  String _msg(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'このメールアドレスは既に登録されています',
        'weak-password' => 'パスワードは6文字以上にしてください',
        'user-not-found' => 'このログインIDは登録されていません',
        _ => '認証に失敗しました（${e.code}）',
      };
}
