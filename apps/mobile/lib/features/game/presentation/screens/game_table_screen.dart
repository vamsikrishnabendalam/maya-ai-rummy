import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_ui_provider.dart';
import '../widgets/game_table_background.dart';
import '../widgets/opponent_panel.dart';
import '../widgets/center_table.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/action_bar.dart';
import '../widgets/player_hand.dart';
import '../widgets/score_bottom_left.dart';
import '../widgets/group_suggestions_modal.dart';
import '../widgets/declaration_result_modal.dart';
import '../widgets/score_card_modal.dart';
import '../widgets/game_settings_modal.dart';
import '../widgets/card_animation_layer.dart';

/// The main game table screen — assembles all gameplay, manual discard,
/// grouping suggestions, declaration, settings, and tournament scorecard.
class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableState = ref.watch(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    final gameState = tableState.gameState;
    final cardGroups = tableState.cardGroups;
    final isHumanTurn = notifier.isHumanTurn;
    final isDrawPhase = notifier.isDrawPhase;
    final isDiscardPhase = notifier.isDiscardPhase;
    final isGameComplete = notifier.isGameComplete;
    final aiPlayer = notifier.aiPlayer;
    final wildJoker = notifier.wildJokerCard;

    return Scaffold(
      body: GameTableBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
              // --- Top Navigation Bar (Branding, Pool Mode, Scorecard, Settings) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 14),
                            SizedBox(width: 4),
                            Text('Home', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const Text(
                      'MAYA RUMMY',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${tableState.gameSettings.eliminationScore} POOL',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Score Card Button
                    InkWell(
                      onTap: () => _openScoreCard(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_chart_outlined, color: AppColors.accent, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Scorecard',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Settings Button
                    InkWell(
                      onTap: () => _openSettings(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Settings',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Opponent Panel (Top) ---
              OpponentPanel(
                opponent: aiPlayer,
                isThinking: !isHumanTurn && !isGameComplete,
                difficultyLabel: tableState.aiDifficultyLabel,
                isDealer: tableState.isAiDealer,
              ),

              // --- Center Table (Closed Deck, Open Joker, Open Pile) ---
              Expanded(
                child: Center(
                  child: CenterTable(
                    closedDeckCount: gameState.closedDeck.length,
                    openPile: gameState.openPile,
                    wildJoker: wildJoker,
                    canDraw: isHumanTurn && isDrawPhase,
                    onDrawClosed: () => notifier.drawFromClosedDeck(),
                    onDrawOpen: () => notifier.drawFromOpenDeck(),
                  ),
                ),
              ),

              // --- Bottom-Left Score & Turn Guidance Banner ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ScoreBottomLeft(
                      handScore: tableState.currentScore,
                      totalGameScore: tableState.totalHumanScore,
                      roundNumber: tableState.currentRoundNumber,
                      opponentTotalScore: tableState.totalAiScore,
                      targetScore: tableState.gameSettings.eliminationScore,
                      isDealer: tableState.isHumanDealer,
                      onTapScoreCard: () => _openScoreCard(context, ref),
                    ),
                    const Spacer(),
                    TurnIndicator(
                      isHumanTurn: isHumanTurn,
                      isDrawPhase: isDrawPhase,
                      isDiscardPhase: isDiscardPhase,
                      isGameComplete: isGameComplete,
                      hasSelectedCard: tableState.selectedCard != null,
                      isAwaitingDeclarationShow: tableState.isAwaitingHumanDeclarationShow,
                      turnNumber: gameState.turnNumber,
                    ),
                  ],
                ),
              ),

              // --- Action Bar (Sort, Group, Discard, Discard & Declare, Drop, New, Submit Show) ---
              ActionBar(
                onSort: () => notifier.autoSortHand(),
                onAutoGroup: () => _openGroupSuggestions(context, ref),
                onDiscard: () => notifier.discardSelectedCard(),
                canDiscard: notifier.canDiscard,
                onDiscardAndDeclare: () => _handleDiscardAndDeclare(context, ref),
                canDiscardAndDeclare: notifier.canDiscardAndDeclare,
                isDeclarationWinning: notifier.remainingCardsFormValidDeclaration,
                onDrop: () => _handleDrop(context, ref),
                canDrop: isHumanTurn && !isGameComplete && !tableState.isAwaitingHumanDeclarationShow,
                onNewGame: () => notifier.startNewGame(),
                isAwaitingDeclarationShow: tableState.isAwaitingHumanDeclarationShow,
                currentDeclarationScore: tableState.currentScore,
                onAutoArrange: () => notifier.autoGroupHand(),
                onSubmitShow: () => _handleSubmitDeclarationShow(context, ref),
              ),

              const SizedBox(height: 4),

              // --- Player Hand with Groups & Selection ---
              PlayerHand(
                cardGroups: cardGroups,
                wildJokerCard: wildJoker,
                selectedCard: tableState.selectedCard,
                isDiscardPhase: isHumanTurn && isDiscardPhase,
                onCardTap: (card) {
                  notifier.selectCard(card);
                },
                onCardMoved: (card, fromGroupId, toGroupId) {
                  notifier.moveCardBetweenGroups(
                    card,
                    fromGroupId,
                    toGroupId,
                    cardGroups
                        .firstWhere(
                          (g) => g.id == toGroupId,
                          orElse: () => cardGroups.first,
                        )
                        .cards
                        .length,
                  );
                },
                onCardMovedToIndex: (card, fromGroupId, toGroupId, insertIndex) {
                  notifier.moveCardBetweenGroups(
                    card,
                    fromGroupId,
                    toGroupId,
                    insertIndex,
                  );
                },
                onCardReordered: (groupId, oldIndex, newIndex) {
                  notifier.moveCardWithinGroup(
                    groupId,
                    oldIndex,
                    newIndex,
                  );
                },
                onCardMovedToNewGroup: (card, fromGroupId) {
                  notifier.moveCardToNewGroup(card, fromGroupId);
                },
                onCardDragStarted: (card, groupId) {
                  ref.read(gameUIProvider.notifier).startDrag(card, groupId);
                },
                onDragEnded: () {
                  ref.read(gameUIProvider.notifier).endDrag();
                },
                onDiscard: (card) {
                  if (isHumanTurn && isDiscardPhase) {
                    notifier.discardCard(card);
                  }
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
        const Positioned.fill(
          child: CardAnimationLayer(),
        ),
      ],
    ),
  ),
);
  }

  void _openGroupSuggestions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameTableProvider.notifier);
    final openJoker = notifier.wildJokerCard;
    final suggestions = notifier.getGroupSuggestions();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return GroupSuggestionsModal(
          suggestions: suggestions,
          openJoker: openJoker,
          onApplyBestGrouping: () {
            Navigator.of(ctx).pop();
            notifier.autoGroupHand();
          },
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  void _openScoreCard(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) {
        return ScoreCardModal(
          roundScores: tableState.roundScores,
          totalHumanScore: tableState.totalHumanScore,
          totalAiScore: tableState.totalAiScore,
          eliminationScore: tableState.gameSettings.eliminationScore,
          isHumanEliminated: tableState.isHumanEliminated,
          isAiEliminated: tableState.isAiEliminated,
          onClose: () => Navigator.of(ctx).pop(),
          onResetTournament: () {
            Navigator.of(ctx).pop();
            notifier.resetTournament();
          },
        );
      },
    );
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) {
        return GameSettingsModal(
          currentSettings: tableState.gameSettings,
          onSave: (newSettings) {
            notifier.updateSettings(newSettings);
          },
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  void _handleDiscardAndDeclare(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameTableProvider.notifier);
    final openJoker = notifier.wildJokerCard;
    final result = notifier.discardAndDeclareSelectedCard();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return DeclarationResultModal(
          result: result,
          openJoker: openJoker,
          onDismiss: () {
            Navigator.of(ctx).pop();
            _checkTournamentStatus(context, ref);
          },
          onNewGame: () {
            Navigator.of(ctx).pop();
            _checkTournamentStatus(context, ref);
          },
        );
      },
    );
  }

  void _handleSubmitDeclarationShow(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameTableProvider.notifier);
    final tableState = ref.read(gameTableProvider);
    final currentDeadwood = tableState.currentScore;

    // Check if an even lower optimal score exists with HandPartitioner
    final allCards = notifier.allGroupedCards();
    final optimalPartition = HandPartitioner.findBestPartition(allCards, notifier.wildJokerCard);
    final optimalDeadwood = optimalPartition.penaltyScore;

    void executeSubmit() {
      notifier.submitHumanDeclarationShow();
      final updatedState = ref.read(gameTableProvider);
      final humanScore = updatedState.currentScore;
      final isBotWinner = (updatedState.roundScores.isNotEmpty && updatedState.roundScores.last.aiScore == 0);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141E18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            title: Row(
              children: [
                Icon(
                  isBotWinner ? Icons.emoji_events : Icons.celebration,
                  color: isBotWinner ? AppColors.accent : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  isBotWinner ? 'Round Complete' : 'Won by Default!',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBotWinner
                      ? 'Maya Bot declared a valid show (0 pts).\n\nYour submitted hand count is $humanScore pts.'
                      : 'Maya Bot made an invalid show!\nYou win the round with 0 pts!',
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Total: ${updatedState.totalHumanScore} pts', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Bot Total: ${updatedState.totalAiScore} pts', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openScoreCard(context, ref);
                },
                child: const Text('Scorecard', style: TextStyle(color: AppColors.accent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _checkTournamentStatus(context, ref);
                },
                child: const Text('Next Deal', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }

    if (optimalDeadwood < currentDeadwood) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141E18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.accent, size: 24),
              SizedBox(width: 8),
              Text('Lower Score Available!', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your current arrangement has $currentDeadwood PTS.\n\n'
            'Auto-Arrange can reorganize your sequences and jokers to achieve $optimalDeadwood PTS (saves ${currentDeadwood - optimalDeadwood} pts)!',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                executeSubmit();
              },
              child: Text(
                'Keep $currentDeadwood PTS',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.autoGroupHand();
                executeSubmit();
              },
              child: Text(
                'Auto-Arrange to $optimalDeadwood PTS & Submit',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      executeSubmit();
    }
  }

  void _handleDrop(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameTableProvider.notifier);
    final tableState = ref.read(gameTableProvider);
    final isFirstDrop = tableState.gameState.turnNumber <= 1 && !tableState.hasDrawnThisTurn;
    final penalty = isFirstDrop
        ? tableState.gameSettings.firstDropPenalty
        : tableState.gameSettings.middleDropPenalty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141E18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Drop Current Hand?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'You will drop this hand and receive $penalty penalty points (${isFirstDrop ? "First Drop" : "Middle Drop"}).',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(ctx).pop();
                notifier.dropCurrentHand();
                _checkTournamentStatus(context, ref);
              },
              child: const Text('Confirm Drop', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _checkTournamentStatus(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    if (tableState.isHumanEliminated || tableState.isAiEliminated) {
      final isHumanWinner = tableState.isAiEliminated && !tableState.isHumanEliminated;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141E18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isHumanWinner ? '🏆 VICTORY!' : '💀 ELIMINATED',
              style: TextStyle(
                color: isHumanWinner ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              isHumanWinner
                  ? 'Congratulations! AI Bot reached ${tableState.totalAiScore} points and is eliminated! You won the tournament with ${tableState.totalHumanScore} points!'
                  : 'You reached ${tableState.totalHumanScore} points (limit ${tableState.gameSettings.eliminationScore}) and have been eliminated.',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openScoreCard(context, ref);
                },
                child: const Text('View Scorecard', style: TextStyle(color: AppColors.accent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  notifier.resetTournament();
                },
                child: const Text('New Tournament', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } else {
      notifier.startNextRound();
    }
  }
}
