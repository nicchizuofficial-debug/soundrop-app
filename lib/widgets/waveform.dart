import 'package:flutter/material.dart';

/// 録音中の振幅を縦バーの列として描画する簡易波形ウィジェット。
///
/// [amplitudes] は 0..1 に正規化された値のリスト（末尾が最新）。
/// 幅に収まる本数だけ末尾から表示する。
class Waveform extends StatelessWidget {
  final List<double> amplitudes;
  final bool active;
  final Color color;
  final double height;

  const Waveform({
    super.key,
    required this.amplitudes,
    required this.color,
    this.active = false,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: amplitudes.isEmpty
          ? Center(
              child: Text(
                active ? '…' : '録音すると波形が表示されます',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : CustomPaint(
              painter: _WaveformPainter(amplitudes, color),
              size: Size.infinite,
            ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _WaveformPainter(this.amplitudes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 3.0;
    const gap = 2.0;
    final step = barWidth + gap;
    final maxBars = (size.width / step).floor();
    if (maxBars <= 0) return;

    // 表示できる本数だけ末尾（最新）から取り出す。
    final start =
        amplitudes.length > maxBars ? amplitudes.length - maxBars : 0;
    final visible = amplitudes.sublist(start);

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final centerY = size.height / 2;
    // 最新が右端に来るよう右詰めで描画。
    var x = size.width - visible.length * step + barWidth / 2;
    for (final amp in visible) {
      final h = (amp.clamp(0.0, 1.0)) * (size.height * 0.9);
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
      x += step;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.amplitudes.length != amplitudes.length || old.color != color;
}
