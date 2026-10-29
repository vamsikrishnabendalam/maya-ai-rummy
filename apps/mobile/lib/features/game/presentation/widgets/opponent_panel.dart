import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive.dart';

/// Luxury circular Opponent Pod matching the HTML reference design:
/// - Circular avatar pod with pulsing radial countdown/timer ring during active turn
/// - Dealer 'D' badge in rich gold container
/// - Hand count badge with cards icon (e.g. '13 🎴')
/// - Opponent name and score / stake status in Outfit/Plus Jakarta Sans
class OpponentPanel extends StatefulWidget {
  /// The AI opponent player state.
  final Player opponent;

  /// Whether the AI is currently calculating its move.
  final bool isThinking;

  /// Difficulty label displayed on the badge (e.g. 'Beginner', 'Expert').
  final String difficultyLabel;

  /// Whether the AI opponent is the dealer for the current deal.
  final bool isDealer;

  /// Chips or tournament score string (e.g. '₹18,400' or '0 pts').
  final String? scoreText;

  /// When true, renders a sleek floating status pill so the painted Host character in the background is not obstructed.
  final bool isHostOverlay;

  const OpponentPanel({
    Key? key,
    required this.opponent,
    this.isThinking = false,
    this.difficultyLabel = 'Expert',
    this.isDealer = false,
    this.scoreText,
    this.isHostOverlay = false,
  }) : super(key: key);

  @override
  State<OpponentPanel> createState() => _OpponentPanelState();
}

class _OpponentPanelState extends State<OpponentPanel> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (widget.isHostOverlay) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xCC120424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isThinking ? const Color(0xFFF2CA50) : const Color(0x66A855F7),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isDealer) ...[
              Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF241A00),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
            const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFFBBF24)),
            const SizedBox(width: 4),
            Text(
              'Maya (AI Host)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: isDesktop ? 12.5 : 11.0,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(width: 6),
            Text(
              widget.scoreText ?? widget.difficultyLabel,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isDesktop ? 10.5 : 9.0,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFBAE6FD),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0x40000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.opponent.hand.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF2CA50),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.style, size: 8.5, color: Color(0xFFF2CA50)),
                ],
              ),
            ),
            if (widget.isThinking) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2CA50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 9, color: Color(0xFF241A00)),
                    const SizedBox(width: 2),
                    Text(
                      'Thinking...',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF241A00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    final double avatarSize = isDesktop ? 60.0 : 48.0;
    final double glowSize = isDesktop ? 66.0 : 52.0;
    final double emojiSize = isDesktop ? 28.0 : 22.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Circular Avatar Pod with Timer Ring
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Active Turn Radial Pulsing Glow
            if (widget.isThinking)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF2CA50).withValues(
                            alpha: 0.35 + _pulseController.value * 0.35,
                          ),
                          blurRadius: 16 + _pulseController.value * 8,
                          spreadRadius: 2 + _pulseController.value * 4,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Base Avatar Container with Timer Border
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF182128),
                    Color(0xFF0B141B),
                  ],
                ),
                border: Border.all(
                  color: widget.isThinking
                      ? const Color(0xFFF2CA50)
                      : const Color(0xFF2D363D),
                  width: widget.isThinking ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: emojiSize),
                ),
              ),
            ),

            // Top Timer Pill (when thinking)
            if (widget.isThinking)
              Positioned(
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2CA50),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 9, color: Color(0xFF241A00)),
                      const SizedBox(width: 2),
                      Text(
                        '12s',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF241A00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom-Left Dealer Badge
            if (widget.isDealer)
              Positioned(
                bottom: -4,
                left: -4,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF241A00),
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom-Right Card Count Badge
            Positioned(
              bottom: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D363D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.opponent.hand.length}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF2CA50),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.style, size: 8.5, color: Color(0xFFF2CA50)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // 2. Name & Stakes Status
        Text(
          'Maya Bot',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isDesktop ? 13.5 : 11.0,
            fontWeight: FontWeight.w700,
            color: widget.isThinking ? const Color(0xFFF2CA50) : const Color(0xFFDAE4ED),
          ),
        ),
        Text(
          widget.scoreText ?? widget.difficultyLabel,
          style: GoogleFonts.jetBrainsMono(
            fontSize: isDesktop ? 11.0 : 9.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFD0C5AF),
          ),
        ),
      ],
    );
  }
}
