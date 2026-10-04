import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';

class VisualCardMeldExample extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Card> cards;
  final Card? wildJoker;
  final bool isValid;
  final String statusText;
  final Color? statusColor;

  const VisualCardMeldExample({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.cards,
    this.wildJoker,
    required this.isValid,
    required this.statusText,
    this.statusColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveStatusColor = statusColor ??
        (isValid ? AppColors.groupPure : AppColors.danger);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveStatusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: effectiveStatusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: effectiveStatusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: effectiveStatusColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: effectiveStatusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row of mini cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards.map((c) => _buildMiniCard(c)).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(Card card) {
    final isJoker = card.isPrintedJoker ||
        (wildJoker != null && !card.isPrintedJoker && card.rank == wildJoker!.rank);

    String rankStr;
    if (card.isPrintedJoker) {
      rankStr = 'JKR';
    } else {
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
    }

    String suitStr;
    Color suitCol;
    if (card.isPrintedJoker) {
      suitStr = '🃏';
      suitCol = Colors.purpleAccent;
    } else {
      switch (card.suit) {
        case Suit.hearts:
          suitStr = '♥';
          suitCol = AppColors.suitRed;
          break;
        case Suit.diamonds:
          suitStr = '♦';
          suitCol = AppColors.suitRed;
          break;
        case Suit.clubs:
          suitStr = '♣';
          suitCol = AppColors.suitBlack;
          break;
        case Suit.spades:
          suitStr = '♠';
          suitCol = AppColors.suitBlack;
          break;
        case null:
          suitStr = '🃏';
          suitCol = Colors.purpleAccent;
          break;
      }
    }

    return Container(
      width: 44,
      height: 64,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isJoker ? AppColors.accent : AppColors.cardBorder,
          width: isJoker ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankStr,
                  style: TextStyle(
                    color: suitCol,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  suitStr,
                  style: TextStyle(
                    color: suitCol,
                    fontSize: 10,
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
                fontSize: 18,
              ),
            ),
          ),
          if (isJoker)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'JOKER',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
