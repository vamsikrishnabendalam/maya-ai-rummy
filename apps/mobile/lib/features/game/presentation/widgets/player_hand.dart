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
    final cw = Responsive.cardWidth(context);
    final ch = Responsive.cardHeight(context);
    final overlap = Responsive.cardOverlap(context);
    final spacing = Responsive.groupSpacing(context);

    return Container(
      constraints: BoxConstraints(
        minHeight: ch + 40,
        maxHeight: ch + 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Discard drop zone (appears during discard phase when dragging)
          if (isDiscardPhase) _buildDiscardZone(context),
          // Card groups in scrollable row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.tablePadding(context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildGroupsWithDividers(
                  cw, ch, overlap, spacing,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupsWithDividers(
    double cw,
    double ch,
    double overlap,
    double spacing,
  ) {
    final widgets = <Widget>[];

    for (var i = 0; i < cardGroups.length; i++) {
      if (i > 0) {
        // Gold divider between groups
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: Container(
              width: 2,
              height: ch * 0.6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.accent.withValues(alpha: 0.4),
                    AppColors.accent.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }

      widgets.add(
        CardGroupWidget(
          group: cardGroups[i],
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

    // "Add group" target at the end
    widgets.add(
      Padding(
        padding: EdgeInsets.only(left: spacing),
        child: _buildAddGroupTarget(cw, ch),
      ),
    );

    return widgets;
  }

  Widget _buildAddGroupTarget(double cw, double ch) {
    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        onCardMovedToNewGroup?.call(details.data.card, details.data.fromGroupId);
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: cw * 0.7,
          height: ch,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAccepting
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: isAccepting ? 2 : 1,
            ),
            color: isAccepting ? AppColors.accentSubtle : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 18,
                color: isAccepting
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 2),
              Text(
                'New\nGroup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  color: isAccepting
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.15),
                ),
              ),
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
          height: isAccepting ? 36 : 24,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isAccepting
                ? AppColors.danger.withValues(alpha: 0.2)
                : Colors.transparent,
            border: isAccepting
                ? Border.all(color: AppColors.danger.withValues(alpha: 0.5))
                : null,
          ),
          child: Center(
            child: Text(
              isAccepting ? '↑ Drop here to discard ↑' : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      },
    );
  }
}
