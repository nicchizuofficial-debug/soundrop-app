import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../state/pin_provider.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/trimmable_waveform.dart';
import '../widgets/waveform.dart';

/// 音声を録音して現在地にドロップ（投稿）する画面。
///
/// 流れ: 録音（波形＋残り時間表示・最大60秒で自動停止）→ 試聴 →
/// タイトル＆タイムロック時間を設定 → ドロップ。
class DropScreen extends StatefulWidget {
  const DropScreen({super.key});

  @override
  State<DropScreen> createState() => _DropScreenState();
}

/// タイムロック（公開までの遅延）の選択肢。
const _lockOptions = <String, Duration>{
  '1時間後': Duration(hours: 1),
  '3時間後': Duration(hours: 3),
  '6時間後': Duration(hours: 6),
  '24時間後': Duration(hours: 24),
};

/// 1回の録音の最大長。これを超えると自動停止する。
const _maxDuration = Duration(seconds: 60);

class _DropScreenState extends State<DropScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _titleController = TextEditingController();

  StreamSubscription<Amplitude>? _ampSub;
  Timer? _ticker;

  bool _isRecording = false;
  String? _recordedPath;
  Duration _elapsed = Duration.zero;
  Duration _selectedLock = const Duration(hours: 3);

  /// 直近の正規化済み振幅（0..1）。ライブ波形描画用（末尾のみ保持）。
  final List<double> _amplitudes = [];

  /// 録音全体の振幅（ダウンサンプル前）。保存用ミニ波形の素材。
  final List<double> _fullAmps = [];

  /// 保存するダウンサンプル済み波形（録音停止時に確定）。
  List<double> _recordedWaveform = const [];

  /// 録音長（停止時に確定）とトリミング範囲（0..1の割合）。
  Duration _recordedDuration = Duration.zero;
  RangeValues _trim = const RangeValues(0, 1);

  /// プレビュー（自動再生）トリガ。増やすとプレイヤーを作り直して頭出し再生。
  int _previewNonce = 0;

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _showSnack('マイクの権限がありません');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/drop_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);

    setState(() {
      _isRecording = true;
      _recordedPath = null;
      _elapsed = Duration.zero;
      _amplitudes.clear();
      _fullAmps.clear();
      _recordedWaveform = const [];
      _previewNonce = 0;
    });

    // 振幅ストリームを購読して波形を更新。
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
      final v = _normalize(amp.current);
      _fullAmps.add(v); // 録音全体を保持（保存用）
      setState(() {
        _amplitudes.add(v);
        // 描画はバッファ末尾だけ見るので無制限に増やさない。
        if (_amplitudes.length > 200) _amplitudes.removeAt(0);
      });
    });

    // 経過時間の更新と最大長での自動停止。
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() => _elapsed += const Duration(milliseconds: 100));
      if (_elapsed >= _maxDuration) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    await _ampSub?.cancel();
    _ticker = null;
    _ampSub = null;

    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedPath = path;
      _recordedWaveform = _downsample(_fullAmps, 40);
      _recordedDuration = _elapsed;
      _trim = const RangeValues(0, 1);
    });
  }

  /// 振幅列を [buckets] 個に平均ダウンサンプルする（保存用ミニ波形）。
  List<double> _downsample(List<double> src, int buckets) {
    if (src.isEmpty) return const [];
    if (src.length <= buckets) return List.of(src);
    final out = <double>[];
    final size = src.length / buckets;
    for (var i = 0; i < buckets; i++) {
      final start = (i * size).floor();
      final end = ((i + 1) * size).floor().clamp(start + 1, src.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += src[j];
      }
      out.add(sum / (end - start));
    }
    return out;
  }

  /// dBFS（おおむね -60..0）を 0..1 に正規化。
  double _normalize(double dbfs) {
    const floor = -60.0;
    final clamped = dbfs.clamp(floor, 0.0);
    return (clamped - floor) / -floor;
  }

  void _drop() {
    final path = _recordedPath;
    if (path == null) return;

    final pin = context.read<PinProvider>().dropPin(
          audioPath: path,
          title: _titleController.text.trim().isEmpty
              ? '無題のドロップ'
              : _titleController.text.trim(),
          lockDuration: _selectedLock,
          waveform: _trimmedWaveform(),
          trimStartMs: _isTrimmed ? _clipStart.inMilliseconds : null,
          trimEndMs: _isTrimmed ? _clipEnd.inMilliseconds : null,
        );

    if (pin == null) {
      _showSnack('現在地が取得できていません。マップで現在地を更新してください。');
      return;
    }
    Navigator.pop(context, true);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  // ---- トリミング補助 ----
  Duration get _clipStart => Duration(
      milliseconds: (_recordedDuration.inMilliseconds * _trim.start).round());
  Duration get _clipEnd => Duration(
      milliseconds: (_recordedDuration.inMilliseconds * _trim.end).round());
  bool get _isTrimmed => _trim.start > 0.001 || _trim.end < 0.999;

  /// トリミング範囲に対応する波形サブリストを返す。
  List<double> _trimmedWaveform() {
    if (_recordedWaveform.isEmpty || !_isTrimmed) return _recordedWaveform;
    final n = _recordedWaveform.length;
    final s = (n * _trim.start).floor().clamp(0, n - 1);
    final e = (n * _trim.end).ceil().clamp(s + 1, n);
    return _recordedWaveform.sublist(s, e);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _recordedPath != null;
    final progress =
        _elapsed.inMilliseconds / _maxDuration.inMilliseconds;

    return Scaffold(
      appBar: AppBar(title: const Text('音声をドロップ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- 波形 ----
            Waveform(
              amplitudes: _amplitudes,
              active: _isRecording,
              color: _isRecording
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),

            // ---- 残り時間 ----
            if (_isRecording || _elapsed > Duration.zero) ...[
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text(
                '${_format(_elapsed)} / ${_format(_maxDuration)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),

            // ---- 録音コントロール ----
            Center(
              child: Column(
                children: [
                  IconButton.filled(
                    iconSize: 56,
                    style: IconButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : null,
                    ),
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    onPressed:
                        _isRecording ? _stopRecording : _startRecording,
                  ),
                  const SizedBox(height: 8),
                  Text(_isRecording
                      ? '録音中… タップで停止（最大60秒）'
                      : (hasRecording ? '録音し直すにはタップ' : 'タップして録音')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 試聴プレイヤー＆トリミング（録音後のみ） ----
            if (hasRecording) ...[
              Text('試聴・トリミング',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // 波形上のハンドルでトリミング範囲を選択。
              TrimmableWaveform(
                data: _recordedWaveform.isEmpty
                    ? List.filled(40, 0.4)
                    : _recordedWaveform,
                values: _trim,
                onChanged: (v) {
                  if ((v.end - v.start) * _recordedDuration.inMilliseconds <
                      500) {
                    return; // 最小0.5秒は残す
                  }
                  setState(() => _trim = v);
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_format(_clipStart)} 〜 ${_format(_clipEnd)}'
                    '（${((_trim.end - _trim.start) * 100).round()}%）',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('選択範囲をプレビュー'),
                    onPressed: () =>
                        setState(() => _previewNonce++), // 自動再生で頭出しプレビュー
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AudioPlayerWidget(
                // trim/プレビュー操作で作り直してクリップ＆自動再生を反映。
                key: ValueKey(
                    '$_recordedPath-${_trim.start}-${_trim.end}-$_previewNonce'),
                audioUrl: _recordedPath!,
                isAsset: false,
                clipStart: _isTrimmed ? _clipStart : null,
                clipEnd: _isTrimmed ? _clipEnd : null,
                autoPlay: _previewNonce > 0,
              ),
              const Divider(height: 32),

              // ---- タイトル ----
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // ---- タイムロック設定 ----
              Text('公開タイミング（タイムロック）',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('待ち伏せ防止のため、ドロップ直後は地図に表示されません。',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _lockOptions.entries.map((e) {
                  return ChoiceChip(
                    label: Text(e.key),
                    selected: _selectedLock == e.value,
                    onSelected: (_) =>
                        setState(() => _selectedLock = e.value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // ---- ドロップ実行 ----
              FilledButton.icon(
                icon: const Icon(Icons.place),
                label: const Text('この場所にドロップする'),
                onPressed: _drop,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
