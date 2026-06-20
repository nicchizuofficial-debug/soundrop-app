import 'dart:async';

import 'package:sound_drop/models/account.dart';
import 'package:sound_drop/models/app_user.dart';
import 'package:sound_drop/models/pin_model.dart';
import 'package:sound_drop/models/privacy_settings.dart';
import 'package:sound_drop/models/report_model.dart';
import 'package:sound_drop/services/account_directory.dart';
import 'package:sound_drop/services/auth_service.dart';
import 'package:sound_drop/services/pin_data_source.dart';
import 'package:sound_drop/services/purchase_gateway.dart' show PurchaseGateway, GiftReceipt;
import 'package:sound_drop/services/report_sink.dart';
import 'package:sound_drop/services/settings_store.dart';

/// テスト用のインメモリ・データソース。
class FakePinDataSource implements PinDataSource {
  FakePinDataSource(List<PinModel> initial) : _pins = List.of(initial);

  List<PinModel> _pins;

  late final StreamController<List<PinModel>> _c =
      StreamController<List<PinModel>>(onListen: _emit);

  void _emit() {
    if (!_c.isClosed) _c.add(List.unmodifiable(_pins));
  }

  @override
  Stream<List<PinModel>> watchPins() => _c.stream;

  @override
  Future<void> upsertPin(PinModel pin) async {
    final i = _pins.indexWhere((p) => p.id == pin.id);
    if (i >= 0) {
      _pins[i] = pin;
    } else {
      _pins = [..._pins, pin];
    }
    _emit();
  }

  @override
  Future<void> deletePin(String id) async {
    _pins = _pins.where((p) => p.id != id).toList();
    _emit();
  }

  @override
  Future<void> dispose() async => _c.close();
}

/// テスト用の設定ストア（メモリ保持）。
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([int initialTickets = 2])
      : _ticketExpiries = List.generate(
            initialTickets,
            (_) => DateTime.now()
                .add(const Duration(days: 180))
                .toIso8601String());
  List<String>? _ticketExpiries;
  Set<String> blocked = {};
  Set<String> reported = {};

  @override
  Future<List<String>?> loadTicketExpiries() async => _ticketExpiries;

  @override
  Future<void> saveTicketExpiries(List<String> e) async =>
      _ticketExpiries = e;

  @override
  Future<Set<String>> loadBlockedAuthors() async => blocked;

  @override
  Future<void> saveBlockedAuthors(Set<String> ids) async => blocked = ids;

  @override
  Future<Set<String>> loadReportedPins() async => reported;

  @override
  Future<void> saveReportedPins(Set<String> ids) async => reported = ids;

  Set<String> saved = {};

  @override
  Future<Set<String>> loadSavedPins() async => saved;

  @override
  Future<void> saveSavedPins(Set<String> ids) async => saved = ids;

  final Map<String, Set<String>> following = {};

  @override
  Future<Set<String>> loadFollowing(String uid) async =>
      following[uid] ?? {};

  @override
  Future<void> saveFollowing(String uid, Set<String> ownerIds) async =>
      following[uid] = ownerIds;

  PrivacySettings privacy = const PrivacySettings();

  @override
  Future<PrivacySettings> loadPrivacy() async => privacy;

  @override
  Future<void> savePrivacy(PrivacySettings settings) async =>
      privacy = settings;

  final Map<String, ({String lastDate, int streak})> streaks = {};

  @override
  Future<({String lastDate, int streak})> loadLoginStreak(String uid) async =>
      streaks[uid] ?? (lastDate: '', streak: 0);

  @override
  Future<void> saveLoginStreak(String uid, String lastDate, int streak) async =>
      streaks[uid] = (lastDate: lastDate, streak: streak);

  final Map<String, Set<String>> unlocked = {};

  @override
  Future<Set<String>> loadUnlockedPins(String uid) async =>
      unlocked[uid] ?? {};

  @override
  Future<void> saveUnlockedPins(String uid, Set<String> ids) async =>
      unlocked[uid] = ids;
}

/// テスト用の通報シンク（メモリ保持）。
class FakeReportSink implements ReportSink {
  final List<ReportModel> submitted = [];

  @override
  Future<void> submit(ReportModel report) async => submitted.add(report);

  @override
  Future<List<ReportModel>> all() async => List.of(submitted);

  @override
  Future<void> updateStatus(String reportId, ReportStatus status) async {
    final i = submitted.indexWhere((r) => r.id == reportId);
    if (i >= 0) submitted[i] = submitted[i].copyWith(status: status);
  }
}

/// テスト用の認証（既定でログイン済みのユーザーを返す）。
class FakeAuthService implements AuthService {
  FakeAuthService([String uid = 'test-uid'])
      : _user = AppUser(
            uid: uid, email: '$uid@example.com', displayName: uid);

  AppUser? _user;

  @override
  Future<AppUser?> currentUser() async => _user;

  @override
  Future<AppUser> signUp({
    required String username,
    required String password,
    required String displayName,
    String email = '',
  }) async {
    _user = AppUser(
        uid: _user?.uid ?? 'test-uid',
        email: email,
        displayName: displayName,
        username: username);
    return _user!;
  }

  @override
  Future<AppUser> signIn(
          {required String username, required String password}) async =>
      _user!;

  @override
  Future<AppUser> updateProfile(
      {String? displayName,
      String? username,
      String? bio,
      String? avatarPath}) async {
    _user = _user!.copyWith(
        displayName: displayName,
        username: username,
        bio: bio,
        avatarPath: avatarPath);
    return _user!;
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> deleteAccount() async => _user = null;
}

/// テスト用のアカウント名簿。
class FakeAccountDirectory implements AccountDirectory {
  FakeAccountDirectory([List<Account>? accounts])
      : _accounts = accounts ??
            const [
              Account(
                  uid: 'acc1',
                  username: 'acc1',
                  displayName: 'Acc One',
                  followerCountBase: 10,
                  followsBack: true),
              Account(
                  uid: 'acc2',
                  username: 'acc2',
                  displayName: 'Acc Two',
                  followerCountBase: 5,
                  followsBack: false),
            ];
  final List<Account> _accounts;

  @override
  Future<List<Account>> all() async => _accounts;
}

/// テスト用の課金ゲートウェイ。
/// [storeAvailable] が false のとき buy* は false を返し、Provider 側の
/// モックフォールバック経路を検証できる。
class FakePurchaseGateway implements PurchaseGateway {
  FakePurchaseGateway({this.storeAvailable = false});

  final bool storeAvailable;

  @override
  void Function(int count)? onWarpTicketsDelivered;
  @override
  void Function(int amount, GiftReceipt? receipt)? onTipDelivered;
  @override
  void Function(String message)? onError;

  int buyWarpCalls = 0;
  int buyTipCalls = 0;

  @override
  bool get isAvailable => storeAvailable;

  @override
  String? priceOf(String productId) => storeAvailable ? '¥320' : null;

  @override
  Future<void> init() async {}

  @override
  Future<bool> buyWarpPack() async {
    buyWarpCalls++;
    return storeAvailable;
  }

  @override
  Future<bool> buyTip(int amount) async {
    buyTipCalls++;
    return storeAvailable;
  }

  @override
  void dispose() {}
}
