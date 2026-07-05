import 'services/account_directory.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_gift_backend.dart';
import 'services/firebase_payout_service.dart';
import 'services/firebase_pin_data_source.dart';
import 'services/firebase_report_sink.dart';
import 'services/gift_backend.dart';
import 'services/local_pin_data_source.dart';
import 'services/payout_service.dart';
import 'services/pin_data_source.dart';
import 'services/report_sink.dart';

/// バックエンド選択などのアプリ全体設定。
///
/// Firebase を使う場合は `--dart-define=USE_FIREBASE=true` で起動する。
/// デフォルト(false)はローカル永続化のみで、Firebase の設定なしでデモが動く。
class AppConfig {
  static const bool useFirebase =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

  /// アプリ内課金（ワープ購入・投げ銭）UI全体のマスタースイッチ。
  /// β版は課金を外して公開するため `--dart-define=ENABLE_PURCHASES=false`。
  static const bool enablePurchases =
      bool.fromEnvironment('ENABLE_PURCHASES', defaultValue: true);

  /// 投げ銭（応援）UIを出すか（課金が有効な場合のみ意味を持つ）。
  /// 投げ銭だけ隠す場合: --dart-define=ENABLE_TIPPING=false
  static const bool _tippingFlag =
      bool.fromEnvironment('ENABLE_TIPPING', defaultValue: true);

  /// 実際に投げ銭UIを表示するか（マスタースイッチとAND）。
  static bool get enableTipping => enablePurchases && _tippingFlag;

  // 地図は flutter_map + OpenStreetMap（APIキー不要）を使用。
}

/// データソース：USE_FIREBASE=true で Firestore、既定はローカル永続化。
PinDataSource createPinDataSource() {
  if (AppConfig.useFirebase) return FirebasePinDataSource();
  return LocalPinDataSource();
}

/// 認証：USE_FIREBASE=true で Firebase Auth（ログインID運用）、既定はローカル。
AuthService createAuthService() {
  if (AppConfig.useFirebase) return FirebaseAuthService();
  return LocalAuthService();
}

/// 通報の送信先。USE_FIREBASE=true で Firestore reports。
ReportSink createReportSink() {
  if (AppConfig.useFirebase) return FirebaseReportSink();
  return LocalReportSink();
}

/// アカウント名簿。USE_FIREBASE=true ではデモ名簿を出さない（空）。
AccountDirectory createAccountDirectory() {
  if (AppConfig.useFirebase) return EmptyAccountDirectory();
  return LocalAccountDirectory();
}

/// 出金サービス：USE_FIREBASE=true で Cloud Functions + Stripe Connect。
PayoutService createPayoutService() {
  if (AppConfig.useFirebase) return FirebasePayoutService();
  return LocalPayoutService();
}

/// 投げ銭検証：USE_FIREBASE=true で Cloud Functions verifyAndCreditGift。
GiftBackend createGiftBackend() {
  if (AppConfig.useFirebase) return FirebaseGiftBackend();
  return LocalGiftBackend();
}
