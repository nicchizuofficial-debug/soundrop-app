import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// プロフィール画像のアバター。
/// [imagePath] がローカルファイルかURLならその画像、無ければ頭文字を表示する。
class UserAvatar extends StatelessWidget {
  final String imagePath;
  final String name;
  final double radius;

  /// ブランドグラデーションの縁取りを付ける（プロフィールの主役表示用）。
  final bool ring;

  const UserAvatar({
    super.key,
    required this.name,
    this.imagePath = '',
    this.radius = 20,
    this.ring = false,
  });

  ImageProvider? _image() {
    if (imagePath.isEmpty) return null;
    // Firebase 版は Storage のダウンロードURLが入るため、URLも表示できるようにする。
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return NetworkImage(imagePath);
    }
    final f = File(imagePath);
    return f.existsSync() ? FileImage(f) : null;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image();
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navyElevated,
      backgroundImage: image,
      onBackgroundImageError: image == null ? null : (_, __) {},
      child: image != null
          ? null
          : GradientMask(
              child: Text(
                initial.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.85,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
    if (!ring) return avatar;
    final w = radius < 30 ? 2.0 : 3.0;
    return Container(
      padding: EdgeInsets.all(w),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brand,
      ),
      child: Container(
        padding: EdgeInsets.all(w),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.navy,
        ),
        child: avatar,
      ),
    );
  }
}
