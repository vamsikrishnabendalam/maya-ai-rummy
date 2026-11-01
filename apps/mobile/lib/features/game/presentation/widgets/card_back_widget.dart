import 'package:flutter/material.dart';

/// Face-down card displaying the authentic custom card back artwork.
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
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 5.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.5),
            child: Image.asset(
              'assets/cards/card_back.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF1E3A8A),
                  child: Center(
                    child: Text(
                      'CARD',
                      style: TextStyle(
                        fontSize: width * 0.22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                );
              },
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
