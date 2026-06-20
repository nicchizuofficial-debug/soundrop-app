import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// プロフィール画像のアバター。
/// [imagePath] があればその画像、無ければ頭文字を表示する。
class UserAvatar extends StatelessWidget {
  final String imagePath;
  final String name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    this.imagePath = '',
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navyElevated,
      backgroundImage: hasImage ? FileImage(File(imagePath)) : null,
      child: hasImage
          ? null
          : Text(
              name.isEmpty ? '?' : name.substring(0, 1),
              style: TextStyle(
                  color: Colors.white, fontSize: radius * 0.8),
            ),
    );
  }
}
