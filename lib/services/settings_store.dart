import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/privacy_settings.dart';

/// ユーザー単位の軽量設定（所持チケット・ブロック/通報など）の保存先。
/// テストではフェイク実装に差し替えられるよう抽象化している。
abstract class SettingsStore {
  /// ワープチケットの有効期限(ISO8601)一覧（ユーザー単位）。1要素=1枚。
  /// null=未設定（初回）。期限により前払式支払手段の論点を回避する
  /// （docs/operator_legal.md）。
  Future<List<String>?> loadTicketExpiries(String uid);
  Future<void> saveTicketExpiries(String uid, List<String> isoExpiries);

  /// ブロックした投稿者ID（これらの投稿は地図/一覧から除外する）。
  Future<Set<String>> loadBlockedAuthors();
  Future<void> saveBlockedAuthors(Set<String> ids);

  /// 通報したピンID（ローカルで即時非表示にする）。
  Future<Set<String>> loadReportedPins();
  Future<void> saveReportedPins(Set<String> ids);

  /// 保存（お気に入り）したピンID。
  Future<Set<String>> loadSavedPins();
  Future<void> saveSavedPins(Set<String> ids);

  /// フォロー中のアカウント（ユーザー単位）。
  Future<Set<String>> loadFollowing(String uid);
  Future<void> saveFollowing(String uid, Set<String> ownerIds);

  /// プライバシー設定。
  Future<PrivacySettings> loadPrivacy();
  Future<void> savePrivacy(PrivacySettings settings);

  /// 連続ログイン記録（ユーザー単位）。lastDate は 'yyyy-MM-dd'。
  Future<({String lastDate, int streak})> loadLoginStreak(String uid);
  Future<void> saveLoginStreak(String uid, String lastDate, int streak);

  /// 解禁済みピンID（ユーザー単位）。共有ドキュメントに入れず端末に持つ。
  Future<Set<String>> loadUnlockedPins(String uid);
  Future<void> saveUnlockedPins(String uid, Set<String> ids);
}

/// SharedPreferences 実装。
class PrefsSettingsStore implements SettingsStore {
  static const _ticketsKeyPrefix = 'warp_ticket_expiries_v1_';
  static const _blockedKey = 'blocked_authors_v1';
  static const _reportedKey = 'reported_pins_v1';
  static const _savedKey = 'saved_pins_v1';

  @override
  Future<List<String>?> loadTicketExpiries(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_ticketsKeyPrefix$uid'); // 未設定なら null
  }

  @override
  Future<void> saveTicketExpiries(String uid, List<String> isoExpiries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_ticketsKeyPrefix$uid', isoExpiries);
  }

  @override
  Future<Set<String>> loadBlockedAuthors() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_blockedKey) ?? const []).toSet();
  }

  @override
  Future<void> saveBlockedAuthors(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedKey, ids.toList());
  }

  @override
  Future<Set<String>> loadReportedPins() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_reportedKey) ?? const []).toSet();
  }

  @override
  Future<void> saveReportedPins(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reportedKey, ids.toList());
  }

  @override
  Future<Set<String>> loadSavedPins() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_savedKey) ?? const []).toSet();
  }

  @override
  Future<void> saveSavedPins(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedKey, ids.toList());
  }

  @override
  Future<Set<String>> loadFollowing(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('following_$uid') ?? const []).toSet();
  }

  @override
  Future<void> saveFollowing(String uid, Set<String> ownerIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('following_$uid', ownerIds.toList());
  }

  @override
  Future<PrivacySettings> loadPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('privacy_v1');
    if (raw == null || raw.isEmpty) return const PrivacySettings();
    return PrivacySettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> savePrivacy(PrivacySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('privacy_v1', jsonEncode(settings.toJson()));
  }

  @override
  Future<({String lastDate, int streak})> loadLoginStreak(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (
      lastDate: prefs.getString('login_last_$uid') ?? '',
      streak: prefs.getInt('login_streak_$uid') ?? 0,
    );
  }

  @override
  Future<void> saveLoginStreak(
      String uid, String lastDate, int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_last_$uid', lastDate);
    await prefs.setInt('login_streak_$uid', streak);
  }

  @override
  Future<Set<String>> loadUnlockedPins(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('unlocked_$uid') ?? const []).toSet();
  }

  @override
  Future<void> saveUnlockedPins(String uid, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('unlocked_$uid', ids.toList());
  }
}
