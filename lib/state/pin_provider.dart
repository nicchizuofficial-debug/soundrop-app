import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app_config.dart';
import '../models/account.dart';
import '../models/app_user.dart';
import '../models/pin_model.dart';
import '../models/privacy_settings.dart';
import '../models/report_model.dart';
import '../services/account_directory.dart';
import '../services/auth_service.dart';
import '../services/gift_backend.dart';
import '../services/payout_service.dart';
import '../services/pin_data_source.dart';
import '../services/purchase_gateway.dart';
import '../services/purchase_service.dart';
import '../services/report_sink.dart';
import '../services/settings_store.dart';
import '../utils/geo_utils.dart';

/// 位置情報パーミッションの状態（UI出し分け用）。
enum LocationStatus { unknown, granted, denied, deniedForever, serviceOff }

/// アプリ全体の状態とロジック。
///
/// 永続化/同期は [PinDataSource]、認証は [AuthService]、課金は [PurchaseGateway]、
/// 軽量設定は [SettingsStore] に委譲。すべて差し替え可能でテスト可能。
class PinProvider extends ChangeNotifier {
  PinProvider({
    PinDataSource? dataSource,
    SettingsStore? settingsStore,
    PurchaseGateway? purchaseGateway,
    AuthService? authService,
    ReportSink? reportSink,
    AccountDirectory? accountDirectory,
    PayoutService? payoutService,
    GiftBackend? giftBackend,
  })  : _dataSource = dataSource ?? createPinDataSource(),
        _settings = settingsStore ?? PrefsSettingsStore(),
        _purchase = purchaseGateway ?? PurchaseService(),
        _auth = authService ?? createAuthService(),
        _reports = reportSink ?? createReportSink(),
        _directory = accountDirectory ?? createAccountDirectory(),
        _payout = payoutService ?? createPayoutService(),
        _gifts = giftBackend ?? createGiftBackend();

  final PinDataSource _dataSource;
  final SettingsStore _settings;
  final PurchaseGateway _purchase;
  final AuthService _auth;
  final ReportSink _reports;
  final AccountDirectory _directory;
  final PayoutService _payout;
  final GiftBackend _gifts;

  PayoutService get payout => _payout;

  StreamSubscription<List<PinModel>>? _pinsSub;

  /// ワープチケットの有効期限。1要素=1枚（有効=now以降）。
  static const Duration ticketTtl = Duration(days: 180);

  List<PinModel> _pins = [];
  LatLng? _currentLatLng;
  List<DateTime> _ticketExpiries = [];
  bool _loaded = false;
  AppUser? _user;
  String? _pendingTipPinId;
  Set<String> _blockedAuthors = {};
  Set<String> _reportedPins = {};
  Set<String> _savedPins = {};
  Set<String> _following = {};
  Set<String> _unlockedPinIds = {}; // この端末/ユーザーで解禁済みのピンID
  List<Account> _accounts = [];
  PrivacySettings _privacy = const PrivacySettings();
  int _loginStreak = 0;
  int _pendingRewardTickets = 0;
  LocationStatus _locationStatus = LocationStatus.unknown;

  LatLng? get currentLatLng => _currentLatLng;
  int get warpTickets => _validTicketCount();
  bool get isLoaded => _loaded;
  AppUser? get currentUser => _user;
  String? get currentUid => _user?.uid;
  bool get isAuthenticated => _user != null;
  PurchaseGateway get purchase => _purchase;
  LocationStatus get locationStatus => _locationStatus;
  List<PinModel> get allPins => List.unmodifiable(_pins);

  /// このピンが自分の投稿か（uid で判定）。
  bool isMine(PinModel p) {
    final uid = _user?.uid;
    if (uid != null && p.ownerId.isNotEmpty) return p.ownerId == uid;
    return false;
  }

  /// この投稿者をフォローしているか。
  bool isFollowing(String ownerId) => _following.contains(ownerId);

