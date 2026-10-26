import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/utils/responsive.dart';
import 'card_widget.dart';
import 'card_back_widget.dart';
import 'discard_history_modal.dart';
import '../../models/card_group.dart';

/// Maya AI Rummy Center Table Wells:
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
  final void Function(Card card)? onCardDeclared;
  final VoidCallback? onShowDiscardHistory;
  final bool isCompact;
  final double? cardWidth;
  final double? cardHeight;
  final double? spacing;
  final String? potAmount;
  final String? pointValue;
  final String? lastDiscardFrom;

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
    this.onCardDeclared,
    this.onShowDiscardHistory,
    this.isCompact = false,
    this.cardWidth,
    this.cardHeight,
    this.spacing,
    this.potAmount,
    this.pointValue,
    this.lastDiscardFrom,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final bool isDesktop = Responsive.isDesktop(context) || screenW >= 1024;
    final bool isTablet = Responsive.isTablet(context) || (screenW >= 768 && screenW < 1024);

    final double cardW;
    final double cardH;
    final double cardSpacing;

    if (cardWidth != null && cardHeight != null) {
      cardW = cardWidth!;
      cardH = cardHeight!;
      cardSpacing = spacing ?? (isCompact ? 16.0 : 28.0);
    } else if (isDesktop) {
      // Large stadium screen: significantly enlarged crisp cards
      if (screenW >= 1400 && screenH >= 700) {
        cardW = 98.0;
        cardH = 142.0;
        cardSpacing = spacing ?? 38.0;
      } else {
        cardW = 86.0;
        cardH = 124.0;
        cardSpacing = spacing ?? 32.0;
      }
    } else if (isTablet) {
      cardW = 70.0;
      cardH = 102.0;
      cardSpacing = spacing ?? 24.0;
    } else if (isCompact) {
      cardW = 46.0;
      cardH = 66.0;
      cardSpacing = spacing ?? 16.0;
    } else {
      cardW = 58.0;
      cardH = 84.0;
      cardSpacing = spacing ?? 20.0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Live Pot & Stakes Banner
        Container(
          margin: EdgeInsets.only(bottom: isCompact ? 3 : 6),
          padding: EdgeInsets.symmetric(
            horizontal: (cardW * 0.18).clamp(10.0, 18.0),
            vertical: (cardW * 0.04).clamp(2.5, 6.0),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF060F16).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TABLE POT',
                style: TextStyle(
                  color: const Color(0xFFD0C5AF),
                  fontSize: (cardW * 0.13).clamp(8.0, 12.0),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                potAmount ?? '🪙 1,200',
                style: TextStyle(
                  color: const Color(0xFFF2CA50),
                  fontSize: (cardW * 0.17).clamp(11.0, 16.0),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '•',
                style: TextStyle(
                  color: const Color(0xFF99907C),
                  fontSize: (cardW * 0.13).clamp(9.0, 13.0),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                pointValue != null ? 'Point: $pointValue' : 'Point: 10 pts',
                style: TextStyle(
                  color: const Color(0xFFDAE4ED),
                  fontSize: (cardW * 0.14).clamp(9.5, 13.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // 2. Wells Row: Closed Deck, Open Discard Pile, Finish Slot
        Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 1.0 : 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // A. CLOSED DECK + PERPENDICULAR WILD JOKER
              _buildClosedDeckWithTuckedJoker(context, cardW, cardH),
              SizedBox(width: cardSpacing),

              // B. OPEN DECK + DISCARD HISTORY
              _buildOpenDeck(context, cardW, cardH),
              SizedBox(width: cardSpacing),

              // C. FINISH / DECLARE SLOT
              _buildFinishSlot(context, cardW, cardH),
            ],
          ),
        ),
      ],
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
    final double tuckedW = cardW * 0.72;
    final double tuckedH = cardH * 0.75;
    final double stackW = cardW + (cardW * 0.44);
    final double stackH = cardH + (cardH * 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackW,
          height: stackH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              // 1. Perpendicular Wild Joker peeking horizontally to the left (-90 deg rotation)
              Positioned(
                left: -(cardW * 0.22),
                top: (cardH - tuckedW) / 2 + 4.0,
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
                                  padding: EdgeInsets.all((cardW * 0.045).clamp(3.0, 6.0)),
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
                                    size: (cardW * 0.16).clamp(11.0, 18.0),
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
                    // Floating DRAW Action Pill
                    if (canDraw)
                      Positioned(
                        top: -(cardH * 0.11),
                        left: -4,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (cardW * 0.09).clamp(5.0, 9.0),
                            vertical: (cardW * 0.025).clamp(1.5, 4.0),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2CA50),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            'DRAW',
                            style: TextStyle(
                              color: const Color(0xFF241A00),
                              fontSize: (cardW * 0.12).clamp(7.5, 12.0),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    // Deck Count Badge
                    Positioned(
                      top: -(cardH * 0.08),
                      right: -6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (cardW * 0.09).clamp(5.0, 9.0),
                          vertical: (cardW * 0.025).clamp(1.5, 4.0),
                        ),
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
                          style: TextStyle(
                            color: const Color(0xFFFDE68A),
                            fontSize: (cardW * 0.14).clamp(9.0, 14.0),
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
        SizedBox(height: isCompact ? 2 : 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CLOSED',
              style: TextStyle(
                fontSize: (cardW * 0.14).clamp(8.5, 13.0),
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE2E8F0),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: (cardW * 0.07).clamp(4.0, 8.0),
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 0.6),
              ),
              child: Text(
                (showJokerFace && wildJoker != null) ? 'JOKER: ${_cardRank(wildJoker!)}' : 'LOCKED',
                style: TextStyle(
                  fontSize: (cardW * 0.12).clamp(8.0, 11.5),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFDE68A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Open deck showing last up to 5 discarded cards in an overlapping cascade,
  /// exposing the rank and suit of each card with the top card interactive to draw.
  Widget _buildOpenDeck(BuildContext context, double cardW, double cardH) {
    if (openPile.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 1.5,
              ),
              color: const Color(0xFF042619).withValues(alpha: 0.5),
            ),
            child: Center(
              child: Text(
                'EMPTY',
                style: TextStyle(
                  fontSize: (cardW * 0.14).clamp(9.0, 13.0),
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 2 : 5),
          Text(
            'OPEN PILE',
            style: TextStyle(
              fontSize: (cardW * 0.14).clamp(9.5, 13.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE2E8F0),
              letterSpacing: 0.6,
            ),
          ),
        ],
      );
    }

    final int count = openPile.length > 5 ? 5 : openPile.length;
    final int startIndex = openPile.length - count;
    final visibleCards = openPile.sublist(startIndex);
    final double overlapOffset = cardW * 0.44;
    final double totalW = cardW + (count - 1) * overlapOffset;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: totalW,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (int i = 0; i < count; i++)
                Positioned(
                  left: i * overlapOffset,
                  top: 0,
                  child: _buildOpenPileCardItem(
                    context: context,
                    card: visibleCards[i],
                    isTop: i == count - 1,
                    cardW: cardW,
                    cardH: cardH,
                  ),
                ),

              // Discard Pile History Button (Pill at top-right of stack)
              Positioned(
                top: -(cardH * 0.08),
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
                    padding: EdgeInsets.all((cardW * 0.06).clamp(4.0, 8.0)),
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
                    child: Icon(
                      Icons.history_rounded,
                      size: (cardW * 0.18).clamp(11.0, 18.0),
                      color: const Color(0xFFFDE68A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 2 : 5),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: (cardW * 0.09).clamp(5.0, 10.0),
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF222B32).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'From: ',
                style: TextStyle(
                  color: const Color(0xFFD0C5AF),
                  fontSize: (cardW * 0.12).clamp(8.0, 11.5),
                ),
              ),
              Text(
                lastDiscardFrom ?? 'Maya',
                style: TextStyle(
                  color: const Color(0xFFF2CA50),
                  fontSize: (cardW * 0.13).clamp(8.5, 12.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenPileCardItem({
    required BuildContext context,
    required Card card,
    required bool isTop,
    required double cardW,
    required double cardH,
  }) {
    final isWild = JokerUtils.isWildJoker(card, wildJoker);

    final cardWidget = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 5,
            offset: const Offset(1, 2),
          ),
          if (isTop && canDraw)
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
        border: Border.all(
          color: isTop && canDraw
              ? const Color(0xFFFBBF24)
              : Colors.black.withValues(alpha: 0.25),
          width: isTop && canDraw ? 2.0 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          CardWidget(
            card: card,
            isWildJoker: isWild,
            width: cardW,
            height: cardH,
          ),
          if (isTop)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'TOP',
                  style: TextStyle(
                    fontSize: (cardW * 0.10).clamp(7.0, 10.0),
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isTop) {
      return GestureDetector(
        onTap: canDraw ? onDrawOpen : null,
        child: cardWidget,
      );
    }
    return cardWidget;
  }

  /// Finish slot for dropping 14th card to declare show
  Widget _buildFinishSlot(BuildContext context, double cardW, double cardH) {
    Widget slotContent = GestureDetector(
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
              size: (cardW * 0.36).clamp(18.0, 32.0),
            ),
            const SizedBox(height: 3),
            Text(
              'FINISH',
              style: TextStyle(
                fontSize: (cardW * 0.14).clamp(8.0, 13.0),
                fontWeight: FontWeight.w900,
                color: canDeclare ? const Color(0xFFFDE68A) : Colors.white70,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '14th Card',
              style: TextStyle(
                fontSize: (cardW * 0.11).clamp(6.5, 10.5),
                color: canDeclare ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );

    if (onCardDeclared != null) {
      slotContent = DragTarget<Object>(
        onWillAcceptWithDetails: (_) => canDeclare,
        onAcceptWithDetails: (details) {
          if (details.data is CardDragData) {
            onCardDeclared?.call((details.data as CardDragData).card);
          } else if (details.data is Card) {
            onCardDeclared?.call(details.data as Card);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isHovering ? Border.all(color: const Color(0xFF10B981), width: 2.5) : null,
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        blurRadius: 16,
                      )
                    ]
                  : null,
            ),
            child: slotContent,
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        slotContent,
        SizedBox(height: isCompact ? 2 : 5),
        Text(
          'DECLARE',
          style: TextStyle(
            fontSize: (cardW * 0.14).clamp(8.5, 13.0),
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFBBF24),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
