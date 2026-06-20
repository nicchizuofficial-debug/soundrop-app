/// クリエイター収益の残高取得・出金オンボーディングを抽象化。
///
/// 既定はローカルスタブ（バックエンド未接続。残高はアプリ内推定を使う／
/// オンボーディングは未提供＝null）。本番は Firebase 実装（cloud_functions で
/// Cloud Functions を呼ぶ）に差し替える。docs/backend/firebase_payout_service.dart 参照。
abstract class PayoutService {
  /// バックエンド集計の受け取り可能残高（円）。未対応なら null。
  Future<int?> availableBalanceYen();

  /// Stripe Connect オンボーディングURL。未対応なら null。
  Future<String?> onboardingUrl();

  /// 出金をリクエスト。成功で true。未対応なら false。
  Future<bool> requestPayout();
}

/// ローカルスタブ（バックエンド未接続）。
class LocalPayoutService implements PayoutService {
  @override
  Future<int?> availableBalanceYen() async => null; // 推定値で表示

  @override
  Future<String?> onboardingUrl() async => null; // 準備中

  @override
  Future<bool> requestPayout() async => false;
}
