import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pin_model.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/mini_waveform.dart';
import '../widgets/report_sheet.dart';
import 'moderation_screen.dart';

/// マイドロップ管理＋公開中ピン一覧の画面。
///
/// タブ構成:
///  - マイドロップ: 自分の投稿（公開待ち含む）。再生・削除・状態確認。
///  - 周辺/公開中: 公開時刻を過ぎたピン。解禁状態と投げ銭額を表示。
class MyDropsScreen extends StatelessWidget {
  const MyDropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ピン一覧'),
          // 運営用の通報審査画面。一般ユーザーには権限が無い（Firebaseモードでは
          // 一覧取得がUnsupportedErrorになる）ため、開発時のみ表示する。
          actions: [
            if (kDebugMode)
              IconButton(
                tooltip: 'モデレーション（運営・開発用）',
                icon: const Icon(Icons.shield_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ModerationScreen()),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'マイドロップ'),
              Tab(text: '公開中'),
              Tab(text: '保存済み'),
            ],
          ),
        ),
        body: Consumer<PinProvider>(
          builder: (context, provider, _) {
            final now = DateTime.now();
            final mine = provider.myPins;
            final published = provider.visiblePins
                .where((p) => p.isVisibleAt(now) && !provider.isMine(p))
                .toList();
            final saved = provider.savedPins;

            return TabBarView(
              children: [
                _PinList(
                  pins: mine,
                  emptyText: 'まだドロップがありません。\nマップの「ドロップ」から録音しましょう。',
                  isMine: true,
                ),
                _PinList(
                  pins: published,
                  emptyText: '公開中のピンがありません。',
                  isMine: false,
                ),
                _PinList(
                  pins: saved,
                  emptyText: '保存したドロップはありません。\n解禁後に「保存」できます。',
                  isMine: false,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinList extends StatelessWidget {
  final List<PinModel> pins;
  final String emptyText;
  final bool isMine;

  const _PinList({
    required this.pins,
    required this.emptyText,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      itemCount: pins.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) => _PinTile(pin: pins[i], isMine: isMine),
    );
  }
}

class _PinTile extends StatelessWidget {
  final PinModel pin;
  final bool isMine;

  const _PinTile({required this.pin, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PinProvider>();
    final now = DateTime.now();
    final pending = provider.isMine(pin) && !pin.isVisibleAt(now);
    final playable = provider.canPlay(pin);

    final (IconData icon, Color color, String status) = pending
        ? (AppIcons.pending, const Color(0xFFE0922B), _pendingLabel(now))
        : playable
            ? (AppIcons.unlocked, const Color(0xFF2BB3A3), '解禁済み')
            : (AppIcons.locked, const Color(0xFF6B72C9), '未解禁');

    return ListTile(
      leading: Icon(icon, color: color),
      title: Row(
        children: [
          Expanded(
            child: Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (provider.isSaved(pin))
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.bookmark, size: 16, color: AppColors.pink),
            ),
          const SizedBox(width: 6),
          _StatusChip(label: status, color: color),
        ],
      ),
      subtitle: Text(
        'by ${pin.authorName}\n'
        '${pin.totalTipAmount}円 / ${pin.giftCount}件の応援'
        '${pin.warpUnlockCount > 0 ? ' ・ ⚡${pin.warpUnlockCount}' : ''}',
      ),
      isThreeLine: true,
      trailing: isMine
          ? IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, provider),
            )
          // 他人の投稿には保存＋通報/ブロックメニュー。
          : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) => _onMenu(context, provider, v),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'save',
                    child: Text(provider.isSaved(pin) ? '保存を解除' : '保存する')),
                const PopupMenuItem(value: 'report', child: Text('このピンを通報')),
                const PopupMenuItem(value: 'block', child: Text('この投稿者をブロック')),
              ],
            ),
      onTap: playable ? () => _showPlayer(context) : null,
    );
  }

  Future<void> _onMenu(
      BuildContext context, PinProvider provider, String action) async {
    if (action == 'save') {
      await provider.toggleSaved(pin.id);
      if (context.mounted) {
        _snack(context, provider.isSaved(pin) ? '保存しました' : '保存を解除しました');
      }
    } else if (action == 'report') {
      final reason = await showReportReasonSheet(context);
      if (reason == null) return;
      await provider.reportPin(pin, reason);
      if (context.mounted) _snack(context, '通報しました。表示を停止します。');
    } else if (action == 'block') {
      await provider.blockAuthor(pin.ownerId);
      if (context.mounted) {
        _snack(context, '${pin.authorName}さんをブロックしました。');
      }
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _pendingLabel(DateTime now) {
    final d = pin.remainingUntilVisible(now);
    if (d.inHours >= 1) return '公開待ち（約${d.inHours}時間後）';
    if (d.inMinutes >= 1) return '公開待ち（約${d.inMinutes}分後）';
    return '公開待ち（まもなく）';
  }

  void _showPlayer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            MiniWaveform(seed: pin.id, data: pin.waveform, height: 40),
            const SizedBox(height: 8),
            AudioPlayerWidget.fromPin(pin, key: ValueKey(pin.id)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, PinProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ドロップを削除'),
        content: Text('「${pin.title.isEmpty ? '無題のドロップ' : pin.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deletePin(pin.id);
  }
}

/// 解禁状態などを表す小さなチップ（ドット付き）。
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