  /// フィードに表示してよいか：自分の投稿 or フォロー中アカウントのみ。
  bool _inFeed(PinModel p) => isMine(p) || isFollowing(p.ownerId);

  /// 名簿の全アカウント（自分以外）。
  List<Account> get accounts =>
      _accounts.where((a) => a.uid != _user?.uid).toList();

  /// フォロー中のアカウント一覧。
  List<Account> get followingAccounts =>
      accounts.where((a) => isFollowing(a.uid)).toList();

  /// 自分をフォローしているアカウント一覧（フォロワー）。
  List<Account> get followerAccounts =>
      accounts.where((a) => a.followsBack).toList();

  /// ブロック中のアカウント（名簿に無ければIDを名前として返す）。
  List<({String uid, String name})> get blockedAccounts => _blockedAuthors
      .map((uid) => (uid: uid, name: accountOf(uid)?.displayName ?? uid))
      .toList();

  /// 連続ログイン日数。
  int get loginStreak => _loginStreak;

  /// 直近で付与された連続ログイン報酬（UI通知用、読み取りで消費）。
  int consumePendingReward() {
    final v = _pendingRewardTickets;
    _pendingRewardTickets = 0;
    return v;
  }

  /// 連続ログインを判定し、7日ごとにワープチケットを1枚付与する。
  Future<void> _applyDailyLogin() async {
    final uid = _user?.uid;
    if (uid == null) return;
    final info = await _settings.loadLoginStreak(uid);
    final today = _ymd(DateTime.now());
    if (info.lastDate == today) {
      _loginStreak = info.streak; // 本日は判定済み
      return;
    }
    final yesterday = _ymd(DateTime.now().subtract(const Duration(days: 1)));
    final streak = (info.lastDate == yesterday) ? info.streak + 1 : 1;
    await _settings.saveLoginStreak(uid, today, streak);
    _loginStreak = streak;
    if (streak % 7 == 0) {
      _addTickets(1); // 7日連続でワープ1枚
      _pendingRewardTickets += 1;
    }
    notifyListeners();
  }

  // ---- ワープチケット（有効期限つき） ----

  int _validTicketCount() {
    final now = DateTime.now();
    return _ticketExpiries.where((e) => e.isAfter(now)).length;
  }

  Future<void> _loadTickets(String uid) async {
    final stored = await _settings.loadTicketExpiries(uid);
    if (stored == null) {
      // 初回付与：2枚（180日有効）。
      _ticketExpiries =
          List.generate(2, (_) => DateTime.now().add(ticketTtl));
      await _settings.saveTicketExpiries(uid, _isoTickets());
    } else {
      _ticketExpiries = stored.map(DateTime.parse).toList();
      _purgeExpiredTickets();
    }
  }

  List<String> _isoTickets() =>
      _ticketExpiries.map((e) => e.toIso8601String()).toList();

  void _persistTickets() {
    final uid = _user?.uid;
    if (uid != null) _settings.saveTicketExpiries(uid, _isoTickets());
  }

  void _purgeExpiredTickets() {
    final now = DateTime.now();
    final before = _ticketExpiries.length;
    _ticketExpiries = _ticketExpiries.where((e) => e.isAfter(now)).toList();
    if (_ticketExpiries.length != before) _persistTickets();
  }

  /// チケットを n 枚付与（180日有効）。
  void _addTickets(int n) {
    final exp = DateTime.now().add(ticketTtl);
    _ticketExpiries.addAll(List.filled(n, exp));
    _persistTickets();
    notifyListeners();
  }

  /// 最も早く失効する有効チケットを1枚消費。無ければ false。
  bool _useOneTicket() {
    _purgeExpiredTickets();
    _ticketExpiries.sort((a, b) => a.compareTo(b));
    final now = DateTime.now();
    final idx = _ticketExpiries.indexWhere((e) => e.isAfter(now));
    if (idx < 0) return false;
    _ticketExpiries.removeAt(idx);
    _persistTickets();
    return true;
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// プライバシー設定。
  PrivacySettings get privacy => _privacy;
  Future<void> updatePrivacy(PrivacySettings settings) async {
    _privacy = settings;
    await _settings.savePrivacy(settings);
    notifyListeners();
  }

  /// ユーザー名／表示名で検索。
  List<Account> searchAccounts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return accounts;
    return accounts
        .where((a) =>
            a.username.toLowerCase().contains(q) ||
            a.displayName.toLowerCase().contains(q))
        .toList();
  }

