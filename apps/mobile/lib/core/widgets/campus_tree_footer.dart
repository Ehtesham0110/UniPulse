import 'package:flutter/material.dart';

class CampusTreeFooter extends StatelessWidget {
  const CampusTreeFooter({super.key, this.height = 130});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TreePainter()),
    );
  }
}

class _TreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final trunk = Paint()..color = const Color(0xFF9A633E);
    final leaf = Paint()..color = const Color(0xFF43C93A);
    final darkLeaf = Paint()..color = const Color(0xFF2EB934);
    final grass = Paint()..color = const Color(0xFF66D85C);

    canvas.drawRect(Rect.fromLTWH(0, size.height - 12, size.width, 12), grass);

    final xs = [10.0, 52.0, 102.0, 166.0, 238.0, 310.0, 366.0];
    final hs = [52.0, 72.0, 58.0, 94.0, 126.0, 70.0, 96.0];
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i] / 390 * size.width;
      final h = hs[i] / 130 * size.height;
      final base = size.height - 8;
      canvas.drawLine(
        Offset(x, base),
        Offset(x + 10, base - h),
        trunk..strokeWidth = 7,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 8, base - h), width: 45, height: 58),
        leaf,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 4, base - h + 12),
          width: 30,
          height: 38,
        ),
        darkLeaf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
