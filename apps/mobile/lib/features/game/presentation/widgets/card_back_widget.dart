import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Face-down card for opponent's hand and closed deck display.
class CardBackWidget extends StatelessWidget {
  final double width;
  final double height;
  final double rotation;
  final VoidCallback? onTap;
  final bool showPulse;

  const CardBackWidget({
    Key? key,
    this.width = 52.0,
    this.height = 78.0,
    this.rotation = 0.0,
    this.onTap,
    this.showPulse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Transform.rotate(
      angle: rotation * 3.14159 / 180.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.deckBack,
                AppColors.deckBackAccent,
                AppColors.deckBack,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.0),
            child: CustomPaint(
              painter: _CardBackPatternPainter(),
              child: Center(
                child: Container(
                  width: width * 0.5,
                  height: height * 0.35,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: width * 0.3,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.3),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (showPulse) {
      card = _PulseWrapper(child: card);
    }

    return card;
  }
}

/// Paints a subtle diamond pattern on the card back.
class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 12.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final path = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wraps a widget with a subtle scale pulse animation (for draw hints).
class _PulseWrapper extends StatefulWidget {
  final Widget child;
  const _PulseWrapper({required this.child});

  @override
  State<_PulseWrapper> createState() => _PulseWrapperState();
}

class _PulseWrapperState extends State<_PulseWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.04),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
