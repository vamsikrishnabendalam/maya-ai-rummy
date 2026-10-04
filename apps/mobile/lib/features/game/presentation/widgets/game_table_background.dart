import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen background with dark navy gradient and center spotlight effect.
class GameTableBackground extends StatelessWidget {
  final Widget child;

  const GameTableBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.tableGradientTop,
            AppColors.tableGradientBottom,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _TableSpotlightPainter(),
        child: child,
      ),
    );
  }
}

/// Paints a subtle warm radial spotlight in the center of the table.
class _TableSpotlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.width * 0.6;

    final gradient = RadialGradient(
      center: Alignment(
        (center.dx / size.width) * 2 - 1,
        (center.dy / size.height) * 2 - 1,
      ),
      radius: radius / size.width,
      colors: [
        AppColors.tableSpotlight,
        Colors.transparent,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Subtle felt texture — thin noise lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.008)
      ..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
