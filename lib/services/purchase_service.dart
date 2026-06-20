import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'purchase_gateway.dart';

/// アプリ内課金（消費型アイテム）を扱うサービス。
///
/// 取り扱う商品:
///  - ワープチケット3枚パック
///  - 応援を贈る（投げ銭）100 / 300 / 500円
///
/// いずれも消費型（consumable）。購入完了時にコールバックで配布する。
/// ストアに接続できない / 商品が見つからない環境では [isAvailable] が false になり、
/// 呼び出し側はモック配布へフォールバックできる。
class PurchaseService implements PurchaseGateway {
  // ストア（App Store / Google Play）に登録する商品ID。
  static const warpPack3Id = 'warp_ticket_3pack';
  static const tip100Id = 'tip_coffee_100';
  static const tip300Id = 'tip_coffee_300';
  static const tip500Id = 'tip_coffee_500';

  /// 投げ銭商品ID → 金額の対応。
  static const tipAmountByProduct = <String, int>{
    tip100Id: 100,
    tip300Id: 300,
    tip500Id: 500,
  };

  static const _warpPackQuantity = 3; // 1パックで配布する枚数

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  final Map<String, ProductDetails> _products = {};

  /// 配布コールバック（Provider 側で実装をセットする）。
  void Function(int count)? onWarpTicketsDelivered;
  void Function(int amount, GiftReceipt? receipt)? onTipDelivered;
  void Function(String message)? onError;

  /// ストアが利用可能で、商品取得に成功したか。
  bool get isAvailable => _available;

  /// 商品の表示価格（"¥320" など）。未取得なら null。
  String? priceOf(String productId) => _products[productId]?.price;

  Set<String> get _allProductIds =>
      {warpPack3Id, ...tipAmountByProduct.keys};

  /// 初期化。購入ストリームの購読と商品情報の取得を行う。
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    // 購入更新の監視を開始（復元・遅延承認もここに流れてくる）。
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e) => onError?.call('購入ストリームエラー: $e'),
    );

    final response = await _iap.queryProductDetails(_allProductIds);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    if (response.error != null) {
      onError?.call('商品取得エラー: ${response.error!.message}');
    }
    if (_products.isEmpty) {
      // 商品未登録などで取れない場合はモックにフォールバックさせる。
      _available = false;
    }
  }

  /// ワープチケットパックを購入。商品が無ければ false（呼び出し側でモック）。
  Future<bool> buyWarpPack() => _buyConsumable(warpPack3Id);

  /// 指定金額の投げ銭を購入。対応商品が無ければ false。
  Future<bool> buyTip(int amount) {
    final id = tipAmountByProduct.entries
        .firstWhere((e) => e.value == amount,
            orElse: () => const MapEntry('', 0))
        .key;
    if (id.isEmpty) return Future.value(false);
    return _buyConsumable(id);
  }

  Future<bool> _buyConsumable(String productId) async {
    final product = _products[productId];
    if (!_available || product == null) return false;

    final param = PurchaseParam(productDetails: product);
    // 消費型なので buyConsumable を使用。
    return _iap.buyConsumable(purchaseParam: param);
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break; // 承認待ち。UI側でローディング表示してもよい。
        case PurchaseStatus.error:
          onError?.call(purchase.error?.message ?? '購入に失敗しました');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _deliver(purchase);
          break;
        case PurchaseStatus.canceled:
          break;
      }

      // 消費型でも完了処理は必須（Androidではここで消費扱いになる）。
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void _deliver(PurchaseDetails purchase) {
    final id = purchase.productID;
    if (id == warpPack3Id) {
      onWarpTicketsDelivered?.call(_warpPackQuantity);
    } else if (tipAmountByProduct.containsKey(id)) {
      // サーバー検証用にレシート（iOS）/購入トークン（Android）を渡す。
      final receipt = GiftReceipt(
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        productId: id,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
      );
      onTipDelivered?.call(tipAmountByProduct[id]!, receipt);
    } else {
      debugPrint('未知の商品が配布されました: $id');
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
