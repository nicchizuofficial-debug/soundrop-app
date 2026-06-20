/// 他ユーザーのアカウント（プロフィール表示・検索・フォロー用）。
class Account {
  final String uid;
  final String username; // @ハンドル
  final String displayName;
  final String bio;
  final String avatarPath; // プロフィール画像（空=未設定、頭文字表示）

  /// 既存のフォロワー数（自分のフォローは別途加算）。
  final int followerCountBase;

  /// このアカウントが自分をフォローしているか（相互フォロー判定用・デモ用シード）。
  final bool followsBack;

  const Account({
    required this.uid,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarPath = '',
    this.followerCountBase = 0,
    this.followsBack = false,
  });
}
