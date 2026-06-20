import 'package:flutter/material.dart';

/// アプリのブランドカラー（アイコンに準拠）。
/// ダークネイビー背景に、ピンク→ブルーのグラデーションをアクセントに使う。
class AppColors {
  static const navy = Color(0xFF1D2A4C); // 背景（アイコンPNGの紺と一致）
  static const navySurface = Color(0xFF232C56); // カード/サーフェス
  static const navyElevated = Color(0xFF2C376B);
  static const pink = Color(0xFFF2A8CF);
  static const blue = Color(0xFF8FB4E8);

  /// ブランドのグラデーション（ピン→波形と同じ流れ）。
  static const brand = LinearGradient(
    colors: [pink, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// アプリ全体のダークテーマ。
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.blue,
    secondary: AppColors.pink,
    surface: AppColors.navySurface,
    surfaceContainerHighest: AppColors.navyElevated,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.navy,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.navySurface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.navySurface,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: const ChipThemeData(
      side: BorderSide(color: AppColors.blue),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
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
