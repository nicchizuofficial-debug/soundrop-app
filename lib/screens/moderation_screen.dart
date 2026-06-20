import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/map_tiles.dart';
import '../models/pin_model.dart';
import '../models/report_model.dart';
import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/mini_waveform.dart';

/// 運営用モデレーション画面。通報（`ReportSink.all()`）を一覧し、
/// フィルタ（未対応のみ・理由別）・並び替え・件数バッジ付きで審査する。
///
/// MVPでは端末ローカルの通報を表示。本番はバックエンドの運営ツールに置き換える
/// （データ設計は docs/moderation.md）。
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  late Future<List<ReportModel>> _future;

  ReportStatus? _statusFilter; // null = すべて
  ReportReason? _reasonFilter; // null = すべて
  bool _newestFirst = true;

  bool _selectionMode = false;
  bool _showSelectedOnly = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<PinProvider>().loadReports();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  void _toggleSelect(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _showSelectedOnly = false;
      _selected.clear();
    });
  }

  /// 選択中の通報に一括でステータスを適用（必要なら投稿削除）。
  Future<void> _bulkApply(ReportStatus status, {bool delete = false}) async {
    final provider = context.read<PinProvider>();
    final reports = await provider.loadReports();
    for (final id in _selected) {
      if (delete) {
        final matches = reports.where((r) => r.id == id);
        if (matches.isNotEmpty) await provider.deletePin(matches.first.pinId);
      }
      await provider.updateReportStatus(id, status);
    }
    _exitSelection();
    await _refresh();
  }

  List<ReportModel> _apply(List<ReportModel> all) {
    var list = all.where((r) {
      if (_selectionMode && _showSelectedOnly && !_selected.contains(r.id)) {
        return false;
      }
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_reasonFilter != null && r.reason != _reasonFilter) return false;
      return true;
    }).toList();
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('${_selected.length}件 選択'),
              actions: [
                IconButton(
                  tooltip: _showSelectedOnly ? '全件表示' : '選択中のみ表示',
                  icon: Icon(_showSelectedOnly
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(
                          () => _showSelectedOnly = !_showSelectedOnly),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _bulkApply(ReportStatus.dismissed),
                  child: const Text('却下'),
                ),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _bulkApply(ReportStatus.actioned),
                  child: const Text('対応済'),
                ),
                PopupMenuButton<String>(
                  onSelected: (_) =>
                      _bulkApply(ReportStatus.actioned, delete: true),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'delete', child: Text('投稿を削除（対応済）')),
                  ],
                ),
              ],
            )
          : AppBar(
              title: const Text('モデレーション（運営）'),
              actions: [
                IconButton(
                  tooltip: '複数選択',
                  icon: const Icon(Icons.checklist_rounded),
                  onPressed: () => setState(() => _selectionMode = true),
                ),
                IconButton(
                  tooltip: _newestFirst ? '古い順にする' : '新しい順にする',
                  icon: Icon(_newestFirst
                      ? Icons.south_rounded
                      : Icons.north_rounded),
                  onPressed: () =>
                      setState(() => _newestFirst = !_newestFirst),
                ),
                IconButton(
                  tooltip: '再読込',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
      body: FutureBuilder<List<ReportModel>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final filtered = _apply(all);

          return Column(
            children: [
              _FilterBar(
                all: all,
                statusFilter: _statusFilter,
                reasonFilter: _reasonFilter,
                onStatus: (s) => setState(() => _statusFilter = s),
                onReason: (r) => setState(() => _reasonFilter = r),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('該当する通報はありません。'))
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) => _ReportTile(
                            report: filtered[i],
                            onChanged: _refresh,
                            selectionMode: _selectionMode,
                            selected: _selected.contains(filtered[i].id),
                            onToggleSelect: () => _toggleSelect(filtered[i].id),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ステータス/理由フィルタ＋件数バッジ。
class _FilterBar extends StatelessWidget {
  final List<ReportModel> all;
  final ReportStatus? statusFilter;
  final ReportReason? reasonFilter;
  final ValueChanged<ReportStatus?> onStatus;
  final ValueChanged<ReportReason?> onReason;

  const _FilterBar({
    required this.all,
    required this.statusFilter,
    required this.reasonFilter,
    required this.onStatus,
    required this.onReason,
  });

  int _countStatus(ReportStatus? s) =>
      s == null ? all.length : all.where((r) => r.status == s).length;
  int _countReason(ReportReason r) =>
      all.where((x) => x.reason == r).length;

  @override
  Widget build(BuildContext context) {
    final pending = _countStatus(ReportStatus.pending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 未対応の強調バッジ。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('未対応', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 8),
              _Badge(count: pending, highlight: pending > 0),
              const Spacer(),
              Text('全 ${all.length} 件',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        // ステータスフィルタ
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('すべて', statusFilter == null, _countStatus(null),
                  () => onStatus(null)),
              for (final s in ReportStatus.values)
                _chip(_statusLabel(s), statusFilter == s, _countStatus(s),
                    () => onStatus(s)),
            ],
          ),
        ),
        // 理由フィルタ（折りたたみメニュー）
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<ReportReason?>(
              onSelected: onReason,
              itemBuilder: (_) => [
                CheckedPopupMenuItem<ReportReason?>(
                  value: null,
                  checked: reasonFilter == null,
                  child: Text('すべての理由 (${all.length})'),
                ),
                for (final r in ReportReason.values)
                  CheckedPopupMenuItem<ReportReason?>(
                    value: r,
                    checked: reasonFilter == r,
                    child: Text('${r.label} (${_countReason(r)})'),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.filter_list, size: 18),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(reasonFilter == null
                        ? '理由：すべて (${all.length})'
                        : '理由：${reasonFilter!.label} (${_countReason(reasonFilter!)})'),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, int count, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text('$label ($count)'),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final bool highlight;
  const _Badge({required this.count, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? Colors.redAccent : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

String _statusLabel(ReportStatus s) => switch (s) {
      ReportStatus.pending => '未対応',
      ReportStatus.reviewing => '審査中',
      ReportStatus.actioned => '対応済',
      ReportStatus.dismissed => '却下',
    };

class _ReportTile extends StatelessWidget {
  final ReportModel report;
  final Future<void> Function() onChanged;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelect;

  const _ReportTile({
    required this.report,
    required this.onChanged,
    this.selectionMode = false,
    this.selected = false,
    required this.onToggleSelect,
  });

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.pending => Colors.orange,
        ReportStatus.reviewing => AppColors.blue,
        ReportStatus.actioned => Colors.redAccent,
        ReportStatus.dismissed => Colors.grey,
      };

  bool get _isUrgent => report.reason == ReportReason.stalking;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PinProvider>();
    final d = report.createdAt;
    final date =
        '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return ListTile(
      onTap: selectionMode
          ? onToggleSelect
          : () => _showDetail(context, provider),
      onLongPress: selectionMode ? null : onToggleSelect,
      selected: selected,
      leading: selectionMode
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelect())
          : Icon(
              _isUrgent ? Icons.priority_high : Icons.flag_outlined,
              color: _isUrgent ? Colors.redAccent : null,
            ),
      title: Row(
        children: [
          Expanded(child: Text(report.reason.label)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(report.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_statusLabel(report.status),
                style: TextStyle(
                    fontSize: 11, color: _statusColor(report.status))),
          ),
        ],
      ),
      subtitle: Text(
        'pin: ${report.pinId}\n'
        '作者: ${report.reportedOwnerId.isEmpty ? '不明' : report.reportedOwnerId}'
        ' ・ 通報者: ${report.reporterId.isEmpty ? '匿名' : report.reporterId}\n'
        '$date${report.note.isEmpty ? '' : ' ・ ${report.note}'}',
      ),
      isThreeLine: true,
      trailing: selectionMode
          ? null
          : PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'delete') {
            await provider.deletePin(report.pinId);
            await provider.updateReportStatus(
                report.id, ReportStatus.actioned);
          } else {
            await provider.updateReportStatus(
                report.id, ReportStatus.values.byName(v));
          }
          await onChanged();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'reviewing', child: Text('審査中にする')),
          PopupMenuItem(value: 'dismissed', child: Text('却下する')),
          PopupMenuItem(value: 'actioned', child: Text('対応済にする')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('対象投稿を削除（対応済）')),
        ],
      ),
    );
  }

  /// 通報詳細ダイアログ（音声再生・位置プレビュー・対応アクション）。
  void _showDetail(BuildContext context, PinProvider provider) {
    final matches = provider.allPins.where((p) => p.id == report.pinId);
    final PinModel? pin = matches.isEmpty ? null : matches.first;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(_isUrgent ? Icons.priority_high : Icons.flag,
                color: _isUrgent ? Colors.redAccent : null),
            const SizedBox(width: 8),
            Expanded(child: Text(report.reason.label)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('状態: ${_statusLabel(report.status)}',
                    style: TextStyle(color: _statusColor(report.status))),
                const SizedBox(height: 4),
                Text('通報者: ${report.reporterId.isEmpty ? '匿名' : report.reporterId}'),
                Text('作者: ${report.reportedOwnerId.isEmpty ? '不明' : report.reportedOwnerId}'),
                if (report.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('メモ: ${report.note}'),
                ],
                const Divider(height: 24),

                if (pin == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('対象の投稿は削除済みです。'),
                  )
                else ...[
                  Text(pin.title.isEmpty ? '無題のドロップ' : pin.title,
                      style:
                          Theme.of(dialogContext).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // 音声波形＋再生（運営が内容を確認）。
                  MiniWaveform(
                      seed: pin.id, data: pin.waveform, height: 40),
                  AudioPlayerWidget.fromPin(pin, key: ValueKey(pin.id)),
                  const SizedBox(height: 12),
                  // 位置プレビュー。
                  _LocationPreview(lat: pin.latitude, lng: pin.longitude),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () async {
              await provider.updateReportStatus(
                  report.id, ReportStatus.dismissed);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await onChanged();
            },
            child: const Text('却下'),
          ),
          FilledButton(
            onPressed: () async {
              await provider.deletePin(report.pinId);
              await provider.updateReportStatus(
                  report.id, ReportStatus.actioned);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await onChanged();
            },
            child: const Text('投稿を削除'),
          ),
        ],
      ),
    );
  }
}

/// 位置プレビュー（flutter_map + OpenStreetMap、非操作の小さな地図）。
class _LocationPreview extends StatelessWidget {
  final double lat;
  final double lng;
  const _LocationPreview({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: pos,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // 一覧では操作不可
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapTiles.urlTemplate,
                  subdomains: MapTiles.subdomains,
                  userAgentPackageName: 'com.example.sound_drop',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: pos,
                    width: 30,
                    height: 30,
                    child: const GradientIcon(AppIcons.myLocation, size: 28),
                  ),
                ]),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.black54,
                child: Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
