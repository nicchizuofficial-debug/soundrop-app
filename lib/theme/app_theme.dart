import 'package:flutter/material.dart';

/// アプリのブランドカラー（アイコンに準拠）。
/// ダークネイビー背景に、ピンク→ブルーのグラデーションをアクセントに使う。
class AppColors {
  static const navy = Color(0xFF1D2A4C); // 背景（アイコンPNGの紺と一致）
  static const navySurface = Color(0xFF232C56); // カード/サーフェス
  static const navyElevated = Color(0xFF2C376B);
  static const pink = Color(0xFFF2A8CF);
  static const blue = Color(0xFF8FB4E8);

  /// 補助テキスト（説明文など）。白の不透明度違いで階層を作る。
  static const textMuted = Color(0xB3FFFFFF); // 70%
  static const outline = Color(0x33FFFFFF); // 20%
  static const danger = Color(0xFFFF7A8A);

  /// ドロップの状態色（地図ピン・一覧・プロフィールで共通）。
  /// ブランドのパステル調に合わせ、彩度を揃えている。
  static const unlocked = Color(0xFF7FDBC8); // 解禁済み（聴ける）
  static const locked = Color(0xFFAFA6F2); // 未解禁
  static const pending = Color(0xFFF6C177); // 公開待ち

  /// ブランドのグラデーション（ピン→波形と同じ流れ）。
  static const brand = LinearGradient(
    colors: [pink, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// 角丸の統一値。
class AppRadius {
  static const field = 14.0;
  static const button = 14.0;
  static const card = 18.0;
  static const sheet = 24.0;
}

/// アプリ全体のダークテーマ。
///
/// 入力欄・ボタン・カード等の見た目はここで一括定義し、画面側では
/// 個別に border や shape を指定しない（画面ごとの見た目のバラつきを防ぐ）。
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.blue,
    onPrimary: AppColors.navy,
    secondary: AppColors.pink,
    onSecondary: AppColors.navy,
    surface: AppColors.navySurface,
    surfaceContainerHighest: AppColors.navyElevated,
    error: AppColors.danger,
    outline: AppColors.outline,
    outlineVariant: AppColors.outline,
  );

  final fieldRadius = BorderRadius.circular(AppRadius.field);
  final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button));
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.navy,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
    ),

    // ---- 入力欄：塗りつぶし＋角丸、フォーカス時のみブランド色の枠 ----
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.navySurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: AppColors.textMuted,
      suffixIconColor: AppColors.textMuted,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.blue),
      border: OutlineInputBorder(
          borderRadius: fieldRadius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6)),
    ),

    // ---- ボタン：高さと角丸を統一 ----
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: buttonShape,
        textStyle: buttonText,
        side: const BorderSide(color: AppColors.outline),
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    cardTheme: CardThemeData(
      color: AppColors.navySurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.blue),
    dividerTheme:
        const DividerThemeData(color: AppColors.outline, thickness: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.navySurface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.outline,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.navySurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.navyElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: AppColors.outline),
      selectedColor: AppColors.blue.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.blue.withValues(alpha: 0.25),
        selectedForegroundColor: Colors.white,
        foregroundColor: AppColors.textMuted,
        side: const BorderSide(color: AppColors.outline),
        minimumSize: const Size(0, 48),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
      linearTrackColor: AppColors.navyElevated,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navyElevated,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      actionTextColor: AppColors.pink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// 子（テキスト/アイコン）にブランドグラデーションを乗せるヘルパー。
class GradientMask extends StatelessWidget {
  final Widget child;
  final Gradient gradient;

  const GradientMask({
    super.key,
    required this.child,
    this.gradient = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }
}

/// ブランドグラデーションの主要ボタン（ドロップ・ログインなど画面の主役アクション）。
///
/// 影は Material の外側に置く。Ink の影は Material の矩形にクリップされ、
/// 角丸ボタンの背後に四角い影が出てしまうため。
class GradientButton extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(height / 2);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || loading ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppColors.brand),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: padding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: AppColors.navy),
                        )
                      else if (icon != null)
                        IconTheme(
                          data: const IconThemeData(color: AppColors.navy),
                          child: icon!,
                        ),
                      if (loading || icon != null) const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
