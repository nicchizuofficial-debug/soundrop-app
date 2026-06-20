/// アプリのユーザー（メール登録）。
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String username; // @ハンドル（検索用・一意想定）
  final String bio;
  final String avatarPath; // プロフィール画像のローカルパス（空=未設定）

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username = '',
    this.bio = '',
    this.avatarPath = '',
  });

  AppUser copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        bio: bio ?? this.bio,
        avatarPath: avatarPath ?? this.avatarPath,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'username': username,
        'bio': bio,
        'avatarPath': avatarPath,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        username: json['username'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        avatarPath: json['avatarPath'] as String? ?? '',
      );
}

/// 認証関連の例外（UI表示用メッセージ付き）。
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
