import 'package:cloud_functions/cloud_functions.dart';

import 'payout_service.dart';

/// Firebase 版 PayoutService（Cloud Functions で残高取得・出金）。
class FirebasePayoutService implements PayoutService {
  final _fn = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  @override
  Future<int?> availableBalanceYen() async {
    try {
      final res = await _fn.httpsCallable('getBalance').call();
      return (res.data as Map)['pending'] as int?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> onboardingUrl() async {
    try {
      final res =
          await _fn.httpsCallable('createConnectOnboardingLink').call();
      return (res.data as Map)['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPayout() async {
    try {
      final res = await _fn.httpsCallable('requestPayout').call();
      return (res.data as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
