import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/card_group.dart';
import 'card_widget.dart';

/// Renders a single group of cards with a type label and fan layout.
/// Accepts dropped cards from other groups and supports intra-group reordering.
class CardGroupWidget extends StatelessWidget {
  final CardGroup group;
  final int groupIndex;
  final int globalStartIndex;
  final int totalHandCards;
  final Card? wildJokerCard;
  final double cardWidth;
  final double cardHeight;
  final double cardOverlap;
  final bool isHovered;
  final Card? selectedCard;
  final Set<Card> selectedCards;
  final ValueChanged<Card>? onCardTap;
  final void Function(Card card, String fromGroupId)? onCardDropped;
  final void Function(Card card, String fromGroupId, int targetIndex)? onCardDroppedAtIndex;
  final void Function(int oldIndex, int newIndex)? onCardReordered;
  final void Function(Card card, String groupId)? onCardDragStarted;

  const CardGroupWidget({
    Key? key,
    required this.group,
    this.groupIndex = 0,
    this.globalStartIndex = 0,
    this.totalHandCards = 13,
    this.wildJokerCard,
    this.cardWidth = 52,
    this.cardHeight = 78,
    this.cardOverlap = 28,
    this.isHovered = false,
    this.selectedCard,
    this.selectedCards = const {},
    this.onCardTap,
    this.onCardDropped,
    this.onCardDroppedAtIndex,
    this.onCardReordered,
    this.onCardDragStarted,
  }) : super(key: key);

  Color _groupColor() {
    switch (group.type) {
      case CardGroupType.pureSequence:
        return const Color(0xFF005035); // on-tertiary-container
      case CardGroupType.impureSequence:
        return const Color(0xFF8DC5A2); // on-secondary-container
      case CardGroupType.set:
        return const Color(0xFFDAE4ED); // on-surface
      case CardGroupType.deadwood:
        return const Color(0xFFFFDAD6); // on-error-container
    }
  }

  Color _groupBgColor() {
    switch (group.type) {
      case CardGroupType.pureSequence:
        return const Color(0xFF33CA90); // tertiary-container
      case CardGroupType.impureSequence:
        return const Color(0xFF1C5338); // secondary-container
      case CardGroupType.set:
        return const Color(0xFF222B32); // surface-container-high
      case CardGroupType.deadwood:
        return const Color(0xFF93000A); // error-container
    }
  }

  String _formatGroupBadgeText() {
    switch (group.type) {
      case CardGroupType.pureSequence:
        return 'Pure Seq • 0 pts';
      case CardGroupType.impureSequence:
        return 'Impure • 0 pts';
      case CardGroupType.set:
        return 'Set • 0 pts';
      case CardGroupType.deadwood:
        return 'Deadwood • ${group.points} pts';
    }
  }

  IconData _groupIcon() {
    switch (group.type) {
      case CardGroupType.pureSequence:
        return Icons.verified;
      case CardGroupType.impureSequence:
        return Icons.check_circle_outline_rounded;
      case CardGroupType.set:
        return Icons.layers_outlined;
      case CardGroupType.deadwood:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _groupColor();

    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        if (details.data.fromGroupId == group.id) {
          onCardReordered?.call(details.data.cardIndex, group.cards.length - 1);
        } else {
          if (onCardDroppedAtIndex != null) {
            onCardDroppedAtIndex!(details.data.card, details.data.fromGroupId, group.cards.length);
          } else {
            onCardDropped?.call(details.data.card, details.data.fromGroupId);
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty && candidateData.any((d) => d?.fromGroupId != group.id);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAccepting || isHovered
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: isAccepting ? 2.0 : 1.0,
            ),
            color: isAccepting
                ? AppColors.accentSubtle
                : Colors.transparent,
          ),
          padding: const EdgeInsets.only(top: 2, left: 2, right: 2, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fanned cards
              _buildCardFan(),
              const SizedBox(height: 8.0),
              // Group label badge below cards matching HTML reference
              _buildGroupLabel(color),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupLabel(Color color) {
    if (group.isEmpty) return const SizedBox.shrink();
    final bgColor = _groupBgColor();
    final fanWidth = cardWidth + (group.cards.length - 1) * cardOverlap;

    return Container(
      constraints: BoxConstraints(maxWidth: fanWidth.clamp(50.0, double.infinity)),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 4,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _groupIcon(),
              size: 9,
              color: color,
            ),
            const SizedBox(width: 2.5),
            Text(
              _formatGroupBadgeText(),
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFan() {
    if (group.isEmpty) {
      return Container(
        width: cardWidth + 8,
        height: cardHeight + 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.white24, size: 20),
        ),
      );
    }

    final totalWidth = cardWidth + (group.cards.length - 1) * cardOverlap;

    return SizedBox(
      width: totalWidth,
      height: cardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(group.cards.length, (index) {
          final card = group.cards[index];
          final isWJ = JokerUtils.isWildJoker(card, wildJokerCard);
          final isSelected = selectedCard == card || selectedCards.contains(card);

          Widget cardWidget = CardWidget(
            card: card,
            isSelected: isSelected,
            isWildJoker: isWJ,
            width: cardWidth,
            height: cardHeight,
            onTap: () => onCardTap?.call(card),
          );

          // Wrap in Draggable carrying cardIndex
          cardWidget = Draggable<CardDragData>(
            data: CardDragData(
              card: card,
              fromGroupId: group.id,
              cardIndex: index,
            ),
            feedback: Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.08,
                child: CardWidget(
                  card: card,
                  isSelected: true,
                  isWildJoker: isWJ,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: cardWidget,
            ),
            onDragStarted: () {
              onCardDragStarted?.call(card, group.id);
            },
            child: cardWidget,
          );

          // Wrap individual card position in DragTarget to support intra-group reordering & precise insertion
          final targetSlot = DragTarget<CardDragData>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              if (details.data.fromGroupId == group.id) {
                // Intra-group reorder
                onCardReordered?.call(details.data.cardIndex, index);
              } else {
                // Move from another group into this exact index
                if (onCardDroppedAtIndex != null) {
                  onCardDroppedAtIndex!(details.data.card, details.data.fromGroupId, index);
                } else {
                  onCardDropped?.call(details.data.card, details.data.fromGroupId);
                }
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHoveredOnCard = candidateData.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isHoveredOnCard
                      ? Border.all(color: AppColors.accent, width: 2)
                      : null,
                ),
                child: cardWidget,
              );
            },
          );

          final int globalIndex = globalStartIndex + index;
          final double t = totalHandCards > 1
              ? (globalIndex - (totalHandCards - 1) / 2.0) / ((totalHandCards - 1) / 2.0)
              : 0.0;
          final double theta = t * 0.28; // Heavily skews outer cards to match the sweeping real-world layout angle
          final double dx = t * 6.0; // Drastically reduce horizontal displacement to pack roots tightly
          final double dy = (1.0 - (t * t).abs()) * -22.0; // Heighten center dome arch lift so cards sweep upward
          final double groupHeightDelta = (groupIndex % 2 == 1) ? -10.0 : 0.0; // Staggers alternate melds for easy tracking
          final double finalY = dy + groupHeightDelta;

          return Positioned(
            left: index * cardOverlap,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.translationValues(dx, finalY, 0.0)
                ..rotateZ(theta),
              child: targetSlot,
            ),
          );
        }),
      ),
    );
  }
}
