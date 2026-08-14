import '../models/account.dart';

/// アカウント名簿（検索・プロフィール・フォロワー数の供給元）。
///
/// ローカルモードはデモ用のシード実装。Firebase モードは
/// [FirebaseAccountDirectory]（Firestore の users コレクション）を使う
/// （uid は投稿の ownerId と一致させること）。
abstract class AccountDirectory {
  Future<List<Account>> all();
}

/// デモ用のシード名簿。dummy_pins の ownerId と uid を一致させている。
class LocalAccountDirectory implements AccountDirectory {
  @override
  Future<List<Account>> all() async => const [
        Account(
          uid: 'demo_kenta',
          username: 'kenta',
          displayName: 'けんた',
          bio: '街の音を集めてます。駅前のドロップが多めです。',
          followerCountBase: 128,
          followsBack: true,
        ),
        Account(
          uid: 'demo_misaki',
          username: 'misaki',
          displayName: 'みさき',
          bio: 'ひみつの声をそっと置いていきます🤫',
          followerCountBase: 342,
          followsBack: false,
        ),
        Account(
          uid: 'demo_yuto',
          username: 'yuto',
          displayName: 'ゆうと',
          bio: '待ち合わせと時間差ドロップの達人。',
          followerCountBase: 57,
          followsBack: true,
        ),
      ];
}
