import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icons.dart';

/// 地図ピンの状態。
enum MarkerKind { locked, unlocked, pending }

/// flutter_map のマーカー用ウィジェット（ブランドグラデのティアドロップ＋状態グリフ）。
class MapPin extends StatelessWidget {
  final MarkerKind kind;
  final double size;
  const MapPin({super.key, required this.kind, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final (Color glyphColor, IconData glyph) = switch (kind) {
      MarkerKind.locked => (const Color(0xFF6B72C9), AppIcons.locked),
      MarkerKind.unlocked => (const Color(0xFF2BB3A3), AppIcons.unlocked),
      MarkerKind.pending => (const Color(0xFFE0922B), AppIcons.pending),
    };
    return SizedBox(
      width: size,
      height: size * 1.25,
      child: CustomPaint(
        painter: _PinPainter(),
        child: Align(
          alignment: const Alignment(0, -0.35),
          child: Icon(glyph, color: glyphColor, size: size * 0.42),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final cc = Offset(cx, w * 0.45);
    final r = w * 0.42;
    final tip = Offset(cx, h - 2);
    final rect = Offset.zero & size;

    // 影
    canvas.drawCircle(Offset(cx, h - 5), r * 0.5,
        Paint()..color = Colors.black.withOpacity(0.22));

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(cc.dx - r * 1.5, cc.dy + r * 0.9, cc.dx - r, cc.dy)
      ..arcToPoint(Offset(cc.dx + r, cc.dy),
          radius: Radius.circular(r), clockwise: true)
      ..quadraticBezierTo(cc.dx + r * 1.5, cc.dy + r * 0.9, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(
        path, Paint()..shader = AppColors.brand.createShader(rect));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = Colors.white,
    );
    // 内側の白丸（アイコンの背面）
    canvas.drawCircle(cc, r * 0.66, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
