import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart' show Card, Rank, Suit;
import 'package:google_fonts/google_fonts.dart';

import '../../providers/game_ui_provider.dart';
import 'card_back_widget.dart';
import 'card_widget.dart';

/// Secret royal reveal animation shown ONLY to the player when their
/// Pure Sequence (1st Life) is formed in a Closed Joker game.
class SecretJokerRevealOverlay extends ConsumerStatefulWidget {
  final Card wildJoker;
  final VoidCallback onDismiss;

  const SecretJokerRevealOverlay({
    super.key,
    required this.wildJoker,
    required this.onDismiss,
  });

  @override
  ConsumerState<SecretJokerRevealOverlay> createState() =>
      _SecretJokerRevealOverlayState();
}

class _SecretJokerRevealOverlayState extends ConsumerState<SecretJokerRevealOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flipAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 40,
      ),
    ]).animate(_controller);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Auto-dismiss after 3.8 seconds so the player has ample time to enjoy the reveal
    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        _handleDismiss();
      }
    });
  }

  void _handleDismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRankName(Rank? rank) {
    if (rank == null) return 'Card';
    switch (rank) {
      case Rank.ace:
        return 'Ace';
      case Rank.king:
        return 'King';
      case Rank.queen:
        return 'Queen';
      case Rank.jack:
        return 'Jack';
      case Rank.ten:
        return '10';
      case Rank.nine:
        return '9';
      case Rank.eight:
        return '8';
      case Rank.seven:
        return '7';
      case Rank.six:
        return '6';
      case Rank.five:
        return '5';
      case Rank.four:
        return '4';
      case Rank.three:
        return '3';
      case Rank.two:
        return '2';
    }
  }

  String _getSuitName(Suit? suit) {
    if (suit == null) return '';
    switch (suit) {
      case Suit.hearts:
        return 'Hearts ♥';
      case Suit.diamonds:
        return 'Diamonds ♦';
      case Suit.clubs:
        return 'Clubs ♣';
      case Suit.spades:
        return 'Spades ♠';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wildJoker = widget.wildJoker;
    final isPrinted = wildJoker.isPrintedJoker;
    final rankName = isPrinted ? 'Printed Joker' : _getRankName(wildJoker.rank);
    final suitName = isPrinted ? '' : _getSuitName(wildJoker.suit);
    final isRedSuit = wildJoker.suit == Suit.hearts || wildJoker.suit == Suit.diamonds;

    const double cardW = 100.0;
    const double cardH = 140.0;

    return GestureDetector(
      onTap: _handleDismiss,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _flipAnimation.value;
          final isBackVisible = angle < (math.pi / 2);

          return Container(
            color: Colors.black.withValues(alpha: 0.65 * _controller.value),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Radial Golden Aura Pulse
                  Opacity(
                    opacity: _glowAnimation.value,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x99F59E0B),
                            Color(0x44D4AF37),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.45, 0.85],
                        ),
                      ),
                    ),
                  ),

                  // 2. Central Presentation Column
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Royal Header Banner
                      Opacity(
                        opacity: _glowAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xEE1E1303),
                                Color(0xFF2C1E0A),
                                Color(0xEE1E1303),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFF2CA50),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                color: Color(0xFFFDE68A),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SECRET WILD JOKER REVEALED',
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFDE68A),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.lock_open_rounded,
                                color: Color(0xFFF2CA50),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Flipping Card with 3D Y-Axis Rotation
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(angle),
                        child: Container(
                          width: cardW,
                          height: cardH,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                                blurRadius: 18,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: isBackVisible
                              ? const CardBackWidget(
                                  width: cardW,
                                  height: cardH,
                                  showPulse: true,
                                )
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(math.pi),
                                  child: CardWidget(
                                    card: wildJoker,
                                    isWildJoker: false,
                                    width: cardW,
                                    height: cardH,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Info Tag Badge
                      Opacity(
                        opacity: _glowAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xF00F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0x99F59E0B),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isPrinted
                                    ? '★ PRINTED JOKER ★'
                                    : '★ ${rankName.toUpperCase()} OF ${suitName.toUpperCase()} ★',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isRedSuit
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFFDE68A),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPrinted
                                    ? 'Acts as Wild Joker for all sequences'
                                    : 'All ${rankName}s now act as Wild Jokers in your hand!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Dismiss Hint
                      Opacity(
                        opacity: _glowAnimation.value * 0.7,
                        child: Text(
                          'Tap anywhere to dismiss',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            color: Colors.white38,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
