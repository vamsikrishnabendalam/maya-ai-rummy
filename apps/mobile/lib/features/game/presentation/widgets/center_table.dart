import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import 'card_widget.dart';
import 'card_back_widget.dart';

/// Center table widget displaying the closed deck, wild joker, and open discard pile.
class CenterTable extends StatelessWidget {
  /// Number of cards remaining in the closed deck.
  final int closedDeckCount;

  /// Cards currently in the open discard pile.
  final List<Card> openPile;

  /// The wild joker card turned face-up for the current round.
  final Card wildJoker;

  /// Whether the table is playing with closed joker rule.
  final bool isClosedJoker;

  /// Whether the player has opened and revealed the joker.
  final bool isJokerOpened;

  /// Whether the player holds a valid Pure Sequence (Life) to view joker.
  final bool hasLife;

  /// Callback when player taps to open/view the closed joker.
  final VoidCallback? onOpenClosedJoker;

  /// Whether the player can tap either deck to draw a card.
  final bool canDraw;

  /// Callback invoked when the closed deck is tapped.
  final VoidCallback? onDrawClosed;

  /// Callback invoked when the open discard pile top card is tapped.
  final VoidCallback? onDrawOpen;

  const CenterTable({
    super.key,
    required this.closedDeckCount,
    required this.openPile,
    required this.wildJoker,
    this.isClosedJoker = false,
    this.isJokerOpened = true,
    this.hasLife = false,
    this.onOpenClosedJoker,
    this.canDraw = false,
    this.onDrawClosed,
    this.onDrawOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildClosedDeck(),
          const SizedBox(width: 24),
          _buildWildJoker(),
          const SizedBox(width: 24),
          _buildOpenPile(),
        ],
      ),
    );
  }

  /// Builds the closed deck stack with depth effect and pulse indicator when drawable.
  Widget _buildClosedDeck() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 94,
          child: Center(
            child: SizedBox(
              width: 62,
              height: 92,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: CardBackWidget(
                      width: 60,
                      height: 90,
                    ),
                  ),
                  const Positioned(
                    left: 1,
                    top: 1,
                    child: CardBackWidget(
                      width: 60,
                      height: 90,
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 2,
                    child: CardBackWidget(
                      width: 60,
                      height: 90,
                      showPulse: canDraw,
                      onTap: canDraw ? onDrawClosed : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Deck ($closedDeckCount)',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Builds the wild joker display with surrounding golden glow and label.
  Widget _buildWildJoker() {
    if (isClosedJoker && !isJokerOpened) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 94,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CardBackWidget(
                    width: 56,
                    height: 84,
                    showPulse: hasLife,
                    onTap: hasLife ? onOpenClosedJoker : null,
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: hasLife ? AppColors.accent : Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasLife ? Colors.white : Colors.amber.shade700,
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (hasLife)
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                        ],
                      ),
                      child: Icon(
                        hasLife ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 13,
                        color: hasLife ? Colors.black : Colors.amber.shade200,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (hasLife)
            GestureDetector(
              onTap: onOpenClosedJoker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VIEW JOKER',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
          else
            const Column(
              children: [
                Text(
                  'CLOSED JOKER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '(Need Life)',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 94,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CardWidget(
                card: wildJoker,
                isWildJoker: true,
                width: 56,
                height: 84,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          wildJoker.isPrintedJoker ? 'OPEN JOKER: A' : 'OPEN JOKER',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
            letterSpacing: 1,
          ),
        ),
        if (wildJoker.isPrintedJoker)
          const Text(
            '(Ace is Wild)',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textGold,
            ),
          ),
      ],
    );
  }

  /// Builds the open discard pile displaying at least 3 cards fanned diagonally,
  /// with only the top card interactive for drawing.
  Widget _buildOpenPile() {
    Widget pileContent;

    if (openPile.isEmpty) {
      pileContent = Container(
        width: 60,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: Text(
            'Empty',
            style: TextStyle(
              fontSize: 11,
              color: Color(0x66FFFFFF),
            ),
          ),
        ),
      );
    } else {
      // Display up to 3 latest discarded cards
      final count = openPile.length > 5 ? 5 : openPile.length;
      final startIndex = openPile.length - count;
      final visibleCards = openPile.sublist(startIndex);

      pileContent = SizedBox(
        width: 60.0 + (count - 1) * 22.0,
        height: 90.0 + (count - 1) * 6.0,
        child: Stack(
          children: List.generate(count, (index) {
            final isTop = index == count - 1;
            final card = visibleCards[index];
            final xOffset = index * 22.0;
            final yOffset = index * 6.0;

            return Positioned(
              left: xOffset,
              top: yOffset,
              child: CardWidget(
                card: card,
                isWildJoker: JokerUtils.isWildJoker(card, wildJoker),
                width: 60,
                height: 90,
                onTap: isTop && canDraw ? onDrawOpen : null,
              ),
            );
          }),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: pileContent),
        const SizedBox(height: 6),
        const Text(
          'OPEN PILE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
