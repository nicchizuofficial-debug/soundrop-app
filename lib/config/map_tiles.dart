/// 地図タイルの提供元設定。
///
/// 本番は MapTiler / Stadia（無料枠＋APIキー）のダークスタイルを推奨。
/// キー未設定時は開発用に CARTO Dark（キー不要）へフォールバックする。
///
/// キーの渡し方（コミットせずビルド時に注入）:
///   flutter run --dart-define=MAPTILER_KEY=xxxxx
///   flutter build apk --dart-define=MAPTILER_KEY=xxxxx
///   （Stadia を使う場合は --dart-define=STADIA_KEY=xxxxx）
class MapTiles {
  /// 自前配信（例: Cloudflare R2 + Protomaps Worker）のタイルURL。最優先。
  /// 例: --dart-define=TILE_URL=https://tiles.example.com/{z}/{x}/{y}.png
  static const _customUrl =
      String.fromEnvironment('TILE_URL', defaultValue: '');
  static const _customAttribution =
      String.fromEnvironment('TILE_ATTRIBUTION',
          defaultValue: '© OpenStreetMap');

  static const _maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static const _stadiaKey =
      String.fromEnvironment('STADIA_KEY', defaultValue: '');

  /// 本番用の配信元が設定されているか。
  static bool get hasProductionKey =>
      _customUrl.isNotEmpty || _maptilerKey.isNotEmpty || _stadiaKey.isNotEmpty;

  /// タイルURLテンプレート。
  static String get urlTemplate {
    if (_customUrl.isNotEmpty) return _customUrl; // 自前配信が最優先
    if (_maptilerKey.isNotEmpty) {
      // MapTiler「DataViz Dark」スタイル（ダーク・ラベル付き）。
      return 'https://api.maptiler.com/maps/dataviz-dark/{z}/{x}/{y}.png'
          '?key=$_maptilerKey';
    }
    if (_stadiaKey.isNotEmpty) {
      // Stadia「Alidade Smooth Dark」。
      return 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/'
          '{z}/{x}/{y}.png?api_key=$_stadiaKey';
    }
    // フォールバック（開発用・キー不要）: CARTO Dark。
    return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
  }

  /// CARTO フォールバック時のみサブドメインが必要（{s}）。
  static List<String> get subdomains =>
      hasProductionKey ? const [] : const ['a', 'b', 'c', 'd'];

  /// 出典表記。
  static String get attribution {
    if (_customUrl.isNotEmpty) return _customAttribution;
    if (_maptilerKey.isNotEmpty) return '© MapTiler © OpenStreetMap';
    if (_stadiaKey.isNotEmpty) return '© Stadia Maps © OpenStreetMap';
    return '© OpenStreetMap © CARTO';
  }
}
