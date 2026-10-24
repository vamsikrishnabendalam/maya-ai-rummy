import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import 'card_widget.dart';
import 'card_back_widget.dart';
import 'discard_history_modal.dart';

/// Royal Rummy Center Table Wells:
/// 1. Closed Deck stack with perpendicular wild joker peeking underneath.
/// 2. Open Discard Pile with Discard History button.
/// 3. Finish / Declare Slot for dropping the 14th card to declare show.
class CenterTable extends StatelessWidget {
  final int closedDeckCount;
  final List<Card> openPile;
  final Card? wildJoker;
  final bool isClosedJoker;
  final bool isJokerOpened;
  final bool hasLife;
  final VoidCallback? onOpenClosedJoker;
  final bool canDraw;
  final VoidCallback? onDrawClosed;
  final VoidCallback? onDrawOpen;
  final bool canDeclare;
  final VoidCallback? onDeclare;
  final VoidCallback? onShowDiscardHistory;
  final bool isCompact;

  const CenterTable({
    super.key,
    required this.closedDeckCount,
    required this.openPile,
    this.wildJoker,
    this.isClosedJoker = false,
    this.isJokerOpened = true,
    this.hasLife = false,
    this.onOpenClosedJoker,
    this.canDraw = false,
    this.onDrawClosed,
    this.onDrawOpen,
    this.canDeclare = false,
    this.onDeclare,
    this.onShowDiscardHistory,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double cardW = isCompact ? 48.0 : 58.0;
    final double cardH = isCompact ? 70.0 : 84.0;
    final double spacing = isCompact ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4.0 : 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A. CLOSED DECK + PERPENDICULAR WILD JOKER
          _buildClosedDeckWithTuckedJoker(context, cardW, cardH),
          SizedBox(width: spacing),

          // B. OPEN DECK + DISCARD HISTORY
          _buildOpenDeck(context, cardW, cardH),
          SizedBox(width: spacing),

          // C. FINISH / DECLARE SLOT
          _buildFinishSlot(context, cardW, cardH),
        ],
      ),
    );
  }

  static String _cardRank(Card card) {
    if (card.isPrintedJoker) return 'A';
    switch (card.rank) {
      case Rank.ace: return 'A';
      case Rank.king: return 'K';
      case Rank.queen: return 'Q';
      case Rank.jack: return 'J';
      case Rank.ten: return '10';
      case Rank.nine: return '9';
      case Rank.eight: return '8';
      case Rank.seven: return '7';
      case Rank.six: return '6';
      case Rank.five: return '5';
      case Rank.four: return '4';
      case Rank.three: return '3';
      case Rank.two: return '2';
      default: return 'A';
    }
  }

  /// Closed deck stack with perpendicular wild joker tucked horizontally underneath
  Widget _buildClosedDeckWithTuckedJoker(BuildContext context, double cardW, double cardH) {
    final bool showJokerFace = !isClosedJoker || isJokerOpened;
    final double tuckedW = isCompact ? 40.0 : 48.0;
    final double tuckedH = isCompact ? 58.0 : 70.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cardW + (isCompact ? 22.0 : 30.0),
          height: cardH + (isCompact ? 6.0 : 8.0),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // 1. Perpendicular Wild Joker peeking horizontally to the left (-90 deg rotation)
              Positioned(
                left: -(isCompact ? 12.0 : 18.0),
                top: (cardH - tuckedW) / 2 + (isCompact ? 4.0 : 6.0),
                child: Transform.rotate(
                  angle: -1.5708, // -90 degrees in radians
                  child: GestureDetector(
                    onTap: (!showJokerFace && hasLife) ? onOpenClosedJoker : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: (showJokerFace && wildJoker != null)
                          ? CardWidget(
                              card: wildJoker!,
                              isWildJoker: true,
                              width: tuckedW,
                              height: tuckedH,
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                CardBackWidget(
                                  width: tuckedW,
                                  height: tuckedH,
                                  showPulse: hasLife,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: hasLife ? const Color(0xFFF59E0B) : Colors.black87,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: hasLife ? Colors.white : Colors.amber.shade700,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    hasLife ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                    size: 11,
                                    color: hasLife ? Colors.black : Colors.amber.shade200,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              // 2. Closed Deck Stack (3 layered cards)
              Positioned(
                right: 4,
                top: 4,
                child: CardBackWidget(width: cardW, height: cardH),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: CardBackWidget(width: cardW, height: cardH),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CardBackWidget(
                      width: cardW,
                      height: cardH,
                      showPulse: canDraw,
                      onTap: canDraw ? onDrawClosed : null,
                    ),
                    // Deck Count Badge
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFBBF24), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '$closedDeckCount',
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'CLOSED',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE2E8F0),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 0.6),
              ),
              child: Text(
                (showJokerFace && wildJoker != null) ? 'JOKER: ${_cardRank(wildJoker!)}' : 'LOCKED',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFDE68A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Open deck showing top discarded card and Discard History button
  Widget _buildOpenDeck(BuildContext context, double cardW, double cardH) {
    final topCard = openPile.isNotEmpty ? openPile.last : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: cardW,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (topCard != null)
                GestureDetector(
                  onTap: canDraw ? onDrawOpen : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        if (canDraw)
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: CardWidget(
                      card: topCard,
                      isWildJoker: JokerUtils.isWildJoker(topCard, wildJoker),
                      width: cardW,
                      height: cardH,
                    ),
                  ),
                )
              else
                Container(
                  width: cardW,
                  height: cardH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                    color: const Color(0xFF042619).withValues(alpha: 0.5),
                  ),
                  child: const Center(
                    child: Text(
                      'EMPTY',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Discard Pile History Button (Pill at top-right)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () {
                    if (onShowDiscardHistory != null) {
                      onShowDiscardHistory!();
                    } else {
                      DiscardHistoryModal.show(
                        context,
                        discardPile: openPile,
                        wildJoker: wildJoker,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFBBF24), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 11,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'OPEN (${openPile.length})',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE2E8F0),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  /// Finish slot for dropping 14th card to declare show
  Widget _buildFinishSlot(BuildContext context, double cardW, double cardH) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canDeclare ? onDeclare : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              color: canDeclare
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                  : const Color(0xFF042619).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: canDeclare
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: canDeclare ? 2.0 : 1.2,
              ),
              boxShadow: [
                if (canDeclare)
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  color: canDeclare ? const Color(0xFFFBBF24) : const Color(0xFFFBBF24).withValues(alpha: 0.65),
                  size: isCompact ? 18 : 22,
                ),
                const SizedBox(height: 3),
                Text(
                  'FINISH',
                  style: TextStyle(
                    fontSize: isCompact ? 8 : 9,
                    fontWeight: FontWeight.w900,
                    color: canDeclare ? const Color(0xFFFDE68A) : Colors.white70,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '14th Card',
                  style: TextStyle(
                    fontSize: isCompact ? 6.5 : 7.5,
                    color: canDeclare ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'DECLARE',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFBBF24),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
