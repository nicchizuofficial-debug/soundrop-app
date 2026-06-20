import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/pin_model.dart';

/// インラインの音声プレイヤー。再生/一時停止と進捗バーを備える。
///
/// アセット音声（ダミーピン）と録音ファイル（ユーザー投稿）の両方に対応。
/// ボトムシート等に埋め込んで使う前提で、自身でプレイヤーを生成・破棄する。
class AudioPlayerWidget extends StatefulWidget {
  /// 再生する音声ソース。アセット or ローカルファイルかは [PinModel.isAssetAudio] で判定。
  final String audioUrl;
  final bool isAsset;

  /// トリミング再生範囲（任意）。指定時は ClippingAudioSource で切り出す。
  final Duration? clipStart;
  final Duration? clipEnd;

  /// ロード完了後に自動再生する（プレビュー用）。
  final bool autoPlay;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isAsset,
    this.clipStart,
    this.clipEnd,
    this.autoPlay = false,
  });

  /// PinModel から直接生成するためのファクトリ。
  factory AudioPlayerWidget.fromPin(PinModel pin, {Key? key}) {
    return AudioPlayerWidget(
      key: key,
      audioUrl: pin.audioUrl,
      isAsset: pin.isAssetAudio,
      clipStart:
          pin.trimStartMs == null ? null : Duration(milliseconds: pin.trimStartMs!),
      clipEnd:
          pin.trimEndMs == null ? null : Duration(milliseconds: pin.trimEndMs!),
    );
  }

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  Future<void> _loadSource() async {
    try {
      final hasClip = widget.clipStart != null || widget.clipEnd != null;
      if (hasClip) {
        // トリミング範囲を再生時に切り出す（元ファイルは無加工）。
        final child = widget.isAsset
            ? AudioSource.asset(widget.audioUrl)
            : AudioSource.uri(Uri.file(widget.audioUrl));
        await _player.setAudioSource(ClippingAudioSource(
          child: child,
          start: widget.clipStart,
          end: widget.clipEnd,
        ));
      } else if (widget.isAsset) {
        await _player.setAsset(widget.audioUrl);
      } else {
        await _player.setFilePath(widget.audioUrl);
      }
      if (widget.autoPlay && mounted) await _player.play();
    } catch (e) {
      // ダミーピンの音声アセットが未配置でもUI確認できるようエラーを握って表示。
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      // 末尾まで再生済みなら頭出ししてから再生。
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Text(
        '音声を読み込めませんでした（${widget.audioUrl}）',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 再生/一時停止ボタン。
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final processing = state?.processingState;
            final playing = state?.playing ?? false;

            if (processing == ProcessingState.loading ||
                processing == ProcessingState.buffering) {
              return const SizedBox(
                height: 48,
                width: 48,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final completed = processing == ProcessingState.completed;
            return IconButton.filled(
              iconSize: 32,
              icon: Icon(
                completed
                    ? Icons.replay
                    : (playing ? Icons.pause : Icons.play_arrow),
              ),
              onPressed: _togglePlay,
            );
          },
        ),

        // 進捗バー＋経過/総時間。
        StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final total = _player.duration ?? Duration.zero;
            final maxMs = total.inMilliseconds.toDouble();
            final value =
                maxMs == 0 ? 0.0 : position.inMilliseconds.clamp(0, maxMs).toDouble();

            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxMs == 0 ? 1 : maxMs,
                  value: maxMs == 0 ? 0 : value,
                  onChanged: maxMs == 0
                      ? null
                      : (v) => _player.seek(Duration(milliseconds: v.round())),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(position)),
                      Text(_format(total)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }
}
