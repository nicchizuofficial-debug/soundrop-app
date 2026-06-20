/// ドロップの公開範囲。
enum DropVisibility { followers, mutual }

/// 投稿位置の精度（防犯：ぼかし）。
enum LocationPrecision { exact, approximate }

/// プライバシー設定（X等を参考にした項目）。
class PrivacySettings {
  /// 既定の公開範囲（フォロワー / 相互フォローのみ）。
  final DropVisibility visibility;

  /// ユーザー名で自分を検索可能にする。
  final bool findableByUsername;

  /// メールアドレスで自分を検索可能にする。
  final bool findableByEmail;

  /// 投稿位置の精度（ぼかし）。
  final LocationPrecision locationPrecision;

  /// フォローを承認制にする（非公開アカウント）。
  final bool protectedAccount;

  const PrivacySettings({
    this.visibility = DropVisibility.followers,
    this.findableByUsername = true,
    this.findableByEmail = false,
    this.locationPrecision = LocationPrecision.exact,
    this.protectedAccount = false,
  });

  PrivacySettings copyWith({
    DropVisibility? visibility,
    bool? findableByUsername,
    bool? findableByEmail,
    LocationPrecision? locationPrecision,
    bool? protectedAccount,
  }) =>
      PrivacySettings(
        visibility: visibility ?? this.visibility,
        findableByUsername: findableByUsername ?? this.findableByUsername,
        findableByEmail: findableByEmail ?? this.findableByEmail,
        locationPrecision: locationPrecision ?? this.locationPrecision,
        protectedAccount: protectedAccount ?? this.protectedAccount,
      );

  Map<String, dynamic> toJson() => {
        'visibility': visibility.name,
        'findableByUsername': findableByUsername,
        'findableByEmail': findableByEmail,
        'locationPrecision': locationPrecision.name,
        'protectedAccount': protectedAccount,
      };

  factory PrivacySettings.fromJson(Map<String, dynamic> j) => PrivacySettings(
        visibility: DropVisibility.values.firstWhere(
            (e) => e.name == j['visibility'],
            orElse: () => DropVisibility.followers),
        findableByUsername: j['findableByUsername'] as bool? ?? true,
        findableByEmail: j['findableByEmail'] as bool? ?? false,
        locationPrecision: LocationPrecision.values.firstWhere(
            (e) => e.name == j['locationPrecision'],
            orElse: () => LocationPrecision.exact),
        protectedAccount: j['protectedAccount'] as bool? ?? false,
      );
}
