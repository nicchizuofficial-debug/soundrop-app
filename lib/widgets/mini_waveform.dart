import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ミニ波形プレビュー。
///
/// [data]（録音時の実振幅）があればそれを描画。空なら [seed]（通常はピンID）から
/// 決定的に装飾波形を生成する（同じピンは常に同じ見た目）。
class MiniWaveform extends StatelessWidget {
  final String seed;
  final List<double> data;
  final double height;
  final int barCount;
  final Gradient gradient;

  const MiniWaveform({
    super.key,
    required this.seed,
    this.data = const [],
    this.height = 40,
    this.barCount = 36,
    this.gradient = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    final bars = data.isNotEmpty ? data : _bars();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MiniWavePainter(bars, gradient),
      ),
    );
  }

  /// seed から 0.15〜1.0 のバー高さ列を決定的に生成（実データが無いとき）。
  List<double> _bars() {
    var h = seed.hashCode & 0x7fffffff;
    final bars = <double>[];
    for (var i = 0; i < barCount; i++) {
      // 線形合同法で擬似乱数を進める。
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final r = (h % 1000) / 1000.0; // 0..1
      // 中央を少し高くする包絡で「声紋」らしく。
      final t = i / (barCount - 1);
      final env = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
      bars.add(0.15 + r * 0.85 * env);
    }
    return bars;
  }
}

class _MiniWavePainter extends CustomPainter {
  final List<double> bars;
  final Gradient gradient;

  _MiniWavePainter(this.bars, this.gradient);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round;

    final gap = 2.0;
    final barWidth = (size.width - gap * (bars.length - 1)) / bars.length;
    paint.strokeWidth = barWidth;
    final cy = size.height / 2;
    var x = barWidth / 2;
    for (final b in bars) {
      final h = b * size.height * 0.9;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWavePainter old) =>
      old.bars != bars || old.gradient != gradient;
}
