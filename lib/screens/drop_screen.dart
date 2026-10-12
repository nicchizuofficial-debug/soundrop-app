import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../state/pin_provider.dart';
import '../theme/app_theme.dart';
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
  '1時間': Duration(hours: 1),
  '3時間': Duration(hours: 3),
  '6時間': Duration(hours: 6),
  '24時間': Duration(hours: 24),
};

/// 1回の録音の最大長。これを超えると自動停止する。
const _maxDuration = Duration(seconds: 60);

class _DropScreenState extends State<DropScreen>
    with SingleTickerProviderStateMixin {
  /// 録音中に録音ボタンの周りで脈動するリング。
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
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

  /// ドロップ（アップロード）中。二重投稿防止とローディング表示に使う。
  bool _dropping = false;

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _showSnack('マイクの権限がありません');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/drop_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);
    HapticFeedback.mediumImpact();
    _pulse.repeat();

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
    _pulse.stop();
    HapticFeedback.lightImpact();
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

  Future<void> _drop() async {
    final path = _recordedPath;
    if (path == null || _dropping) return;

    setState(() => _dropping = true);
    try {
      final pin = await context.read<PinProvider>().dropPin(
            audioPath: path,
            title: _titleController.text.trim().isEmpty
                ? '無題のドロップ'
                : _titleController.text.trim(),
            lockDuration: _selectedLock,
            waveform: _trimmedWaveform(),
            trimStartMs: _isTrimmed ? _clipStart.inMilliseconds : null,
            trimEndMs: _isTrimmed ? _clipEnd.inMilliseconds : null,
          );
      if (!mounted) return;
      if (pin == null) {
        _showSnack('現在地が取得できていません。マップで現在地を更新してください。');
        return;
      }
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
    } catch (_) {
      // 録音は残っているので、そのまま再試行できる。
      _showSnack('ドロップに失敗しました。通信環境を確認して、もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _dropping = false);
    }
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
    _pulse.dispose();
    _recorder.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _recordedPath != null;
    final progress = _elapsed.inMilliseconds / _maxDuration.inMilliseconds;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.textMuted, height: 1.5);

    return Scaffold(
      appBar: AppBar(title: const Text('音声をドロップ')),
      // 主役の「ドロップする」は常に画面下に固定（スクロールしないと押せない問題の解消）。
      bottomNavigationBar: hasRecording
          ? DecoratedBox(
              // 下に流れるカードとボタンが重ならないよう背景を敷く。
              decoration: const BoxDecoration(
                color: AppColors.navy,
                border: Border(top: BorderSide(color: AppColors.outline)),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: GradientButton(
                  icon: const Icon(Icons.place_rounded),
                  label: _dropping ? 'アップロード中…' : 'この場所にドロップする',
                  loading: _dropping,
                  onPressed: _drop,
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- STEP 1: 録音 ----
            _StepCard(
              step: 1,
              title: '録音する',
              child: Column(
                children: [
                  Waveform(
                    amplitudes: _amplitudes,
                    active: _isRecording,
                    color: _isRecording ? AppColors.pink : AppColors.blue,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: progress.clamp(0.0, 1.0),
                      color: _isRecording ? AppColors.pink : AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_format(_elapsed)} / ${_format(_maxDuration)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RecordButton(
                    recording: _isRecording,
                    // 録音後は次の手順が主役なので、ボタンを小さくして詰める。
                    size: hasRecording && !_isRecording ? 60 : 84,
                    pulse: _pulse,
                    onPressed: _dropping
                        ? null
                        : (_isRecording ? _stopRecording : _startRecording),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? '録音中… タップで停止（最大60秒）'
                        : (hasRecording ? 'タップで録音し直す' : 'タップして録音を開始'),
                    style: muted,
                  ),
                ],
              ),
            ),

            // ---- STEP 2: 試聴・トリミング（録音後のみ） ----
            if (hasRecording) ...[
              const SizedBox(height: 14),
              _StepCard(
                step: 2,
                title: '試聴・トリミング',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 波形上のハンドルでトリミング範囲を選択。
                    TrimmableWaveform(
                      data: _recordedWaveform.isEmpty
                          ? List.filled(40, 0.4)
                          : _recordedWaveform,
                      values: _trim,
                      onChanged: (v) {
                        if ((v.end - v.start) *
                                _recordedDuration.inMilliseconds <
                            500) {
                          return; // 最小0.5秒は残す
                        }
                        setState(() => _trim = v);
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_format(_clipStart)} 〜 ${_format(_clipEnd)}',
                            style: muted,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.play_circle_outline, size: 20),
                          label: const Text('範囲をプレビュー'),
                          onPressed: () =>
                              setState(() => _previewNonce++), // 自動再生で頭出しプレビュー
                        ),
                      ],
                    ),
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
                  ],
                ),
              ),

              // ---- STEP 3: 公開設定 ----
              const SizedBox(height: 14),
              _StepCard(
                step: 3,
                title: '公開の設定',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      textInputAction: TextInputAction.done,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'タイトル（任意）',
                        prefixIcon: Icon(Icons.edit_outlined),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.pink),
                        const SizedBox(width: 6),
                        Text('地図に公開するまでの時間',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('待ち伏せ防止のため、ドロップ直後は地図に表示されません。', style: muted),
                    const SizedBox(height: 10),
                    SegmentedButton<Duration>(
                      showSelectedIcon: false,
                      segments: [
                        for (final e in _lockOptions.entries)
                          ButtonSegment(value: e.value, label: Text(e.key)),
                      ],
                      selected: {_selectedLock},
                      onSelectionChanged: (s) =>
                          setState(() => _selectedLock = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_lockOptions.entries.firstWhere((e) => e.value == _selectedLock).key}後に公開されます',
                      style: muted,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 番号付きの手順カード（録音 → 試聴 → 公開設定 の流れを見せる）。
class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final Widget child;

  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$step',
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// 録音ボタン。待機中はブランドグラデーション、録音中は脈動するリングで状態を示す。
class _RecordButton extends StatelessWidget {
  final bool recording;
  final Animation<double> pulse;
  final VoidCallback? onPressed;

  final double size;

  const _RecordButton({
    required this.recording,
    required this.pulse,
    required this.onPressed,
    this.size = 84,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? '録音を停止' : '録音を開始',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size + 36,
        height: size + 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (recording)
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  width: size + 36 * pulse.value,
                  height: size + 36 * pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pink
                        .withValues(alpha: 0.35 * (1 - pulse.value)),
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: recording ? null : AppColors.brand,
                  color: recording ? const Color(0xFFFF5C7A) : null,
                ),
                child: InkWell(
                  onTap: onPressed,
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: size * 0.48,
                    color: recording ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
