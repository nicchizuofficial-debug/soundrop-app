import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../models/pin_model.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/mini_waveform.dart';
import '../widgets/report_sheet.dart';
import '../widgets/ui_kit.dart';
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
          title: const Text('ドロップ一覧'),
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
            dividerColor: AppColors.outline,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                  empty: const EmptyState(
                    icon: AppIcons.drop,
                    title: 'まだドロップがありません',
                    message: '地図の「ドロップ」から、\nその場所に音を残してみましょう。',
                  ),
                  isMine: true,
                ),
                _PinList(
                  pins: published,
                  empty: const EmptyState(
                    icon: Icons.map_outlined,
                    title: '聴けるドロップはまだありません',
                    message: 'フォロー中の人のドロップが\n公開されると、ここに並びます。',
                  ),
                  isMine: false,
                ),
                _PinList(
                  pins: saved,
                  empty: const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: '保存したドロップはありません',
                    message: '解禁したドロップは「保存」すると、\nいつでもここから聴き直せます。',
                  ),
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
  final Widget empty;
  final bool isMine;

  const _PinList({
    required this.pins,
    required this.empty,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return empty;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: pins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
        ? (AppIcons.pending, AppColors.pending, _pendingLabel(now))
        : playable
            ? (AppIcons.unlocked, AppColors.unlocked, '解禁済み')
            : (AppIcons.locked, AppColors.locked, '未解禁');

    final meta = <String>[
      if (!isMine) pin.authorName,
      relativeTime(pin.createdAt, now: now),
    ].join(' ・ ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: playable ? () => _showPlayer(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        if (provider.isSaved(pin))
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.bookmark_rounded,
                                size: 16, color: AppColors.pink),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    MiniWaveform(seed: pin.id, data: pin.waveform, height: 20),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppTag(label: status, color: color, dot: true),
                        if (AppConfig.enableTipping && pin.giftCount > 0)
                          AppTag(
                              label: '応援 ${pin.totalTipAmount}円',
                              color: AppColors.pink,
                              icon: AppIcons.support),
                        if (pin.warpUnlockCount > 0)
                          AppTag(
                              label: 'ワープ ${pin.warpUnlockCount}',
                              color: AppColors.blue,
                              icon: AppIcons.warpTicket),
                      ],
                    ),
                  ],
                ),
              ),
              isMine
                  ? IconButton(
                      tooltip: '削除',
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textMuted),
                      onPressed: () => _confirmDelete(context, provider),
                    )
                  // 他人の投稿には保存＋通報/ブロックメニュー。
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.textMuted),
                      onSelected: (v) => _onMenu(context, provider, v),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'save',
                            child: _MenuRow(
                                icon: provider.isSaved(pin)
                                    ? Icons.bookmark_remove_outlined
                                    : Icons.bookmark_add_outlined,
                                label:
                                    provider.isSaved(pin) ? '保存を解除' : '保存する')),
                        const PopupMenuItem(
                            value: 'report',
                            child: _MenuRow(
                                icon: Icons.flag_outlined, label: 'このピンを通報')),
                        const PopupMenuItem(
                            value: 'block',
                            child: _MenuRow(
                                icon: Icons.block, label: 'この投稿者をブロック')),
                      ],
                    ),
            ],
          ),
        ),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('by ${pin.authorName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              MiniWaveform(seed: pin.id, data: pin.waveform, height: 44),
              const SizedBox(height: 12),
              AudioPlayerWidget.fromPin(pin, key: ValueKey(pin.id)),
            ],
          ),
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
        content: Text(
            '「${pin.title.isEmpty ? '無題のドロップ' : pin.title}」を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.navy,
              minimumSize: const Size(88, 44),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deletePin(pin.id);
  }
}

/// ポップアップメニューの1行（アイコン＋ラベル）。
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