  Account? accountOf(String uid) {
    for (final a in _accounts) {
      if (a.uid == uid) return a;
    }
    return null;
  }

  /// アカウントのフォロワー数（自分がフォローしていれば+1）。
  int followerCount(String uid) {
    final base = accountOf(uid)?.followerCountBase ?? 0;
    return base + (isFollowing(uid) ? 1 : 0);
  }

  /// 相互フォローか（自分がフォロー && 相手もフォローバック）。
  bool isMutual(String uid) =>
      isFollowing(uid) && (accountOf(uid)?.followsBack ?? false);

  /// 自分のフォロー数／フォロワー数（フォローバックしている人数）。
  // 名簿から消えたアカウント（例: 隠されたデモアカウント）へのフォローIDが
  // _following に残っていても数えないよう、一覧（followingAccounts）と揃える。
  int get myFollowingCount => followingAccounts.length;
  int get myFollowerCount =>
      _accounts.where((a) => a.followsBack).length;

  /// 指定アカウントの公開ドロップ（プロフィール表示用）。
  List<PinModel> pinsByOwner(String uid) {
    final now = DateTime.now();
    final list = _pins
        .where((p) => p.ownerId == uid && p.isVisibleAt(now) && !p.hidden)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool isBlocked(PinModel p) => _blockedAuthors.contains(p.ownerId);
  bool isReported(PinModel p) => _reportedPins.contains(p.id);

  /// 安全フィルタ：ブロック相手・通報済み・運営非表示は除外。自分の投稿は常に残す。
  bool _passesSafety(PinModel p) =>
      isMine(p) || (!isBlocked(p) && !isReported(p) && !p.hidden);

  /// 自分の投稿（マイドロップ）。新しい順。
  List<PinModel> get myPins {
    final mine = _pins.where(isMine).toList();
    mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  /// クリエイター収益：自分のドロップに集まった応援の総額・件数（グロス）。
  int get myGrossEarnings =>
      myPins.fold(0, (s, p) => s + p.totalTipAmount);
  int get myGiftsReceived => myPins.fold(0, (s, p) => s + p.giftCount);

  /// 保存（お気に入り）したピンか。
  bool isSaved(PinModel p) => _savedPins.contains(p.id);

  /// 保存済みのピン一覧（現存するもの）。
  List<PinModel> get savedPins =>
      _pins.where((p) => _savedPins.contains(p.id)).toList();

  /// 解禁したドロップの保存をトグルする。
  Future<void> toggleSaved(String pinId) async {
    if (_savedPins.contains(pinId)) {
      _savedPins = {..._savedPins}..remove(pinId);
    } else {
      _savedPins = {..._savedPins, pinId};
    }
    await _settings.saveSavedPins(_savedPins);
    notifyListeners();
  }

  /// 地図に描画してよいピン。
  /// フォロー中アカウント or 自分の投稿、かつ（公開済み or 自分）、かつ安全フィルタ通過。
  List<PinModel> get visiblePins {
    final now = DateTime.now();
    return _pins
        .where((p) =>
            _inFeed(p) && (p.isVisibleAt(now) || isMine(p)) && _passesSafety(p))
        .toList();
  }

  // ---- 初期化 ----

  Future<void> init() async {
    _user = await _auth.currentUser(); // 自動ログインはしない（メール登録必須）
    _blockedAuthors = await _settings.loadBlockedAuthors();
    _reportedPins = await _settings.loadReportedPins();
    _savedPins = await _settings.loadSavedPins();
    _privacy = await _settings.loadPrivacy();
    _accounts = await _directory.all();
    if (_user != null) {
      await _loadTickets(_user!.uid);
      _following = await _settings.loadFollowing(_user!.uid);
      _unlockedPinIds = await _settings.loadUnlockedPins(_user!.uid);
      await _applyDailyLogin();
    }

    // Firebase はピン購読に認証が必要（ルール: read は auth 必須）。
    // 未ログインで購読すると permission-denied になるため、ログイン後に開始する。
    // ローカルモードは認証不要なので即購読（既存挙動を維持）。
    if (!AppConfig.useFirebase || _user != null) {
      _startPinSubscription();
    } else {
      // 未ログイン Firebase: ピンはログイン後に読み込む。
      // ここで loaded を立てないとスプラッシュが進めず固まる。
      _loaded = true;
    }

    _purchase
      ..onWarpTicketsDelivered = _deliverWarpTickets
      ..onTipDelivered = (amount, receipt) => _onTipDelivered(amount, receipt);
    await _purchase.init();
  }

  // ---- 認証（メール登録必須） ----

  /// ピン購読を開始（多重購読しない）。
  void _startPinSubscription() {
    if (_pinsSub != null) return;
    _pinsSub = _dataSource.watchPins().listen((pins) {
      _pins = pins;
      _loaded = true;
      notifyListeners();
    });
  }

  Future<void> signUp({
    required String username,
    required String password,
    required String displayName,
    String email = '',
  }) async {
    _user = await _auth.signUp(
        username: username,
        password: password,
        displayName: displayName,
        email: email);
    await _loadTickets(_user!.uid);
    _following = await _settings.loadFollowing(_user!.uid);
    _unlockedPinIds = await _settings.loadUnlockedPins(_user!.uid);
    _startPinSubscription(); // ログイン後にピン購読を開始（Firebaseは認証必須）
    await _applyDailyLogin();
    notifyListeners();
  }

  /// パスワード再設定メールを送信する（ログイン前に使う想定）。
  Future<void> sendPasswordReset(String username) =>
      _auth.sendPasswordReset(username: username);

  Future<void> signIn(
      {required String username, required String password}) async {
    _user = await _auth.signIn(username: username, password: password);
    await _loadTickets(_user!.uid);
    _following = await _settings.loadFollowing(_user!.uid);
    _unlockedPinIds = await _settings.loadUnlockedPins(_user!.uid);
    _startPinSubscription();
    await _applyDailyLogin();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _following = {};
    _unlockedPinIds = {};
    _ticketExpiries = [];
    // Firebaseは未認証で読み続けると権限エラーになるため購読停止。
    if (AppConfig.useFirebase) {
      await _pinsSub?.cancel();
      _pinsSub = null;
      _pins = [];
    }
    notifyListeners();
  }

  /// アカウント削除（退会）。自分の投稿も削除する。App Store 要件。
  Future<void> deleteAccount() async {
    for (final p in myPins) {
      await _dataSource.deletePin(p.id);
    }
    await _auth.deleteAccount();
    _user = null;
    _following = {};
    _unlockedPinIds = {};
    _ticketExpiries = [];
    notifyListeners();
  }

  /// プロフィール（表示名・ユーザー名・自己紹介・画像）を更新。
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? avatarPath,
  }) async {
    _user = await _auth.updateProfile(
        displayName: displayName,
        username: username,
        bio: bio,
        avatarPath: avatarPath);
    notifyListeners();
  }

