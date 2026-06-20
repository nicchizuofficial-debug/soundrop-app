/// 課金レシート（サーバー検証に渡す情報）。in_app_purchase 非依存のDTO。
class GiftReceipt {
  final String platform; // 'ios' | 'android'
  final String productId;
  final String serverVerificationData; // iOS:base64レシート / Android:purchaseToken
  const GiftReceipt({
    required this.platform,
    required this.productId,
    required this.serverVerificationData,
  });
}

/// アプリ内課金の窓口を抽象化したインターフェース。
///
/// 本番は [PurchaseService]（in_app_purchase）、テストや課金不可環境では
/// フェイク/モックに差し替えられる。配布は購入完了時にコールバックで通知する。
abstract class PurchaseGateway {
  /// ワープチケット配布（枚数）。
  abstract void Function(int count)? onWarpTicketsDelivered;

  /// 投げ銭配布（金額, レシート）。レシートはストア購入時のみ（モックはnull）。
  abstract void Function(int amount, GiftReceipt? receipt)? onTipDelivered;

  /// エラー通知。
  abstract void Function(String message)? onError;

  /// ストアが利用可能で商品取得に成功したか。
  bool get isAvailable;

  /// 商品の表示価格（"¥320" 等）。未取得なら null。
  String? priceOf(String productId);

  /// 初期化（購入ストリーム購読・商品取得）。
  Future<void> init();

  /// ワープチケットパック購入。開始できたら true。
  Future<bool> buyWarpPack();

  /// 指定金額の投げ銭購入。開始できたら true。
  Future<bool> buyTip(int amount);

  void dispose();
}
