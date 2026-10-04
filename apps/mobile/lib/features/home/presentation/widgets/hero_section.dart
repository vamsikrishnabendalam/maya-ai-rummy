import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';

class HeroSection extends StatefulWidget {
  final bool isCompact;

  const HeroSection({Key? key, this.isCompact = false}) : super(key: key);

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Decorative Card Fan with gentle floating physics
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final floatOffset = math.sin(_controller.value * math.pi) * 6;
            return Transform.translate(
              offset: Offset(0, floatOffset),
              child: _buildCardFan(widget.isCompact ? 0.8 : 1.0),
            );
          },
        ),
        SizedBox(height: widget.isCompact ? 12 : 20),

        // Brand Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFE082),
              AppColors.accent,
              Color(0xFFFFB300),
              Color(0xFFFF8F00),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            'MAYA AI RUMMY',
            style: TextStyle(
              fontSize: widget.isCompact ? 28 : 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Tagline
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            'Your Cards • Your Strategy • Maya\'s Challenge',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.isCompact ? 12 : 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFan(double scale) {
    final cards = [
      const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
      const Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
      const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
      const Card(suit: Suit.clubs, rank: Rank.jack, deckIndex: 0),
    ];

    final angles = [-15.0, -5.0, 5.0, 15.0];
    final yOffsets = [8.0, 0.0, 0.0, 8.0];

    return SizedBox(
      height: 90 * scale,
      width: 220 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(cards.length, (i) {
          final angle = angles[i] * math.pi / 180;
          final xOffset = (i - 1.5) * 36 * scale;
          final yOffset = yOffsets[i] * scale;

          return Transform.translate(
            offset: Offset(xOffset, yOffset),
            child: Transform.rotate(
              angle: angle,
              child: _buildMiniFanCard(cards[i], scale),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMiniFanCard(Card card, double scale) {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final suitCol = isRed ? AppColors.suitRed : AppColors.suitBlack;
    String rankStr;
    final r = card.rank;
    switch (r) {
      case Rank.ace:
        rankStr = 'A';
        break;
      case Rank.king:
        rankStr = 'K';
        break;
      case Rank.queen:
        rankStr = 'Q';
        break;
      case Rank.jack:
        rankStr = 'J';
        break;
      case Rank.ten:
        rankStr = '10';
        break;
      case Rank.nine:
        rankStr = '9';
        break;
      case Rank.eight:
        rankStr = '8';
        break;
      case Rank.seven:
        rankStr = '7';
        break;
      case Rank.six:
        rankStr = '6';
        break;
      case Rank.five:
        rankStr = '5';
        break;
      case Rank.four:
        rankStr = '4';
        break;
      case Rank.three:
        rankStr = '3';
        break;
      case Rank.two:
        rankStr = '2';
        break;
      case null:
        rankStr = 'JKR';
        break;
    }

    String suitStr;
    switch (card.suit) {
      case Suit.hearts:
        suitStr = '♥';
        break;
      case Suit.diamonds:
        suitStr = '♦';
        break;
      case Suit.clubs:
        suitStr = '♣';
        break;
      case Suit.spades:
        suitStr = '♠';
        break;
      case null:
        suitStr = '🃏';
        break;
    }

    return Container(
      width: 48 * scale,
      height: 72 * scale,
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(4 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankStr,
                  style: TextStyle(
                    color: suitCol,
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  suitStr,
                  style: TextStyle(
                    color: suitCol,
                    fontSize: 10 * scale,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              suitStr,
              style: TextStyle(
                color: suitCol.withValues(alpha: 0.85),
                fontSize: 22 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
