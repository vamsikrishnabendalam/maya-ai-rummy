import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PlayWithMayaCTA extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const PlayWithMayaCTA({
    Key? key,
    required this.onPressed,
    this.label = 'PLAY WITH MAYA AI',
  }) : super(key: key);

  @override
  State<PlayWithMayaCTA> createState() => _PlayWithMayaCTAState();
}

class _PlayWithMayaCTAState extends State<PlayWithMayaCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = 0.35 + (_pulseController.value * 0.25);
        final scale = _isHovered ? 1.03 : (1.0 + (_pulseController.value * 0.015));

        return Transform.scale(
          scale: scale,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: glowAlpha),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHover: (hovered) => setState(() => _isHovered = hovered),
                borderRadius: BorderRadius.circular(28),
                splashColor: Colors.white24,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD54F),
                        AppColors.accent,
                        Color(0xFFFF8F00),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF1A1A1A),
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF1A1A1A),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
