import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 波形上で開始/終了ハンドルをドラッグしてトリミング範囲を選ぶウィジェット。
///
/// [values] は 0..1 の割合（start/end）。範囲外のバーは暗く表示し、
/// 両端のハンドルをドラッグして範囲を変更する。
class TrimmableWaveform extends StatelessWidget {
  final List<double> data;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final double height;
  final double minGap;

  const TrimmableWaveform({
    super.key,
    required this.data,
    required this.values,
    required this.onChanged,
    this.height = 64,
    this.minGap = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const handleW = 16.0;
        final startX = values.start * w;
        final endX = values.end * w;

        void dragStart(double dx) {
          final v =
              (values.start + dx / w).clamp(0.0, values.end - minGap);
          onChanged(RangeValues(v, values.end));
        }

        void dragEnd(double dx) {
          final v = (values.end + dx / w).clamp(values.start + minGap, 1.0);
          onChanged(RangeValues(values.start, v));
        }

        return SizedBox(
          height: height,
          width: w,
          child: Stack(
            children: [
              // 波形（選択外は暗く）。
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrimWavePainter(data, values.start, values.end),
                ),
              ),
              // 選択範囲の枠。
              Positioned(
                left: startX,
                top: 0,
                bottom: 0,
                width: (endX - startX).clamp(0, w),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                          color: AppColors.blue.withOpacity(0.6), width: 1),
                    ),
                  ),
                ),
              ),
              // 開始ハンドル。
              Positioned(
                left: (startX - handleW / 2).clamp(0, w - handleW),
                top: 0,
                bottom: 0,
                width: handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => dragStart(d.delta.dx),
                  child: const _Handle(),
                ),
              ),
              // 終了ハンドル。
              Positioned(
                left: (endX - handleW / 2).clamp(0, w - handleW),
                top: 0,
                bottom: 0,
                width: handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => dragEnd(d.delta.dx),
                  child: const _Handle(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 6,
        decoration: BoxDecoration(
          gradient: AppColors.brand,
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _TrimWavePainter extends CustomPainter {
  final List<double> bars;
  final double start;
  final double end;

  _TrimWavePainter(this.bars, this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final sel = Paint()
      ..shader = AppColors.brand.createShader(Offset.zero & size)
      ..strokeCap = StrokeCap.round;
    final dim = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeCap = StrokeCap.round;

    const gap = 2.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;
    sel.strokeWidth = barW;
    dim.strokeWidth = barW;
    final cy = size.height / 2;
    var x = barW / 2;
    for (var i = 0; i < bars.length; i++) {
      final f = i / (bars.length - 1);
      final h = bars[i] * size.height * 0.9;
      final paint = (f >= start && f <= end) ? sel : dim;
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
      x += barW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrimWavePainter old) =>
      old.start != start || old.end != end || old.bars != bars;
}
