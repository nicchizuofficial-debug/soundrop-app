import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// アイコンを模したブランドロゴ（地図ピン＋内部の波形）。
///
/// アプリ内のスプラッシュ／空状態／ヘッダーで使う。画像アセット無しでも
/// グラデーションで描画できるよう CustomPaint で実装している。
class SoundDropLogo extends StatelessWidget {
  final double size;

  /// 角丸の枠線を描くか（アプリアイコン風にしたいとき true）。
  final bool withFrame;

  const SoundDropLogo({super.key, this.size = 96, this.withFrame = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(withFrame: withFrame),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool withFrame;
  _LogoPainter({required this.withFrame});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final shader = AppColors.brand.createShader(rect);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..strokeWidth = w * 0.045;

    if (withFrame) {
      final framePaint = Paint()
        ..style = PaintingStyle.stroke
        ..shader = shader
        ..strokeWidth = w * 0.04;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(w * 0.06),
          Radius.circular(w * 0.22),
        ),
        framePaint,
      );
    }

    // ---- 地図ピン（ティアドロップ）の輪郭 ----
    // フレーム付きのときは枠内に収まるよう中央基準で縮小。
    if (withFrame) {
      final c = Offset(w / 2, h / 2);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(0.76)
        ..translate(-c.dx, -c.dy);
    }

    final cx = w / 2;
    final circleCenter = Offset(cx, h * 0.40);
    final r = w * 0.24;
    final tip = Offset(cx, h * 0.86);

    final pin = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        circleCenter.dx - r * 1.7, circleCenter.dy + r * 0.9,
        circleCenter.dx - r, circleCenter.dy,
      )
      ..arcToPoint(
        Offset(circleCenter.dx + r, circleCenter.dy),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..quadraticBezierTo(
        circleCenter.dx + r * 1.7, circleCenter.dy + r * 0.9,
        tip.dx, tip.dy,
      );
    canvas.drawPath(pin, stroke);

    // ---- 内部の丸い枠（リング） ----
    final rr = r * 0.72;
    canvas.drawCircle(
      circleCenter,
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..strokeWidth = w * 0.04,
    );

    // ---- 内部の波形（リング中央を横切る声紋） ----
    final waveTop = circleCenter.dy;
    final left = circleCenter.dx - rr;
    final right = circleCenter.dx + rr;
    final span = right - left;
    final lead = rr * 0.22;
    final amps = [0.28, 0.55, 0.82, 1.0, 0.86, 0.66, 0.44, 0.24];
    final wave = Path()
      ..moveTo(left - lead, waveTop)
      ..lineTo(left, waveTop);
    const steps = 96;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = left + span * t;
      final edge = math.pow(math.sin(t * math.pi), 0.7).toDouble();
      final env = amps[(t * (amps.length - 1)).floor()] * edge;
      final y = waveTop - math.sin(t * math.pi * 6) * (rr * 0.82) * env;
      wave.lineTo(x, y);
    }
    wave
      ..lineTo(right, waveTop)
      ..lineTo(right + lead, waveTop);
    canvas.drawPath(wave, stroke);

    if (withFrame) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.withFrame != withFrame;
}
