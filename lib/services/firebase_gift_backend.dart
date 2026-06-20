import 'package:cloud_functions/cloud_functions.dart';

import 'gift_backend.dart';
import 'purchase_gateway.dart';

/// Firebase 版 GiftBackend（Cloud Functions `verifyAndCreditGift` を呼ぶ）。
class FirebaseGiftBackend implements GiftBackend {
  final _fn = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  @override
  Future<bool> creditTip({
    required GiftReceipt receipt,
    required String pinId,
    required String toUid,
  }) async {
    try {
      final res = await _fn.httpsCallable('verifyAndCreditGift').call({
        'platform': receipt.platform,
        'productId': receipt.productId,
        if (receipt.platform == 'ios')
          'receiptData': receipt.serverVerificationData
        else
          'purchaseToken': receipt.serverVerificationData,
        'pinId': pinId,
        'toUid': toUid,
      });
      return (res.data as Map)['ok'] == true;
    } catch (_) {
      return false; // 失敗時は呼び出し側でローカルフォールバック
    }
  }
}
