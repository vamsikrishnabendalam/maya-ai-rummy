import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/card_group.dart';
import 'card_widget.dart';

/// Renders a single group of cards with a type label and fan layout.
/// Accepts dropped cards from other groups and supports intra-group reordering.
class CardGroupWidget extends StatelessWidget {
  final CardGroup group;
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
        return AppColors.groupPure;
      case CardGroupType.impureSequence:
        return AppColors.groupImpure;
      case CardGroupType.set:
        return AppColors.groupSet;
      case CardGroupType.deadwood:
        return AppColors.groupDeadwood;
    }
  }

  IconData _groupIcon() {
    switch (group.type) {
      case CardGroupType.pureSequence:
      case CardGroupType.impureSequence:
      case CardGroupType.set:
        return Icons.check_circle;
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
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: isAccepting ? 2.0 : 1.0,
            ),
            color: isAccepting
                ? AppColors.accentSubtle
                : Colors.transparent,
          ),
          padding: const EdgeInsets.only(top: 2, left: 4, right: 4, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group label pill
              _buildGroupLabel(color),
              const SizedBox(height: 4),
              // Fanned cards
              _buildCardFan(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupLabel(Color color) {
    if (group.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _groupIcon(),
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            group.label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
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

          return Positioned(
            left: index * cardOverlap,
            child: targetSlot,
          );
        }),
      ),
    );
  }
}
