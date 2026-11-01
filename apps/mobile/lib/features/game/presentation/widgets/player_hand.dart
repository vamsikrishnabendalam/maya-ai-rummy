import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../models/card_group.dart';
import 'card_group_widget.dart';

/// The player's hand area — shows card groups with drag-and-drop support.
/// Cards are organized into groups (sequences, sets, deadwood) separated
/// by gold dividers, scrollable horizontally.
class PlayerHand extends StatelessWidget {
  final List<CardGroup> cardGroups;
  final Card? wildJokerCard;
  final Card? selectedCard;
  final Set<Card> selectedCards;
  final bool isDiscardPhase;
  final ValueChanged<Card>? onCardTap;
  final void Function(Card card, String fromGroupId, String toGroupId)?
      onCardMoved;
  final void Function(Card card, String fromGroupId, String toGroupId, int insertIndex)?
      onCardMovedToIndex;
  final void Function(String groupId, int oldIndex, int newIndex)? onCardReordered;
  final void Function(Card card, String fromGroupId)? onCardMovedToNewGroup;
  final void Function(Card card, String groupId)? onCardDragStarted;
  final VoidCallback? onDragEnded;
  final void Function(Card card)? onDiscard;

  const PlayerHand({
    Key? key,
    required this.cardGroups,
    this.wildJokerCard,
    this.selectedCard,
    this.selectedCards = const {},
    this.isDiscardPhase = false,
    this.onCardTap,
    this.onCardMoved,
    this.onCardMovedToIndex,
    this.onCardReordered,
    this.onCardMovedToNewGroup,
    this.onCardDragStarted,
    this.onDragEnded,
    this.onDiscard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalCards = cardGroups.fold<int>(0, (sum, g) => sum + g.cards.length);
        final groupCount = cardGroups.length;

        // Is compact mode (only when very narrow portrait container < 480)
        final isCompact = availableWidth < 480;

        // Base metrics
        double cw = isCompact ? 46.0 : Responsive.cardWidth(context);
        double overlap = isCompact ? 24.0 : Responsive.cardOverlap(context);
        double spacing = isCompact ? 8.0 : Responsive.groupSpacing(context);

        if (groupCount > 0 && totalCards > 0) {
          final horizontalPadding = isCompact ? 6.0 : 16.0;
          final availableForRack = availableWidth - (horizontalPadding * 2);
          final gapsCount = groupCount - 1;
          final spacingNeeded = gapsCount * spacing;
          final availableForCards = availableForRack - spacingNeeded;

          final nonFirstCards = (totalCards - groupCount).clamp(0, 99);
          final requiredWidth = (groupCount * cw) + (nonFirstCards * overlap);

          if (requiredWidth > availableForCards && availableForCards > 60) {
            // First adjust overlap so cards stay large and readable
            if (nonFirstCards > 0) {
              final neededForCw = groupCount * cw;
              if (availableForCards > neededForCw + (nonFirstCards * 20.0)) {
                overlap = ((availableForCards - neededForCw) / nonFirstCards).clamp(20.0, 48.0);
              } else {
                // Scale cw gently only if even minimum overlap overflows
                final scale = (availableForCards / (neededForCw + nonFirstCards * 20.0)).clamp(0.72, 1.0);
                cw = (cw * scale).clamp(56.0, Responsive.cardWidth(context));
                overlap = (20.0 * scale).clamp(18.0, 38.0);
              }
            } else {
              cw = (availableForCards / groupCount).clamp(56.0, Responsive.cardWidth(context));
            }
          }
        }

        final ch = cw * 1.45;

        return Container(
          clipBehavior: Clip.none,
          constraints: BoxConstraints(
            minHeight: ch + (isCompact ? 20 : 26),
            maxHeight: ch + (isCompact ? 28 : 34),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Discard drop zone (appears during discard phase when dragging)
              if (isDiscardPhase) _buildDiscardZone(context),
              // Card groups centered and auto-fitted in one go
              SingleChildScrollView(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 4.0 : Responsive.tablePadding(context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _buildGroupsWithDividers(
                    cw, ch, overlap, spacing, isCompact, totalCards,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupsWithDividers(
    double cw,
    double ch,
    double overlap,
    double spacing,
    bool isCompact,
    int totalCards,
  ) {
    final widgets = <Widget>[];
    int cardOffset = 0;

    for (var i = 0; i < cardGroups.length; i++) {
      final startIdx = cardOffset;
      cardOffset += cardGroups[i].cards.length;

      if (i > 0) {
        widgets.add(SizedBox(width: spacing));
      }

      widgets.add(
        CardGroupWidget(
          group: cardGroups[i],
          groupIndex: i,
          globalStartIndex: startIdx,
          totalHandCards: totalCards,
          wildJokerCard: wildJokerCard,
          cardWidth: cw,
          cardHeight: ch,
          cardOverlap: overlap,
          selectedCard: selectedCard,
          selectedCards: selectedCards,
          onCardTap: onCardTap,
          onCardDropped: (card, fromGroupId) {
            onCardMoved?.call(card, fromGroupId, cardGroups[i].id);
          },
          onCardDroppedAtIndex: (card, fromGroupId, targetIndex) {
            if (onCardMovedToIndex != null) {
              onCardMovedToIndex!(card, fromGroupId, cardGroups[i].id, targetIndex);
            } else {
              onCardMoved?.call(card, fromGroupId, cardGroups[i].id);
            }
          },
          onCardReordered: (oldIndex, newIndex) {
            onCardReordered?.call(cardGroups[i].id, oldIndex, newIndex);
          },
          onCardDragStarted: onCardDragStarted,
        ),
      );
    }

    return widgets;
  }

  Widget _buildDiscardZone(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        if (details.data is CardDragData) {
          onDiscard?.call((details.data as CardDragData).card);
        } else if (details.data is Card) {
          onDiscard?.call(details.data as Card);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isAccepting ? 32 : 0,
          margin: EdgeInsets.only(bottom: isAccepting ? 4 : 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isAccepting
                ? AppColors.danger.withValues(alpha: 0.2)
                : Colors.transparent,
            border: isAccepting
                ? Border.all(color: AppColors.danger.withValues(alpha: 0.5))
                : null,
          ),
          child: isAccepting
              ? Center(
                  child: Text(
                    '↑ Drop here to discard ↑',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger.withValues(alpha: 0.8),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
