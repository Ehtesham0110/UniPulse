import 'package:flutter/material.dart';

class CampusTreeFooter extends StatelessWidget {
  const CampusTreeFooter({
    super.key,
    this.height = 130,
    this.fadeTop = false,
  });

  final double height;

  /// When true, blends the top edge of the footer into whatever sits
  /// behind it (assumed white/near-white) so it reads as a soft
  /// decorative strip rather than a hard-edged banner. Off by default to
  /// avoid changing the look on existing screens that already use this
  /// footer at full height.
  final bool fadeTop;

  @override
  Widget build(BuildContext context) {
    final trees = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TreePainter()),
    );

    if (!fadeTop) return trees;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white],
        stops: [0.0, 0.45],
      ).createShader(rect),
      child: trees,
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

    // Every dimension below scales off canvas height, not just the trunk
    // line. Previously the leaf ovals were fixed-pixel (45x58) regardless
    // of `size.height`, so at a short footer height they'd clip past the
    // canvas and read as a foreground shape instead of a small footer
    // decoration. Scaling everything keeps trees legible and
    // proportionate at both the original ~130px size and a compact
    // ~40px footer.
    final scale = (size.height / 130).clamp(0.18, 1.0);
    final grassHeight = (12 * scale).clamp(3.0, 12.0);

    canvas.drawRect(
      Rect.fromLTWH(0, size.height - grassHeight, size.width, grassHeight),
      grass,
    );

    final xs = [10.0, 52.0, 102.0, 166.0, 238.0, 310.0, 366.0];
    final hs = [52.0, 72.0, 58.0, 94.0, 126.0, 70.0, 96.0];
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i] / 390 * size.width;
      final h = hs[i] / 130 * size.height;
      final base = size.height - grassHeight * 0.6;
      canvas.drawLine(
        Offset(x, base),
        Offset(x + 10 * scale, base - h),
        trunk..strokeWidth = (7 * scale).clamp(1.5, 7.0),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 8 * scale, base - h),
          width: 45 * scale,
          height: 58 * scale,
        ),
        leaf,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 4 * scale, base - h + 12 * scale),
          width: 30 * scale,
          height: 38 * scale,
        ),
        darkLeaf,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}