  // ---- フォロー ----

  Future<void> toggleFollow(String ownerId) async {
    if (_user == null || ownerId.isEmpty) return;
    if (_following.contains(ownerId)) {
      _following = {..._following}..remove(ownerId);
    } else {
      _following = {..._following, ownerId};
    }
    await _settings.saveFollowing(_user!.uid, _following);
    notifyListeners();
  }

  // ---- 位置情報 ----

  Future<void> updateCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationStatus = LocationStatus.serviceOff;
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _locationStatus = LocationStatus.deniedForever;
        notifyListeners();
        return;
      }
      if (permission == LocationPermission.denied) {
        _locationStatus = LocationStatus.denied;
        notifyListeners();
        return;
      }

      // 屋内などで高精度測位が長引くとタイムアウト。その場合は前回位置で代替。
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return; // 取得できず（状態は変えない）
      _currentLatLng = LatLng(pos.latitude, pos.longitude);
      _locationStatus = LocationStatus.granted;
      notifyListeners();
    } catch (_) {
      // プラットフォーム未対応（テスト等）や取得失敗時は状態を変えない。
    }
  }

  /// 現在地を手動設定（地図タップでの移動など）。
  void setManualLocation(double lat, double lng) {
    _currentLatLng = LatLng(lat, lng);
    _locationStatus = LocationStatus.granted;
    notifyListeners();
  }

  @visibleForTesting
  void setLocationForTest(double lat, double lng) =>
      setManualLocation(lat, lng);

  // ---- ドロップ ----

  PinModel? dropPin({
    required String audioPath,
    required String title,
    required Duration lockDuration,
    List<double> waveform = const [],
    int? trimStartMs,
    int? trimEndMs,
  }) {
    final loc = _currentLatLng;
    if (loc == null) return null;

    // 位置のぼかし（プライバシー）。approximate は約100m粗に丸める。
    double lat = loc.latitude, lng = loc.longitude;
    if (_privacy.locationPrecision == LocationPrecision.approximate) {
      lat = (lat * 1000).roundToDouble() / 1000;
      lng = (lng * 1000).roundToDouble() / 1000;
    }

    final now = DateTime.now();
    final pin = PinModel(
      id: 'pin_${now.millisecondsSinceEpoch}',
      authorName: _user?.displayName ?? 'あなた',
      ownerId: _user?.uid ?? '',
      title: title,
      latitude: lat,
      longitude: lng,
      audioUrl: audioPath,
      createdAt: now,
      visibleAt: now.add(lockDuration),
      waveform: waveform,
      trimStartMs: trimStartMs,
      trimEndMs: trimEndMs,
      isUnlocked: true,
      isOwn: true,
    );
    _pins = [..._pins, pin];
    notifyListeners();
    _dataSource.upsertPin(pin);
    return pin;
  }

  Future<void> deletePin(String id) async {
    _pins = _pins.where((p) => p.id != id).toList();
    notifyListeners();
    await _dataSource.deletePin(id);
  }

  // ---- 距離・解禁 ----

  double? distanceToPin(PinModel pin) {
    final loc = _currentLatLng;
    if (loc == null) return null;
    return distanceMeters(
        loc.latitude, loc.longitude, pin.latitude, pin.longitude);
  }

  bool isWithinUnlockRange(PinModel pin) {
    final d = distanceToPin(pin);
    if (d == null) return false;
    return d <= pin.unlockRadiusInMeters;
  }

  /// 再生可否。解禁状態は「端末ごと(_unlockedPinIds)」で持つため、
  /// 共有ドキュメントの isUnlocked を他ユーザーへ漏らさない。
  bool canPlay(PinModel pin) =>
      isMine(pin) ||
      _unlockedPinIds.contains(pin.id) ||
      isWithinUnlockRange(pin);

  /// この端末/ユーザーでピンを解禁済みにする（永続化）。
  void _markUnlocked(String pinId) {
    _unlockedPinIds = {..._unlockedPinIds, pinId};
    final uid = _user?.uid;
    if (uid != null) _settings.saveUnlockedPins(uid, _unlockedPinIds);
  }

  bool unlockByGps(String pinId) {
    final pin = _findPin(pinId);
    if (pin == null || !isWithinUnlockRange(pin)) return false;
    _markUnlocked(pin.id);
    _replacePin(pin.copyWith(isUnlocked: true));
    return true;
  }

  bool unlockByWarpTicket(String pinId) {
    final pin = _findPin(pinId);
    if (pin == null) return false;
    if (!_useOneTicket()) return false; // 有効チケットが無い
    _markUnlocked(pin.id);
    _replacePin(pin.copyWith(
      isUnlocked: true,
      warpUnlockCount: pin.warpUnlockCount + 1,
    ));
    return true;
  }

  // ---- 安全機能（通報・ブロック） ----

  /// ピンを通報する。
  /// 1) 構造化レコードを [ReportSink] へ送信（運営審査キューへ）
  /// 2) 端末ローカルで即時非表示
  Future<void> reportPin(PinModel pin, ReportReason reason,
      {String note = ''}) async {
    final record = ReportModel(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      pinId: pin.id,
      reportedOwnerId: pin.ownerId,
      reporterId: _user?.uid ?? '',
      reason: reason,
      note: note,
      createdAt: DateTime.now(),
    );
    await _reports.submit(record);

    _reportedPins = {..._reportedPins, pin.id};
    await _settings.saveReportedPins(_reportedPins);
    notifyListeners();
  }

  /// 投稿者をブロックする（以降その人の投稿を非表示）。
  Future<void> blockAuthor(String ownerId) async {
    if (ownerId.isEmpty) return;
    _blockedAuthors = {..._blockedAuthors, ownerId};
    await _settings.saveBlockedAuthors(_blockedAuthors);
    notifyListeners();
  }

  Future<void> unblockAuthor(String ownerId) async {
    _blockedAuthors = {..._blockedAuthors}..remove(ownerId);
    await _settings.saveBlockedAuthors(_blockedAuthors);
    notifyListeners();
  }

  // ---- 運営モデレーション ----

  /// 蓄積された通報一覧（新しい順）。
  Future<List<ReportModel>> loadReports() async {
    final list = await _reports.all();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 通報の審査ステータスを更新する。
  Future<void> updateReportStatus(String reportId, ReportStatus status) async {
    await _reports.updateStatus(reportId, status);
    notifyListeners();
  }

  // ---- 課金 ----

  Future<void> purchaseWarpPack() async {
    final started = await _purchase.buyWarpPack();
    if (!started) _deliverWarpTickets(3);
  }

  Future<void> purchaseTip(String pinId, int amount) async {
    _pendingTipPinId = pinId;
    final started = await _purchase.buyTip(amount);
    if (!started) _onTipDelivered(amount, null); // ストア不可→モック
  }

  void _deliverWarpTickets(int count) {
    _addTickets(count);
    notifyListeners();
  }

  /// 投げ銭の配布。ストア購入(receipt有)はサーバー検証→記帳に任せ、
  /// 失敗/未接続/モック(receipt無)はローカル加算でフォールバック。
  Future<void> _onTipDelivered(int amount, GiftReceipt? receipt) async {
    final pinId = _pendingTipPinId;
    if (pinId == null) return;
    final pin = _findPin(pinId);
    if (pin == null) {
      _pendingTipPinId = null;
      return;
    }
    if (receipt != null) {
      final ok = await _gifts.creditTip(
          receipt: receipt, pinId: pinId, toUid: pin.ownerId);
      if (ok) {
        // サーバーが pins/balances を更新→同期で反映。ローカル加算しない。
        _pendingTipPinId = null;
        return;
      }
    }
    // フォールバック（モック/未接続）。
    _replacePin(pin.copyWith(
      totalTipAmount: pin.totalTipAmount + amount,
      giftCount: pin.giftCount + 1,
    ));
    _pendingTipPinId = null;
  }

  // ---- 内部 ----

  PinModel? _findPin(String id) {
    for (final p in _pins) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _replacePin(PinModel updated) {
    _pins = _pins.map((p) => p.id == updated.id ? updated : p).toList();
    notifyListeners();
    _dataSource.upsertPin(updated);
  }

  @override
  void dispose() {
    _pinsSub?.cancel();
    _dataSource.dispose();
    _purchase.dispose();
    super.dispose();
  }
}
