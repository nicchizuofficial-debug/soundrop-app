import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 画面をまたいで使う小さな UI 部品。
///
/// 見た目の基準（余白・角丸・色）をここに集め、各画面は組み立てに専念する。

/// 見出し付きのグループカード（設定画面などの「ひとまとまり」）。
/// 子同士の間には細い区切り線を自動で入れる。
class SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SectionCard({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 20),
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(height: 1, indent: 56, endIndent: 0));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) SectionLabel(title!),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: items),
          ),
        ],
      ),
    );
  }
}

/// セクション見出し（小さめ・ピンク）。
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.pink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.4)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 一覧が空のときの案内（アイコン・見出し・説明・任意のアクション）。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navySurface,
                border: Border.all(color: AppColors.outline),
              ),
              child: Center(child: GradientMask(child: Icon(icon, size: 34))),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.6, color: AppColors.textMuted)),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 色付きの小さなラベル（相互フォロー・公開状態など）。
class AppTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool dot;

  const AppTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// 一覧の行に置くコンパクトなフォローボタン。
/// （テーマの主ボタンは高さ52なので、行内では小さい専用ボタンを使う）
class FollowButton extends StatelessWidget {
  final bool following;
  final VoidCallback onPressed;
  final bool large;

  const FollowButton({
    super.key,
    required this.following,
    required this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? const Size(140, 46) : const Size(88, 36);
    final pad = EdgeInsets.symmetric(horizontal: large ? 20 : 14);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(40));
    final text =
        TextStyle(fontSize: large ? 15 : 13, fontWeight: FontWeight.w700);
    if (following) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: pad,
          shape: shape,
          textStyle: text,
        ),
        onPressed: onPressed,
        child: const Text('フォロー中'),
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: size,
        padding: pad,
        shape: shape,
        textStyle: text,
        backgroundColor: AppColors.pink,
        foregroundColor: AppColors.navy,
      ),
      onPressed: onPressed,
      child: const Text('フォロー'),
    );
  }
}

/// 数値＋ラベルの統計（フォロワー数など）。タップ可能。
class StatItem extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('$value',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「3時間前」「2日前」などの相対時刻。
String relativeTime(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.isNegative) return 'たった今';
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes}分前';
  if (d.inDays < 1) return '${d.inHours}時間前';
  if (d.inDays < 7) return '${d.inDays}日前';
  return '${t.month}月${t.day}日';
}
