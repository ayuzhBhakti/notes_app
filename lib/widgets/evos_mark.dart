import 'package:flutter/material.dart';

import '../theme.dart';

/// The launcher icon, drawn: the white E and amber dot on the violet tile.
///
/// Painted from the same geometry as tool/app_icon/evos_rounded.svg rather
/// than shipped as an image, so it is sharp at any size and needs no asset or
/// SVG package. Keep the two in step if the icon changes.
class EvosMark extends StatelessWidget {
  const EvosMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    // Decorative: every screen that shows it also says "Evos" in text.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: kBrandGradient,
          // rx 23.76 on the icon's 108-unit grid.
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: kBrandViolet.withValues(alpha: 0.35),
              blurRadius: size * 0.35,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The SVG's 108-unit grid, with its scale(1.12) about the centre applied.
    final double unit = size.width / 108;
    double at(double v) => (54 + 1.12 * (v - 54)) * unit;
    double len(double v) => 1.12 * v * unit;

    final Paint white = Paint()..color = Colors.white;
    void bar(double x, double y, double w, double h) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at(x), at(y), len(w), len(h)),
          Radius.circular(len(4)),
        ),
        white,
      );
    }

    bar(36, 38, 8, 34);
    bar(36, 38, 28, 8);
    bar(36, 51, 22, 8);
    bar(36, 64, 28, 8);
    canvas.drawCircle(
      Offset(at(71), at(33)),
      len(3.5),
      Paint()..color = kBrandAmber,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
