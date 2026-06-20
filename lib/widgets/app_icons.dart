import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Material アイコンにブランドグラデーションを乗せた、おしゃれな汎用アイコン。
///
/// アプリ全体のアイコン（ワープ/鍵/応援/現在地など）をこれで統一する。
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.gradient = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// アプリで使うアイコンの意味づけ（角丸系で統一）。
class AppIcons {
  AppIcons._();

  static const warpTicket = Icons.bolt_rounded; // ワープチケット
  static const locked = Icons.lock_rounded; // 鍵（未解禁）
  static const unlocked = Icons.graphic_eq_rounded; // 解禁（音声）
  static const pending = Icons.hourglass_top_rounded; // 公開待ち
  static const support = Icons.volunteer_activism_rounded; // 応援を贈る（投げ銭）
  static const myLocation = Icons.near_me_rounded; // 現在地
  static const drop = Icons.mic_none_rounded; // ドロップ（録音）
  static const spark = Icons.auto_awesome; // きらめき（demo: spark / ちいさな拍手）
  static const star = Icons.star_rounded; // 星（demo: star / 最高のサウンドに）
}
