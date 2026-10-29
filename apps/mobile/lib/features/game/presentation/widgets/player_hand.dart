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

        // Auto-fit calculation to make all cards visible in one go
        final showAddGroupTarget = availableWidth >= 280;
        final addGroupWidth = showAddGroupTarget ? (isCompact ? 24.0 : cw * 0.7) : 0.0;

        if (groupCount > 0 && totalCards > 0) {
          final horizontalPadding = isCompact ? 6.0 : 16.0;
          final availableForRack = availableWidth - (horizontalPadding * 2);
          final gapsCount = groupCount - 1;
          final spacingNeeded = (gapsCount * spacing) + (showAddGroupTarget ? spacing + addGroupWidth : 0.0);
          final availableForCards = availableForRack - spacingNeeded;

          final nonFirstCards = (totalCards - groupCount).clamp(0, 99);
          final requiredWidth = (groupCount * cw) + (nonFirstCards * overlap);

          if (requiredWidth > availableForCards && availableForCards > 60) {
            // Compress cards smoothly to fit in one go!
            if (isCompact) {
              cw = (availableForCards * 0.38 / groupCount).clamp(38.0, 48.0);
            } else {
              cw = (availableForCards * 0.35 / groupCount).clamp(48.0, 82.0);
            }
            final remainingForOverlap = availableForCards - (groupCount * cw);
            if (nonFirstCards > 0) {
              overlap = (remainingForOverlap / nonFirstCards).clamp(16.0, isCompact ? 24.0 : 40.0);
            }
          }
        }

        final ch = cw * 1.45;

        return Container(
          clipBehavior: Clip.none,
          constraints: BoxConstraints(
            minHeight: ch + (isCompact ? 56 : 78),
            maxHeight: ch + (isCompact ? 76 : 96),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Discard drop zone (appears during discard phase when dragging)
              if (isDiscardPhase) _buildDiscardZone(context),
              // Card groups centered and auto-fitted in one go
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
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
                        cw, ch, overlap, spacing, showAddGroupTarget, isCompact, totalCards,
                      ),
                    ),
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
    bool showAddGroupTarget,
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

    // "Add group" target at the end — wrapped in zero-width box so the card fan centers perfectly on table center axis
    if (showAddGroupTarget) {
      final targetWidth = isCompact ? 24.0 : cw * 0.7;
      widgets.add(
        SizedBox(
          width: 0,
          child: OverflowBox(
            alignment: Alignment.bottomLeft,
            minWidth: 0,
            maxWidth: targetWidth + spacing * 2,
            child: Padding(
              padding: EdgeInsets.only(left: spacing),
              child: _buildAddGroupTarget(cw, ch, isCompact),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildAddGroupTarget(double cw, double ch, bool isCompact) {
    final targetWidth = isCompact ? 24.0 : cw * 0.7;
    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        onCardMovedToNewGroup?.call(details.data.card, details.data.fromGroupId);
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: targetWidth,
          height: ch,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAccepting
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.12),
              width: isAccepting ? 2 : 1,
            ),
            color: isAccepting ? AppColors.accentSubtle : Colors.white.withValues(alpha: 0.03),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: isCompact ? 15 : 18,
                color: isAccepting
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.35),
              ),
              if (!isCompact) ...[
                const SizedBox(height: 2),
                Text(
                  'New\nGroup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: isAccepting
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
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
