import 'purchase_gateway.dart';

/// 投げ銭購入をサーバーで検証し、台帳に記帳する窓口。
///
/// 本番は Firebase 実装（Cloud Functions `verifyAndCreditGift` を呼ぶ。
/// docs/backend/firebase_payout_service.dart 参照）。
/// 既定はローカルスタブ＝未接続（false を返し、呼び出し側がローカルモック加算）。
abstract class GiftBackend {
  /// 検証＋記帳。成功で true（サーバーが pins/balances を更新）。
  Future<bool> creditTip({
    required GiftReceipt receipt,
    required String pinId,
    required String toUid,
  });
}

class LocalGiftBackend implements GiftBackend {
  @override
  Future<bool> creditTip({
    required GiftReceipt receipt,
    required String pinId,
    required String toUid,
  }) async =>
      false; // 未接続：呼び出し側でローカルモック加算にフォールバック
}
