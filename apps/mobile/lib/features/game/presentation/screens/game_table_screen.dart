import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:game_engine/game_engine.dart';

import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../auth/providers/auth_provider.dart';

import '../../../home/providers/home_provider.dart';

import '../../models/card_group.dart';

import '../../providers/game_provider.dart';

import '../../providers/game_ui_provider.dart';

import '../widgets/game_table_background.dart';

import '../widgets/opponent_panel.dart';

import '../widgets/card_widget.dart';

import '../widgets/card_back_widget.dart';

import '../widgets/discard_history_modal.dart';

import '../widgets/player_hand.dart';

import '../widgets/declaration_result_modal.dart';

import '../widgets/opponent_declaration_modal.dart';

import '../widgets/score_card_modal.dart';

import '../widgets/game_settings_modal.dart';

import '../widgets/game_logs_modal.dart';

import '../widgets/card_animation_layer.dart';

import '../widgets/royal_life_checklist_bar.dart';

import '../widgets/secret_joker_reveal_overlay.dart';

import '../../../../core/utils/responsive.dart';

/// The main game table screen — assembles all gameplay, manual discard,

/// grouping suggestions, declaration, settings, and tournament scorecard

/// with full Mobile Landscape and Portrait responsive support.

class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({Key? key}) : super(key: key);

  static String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _computeToastMessage({
    required bool isHumanTurn,
    required bool isDrawPhase,
    required bool isDiscardPhase,
    required bool isGameComplete,
    required bool hasSelectedCard,
    required bool isAwaitingDeclarationShow,
    required bool isWinningDeclaration,
    required bool isTournamentOver,
    int? currentRound,
  }) {
    if (isGameComplete) {
      if (isTournamentOver) {
        return 'Tournament completed! Tap New Tournament to play again.';
      }

      return 'Round ${currentRound ?? ''} completed! Tap Next Deal below to continue.';
    }

    if (isAwaitingDeclarationShow) {
      return 'Maya Bot declared show! Tap to view melds. Arrange & Declare your final hand.';
    }

    if (!isHumanTurn) return 'Maya Bot is thinking...';

    if (isDrawPhase) return 'Your Turn! Tap Closed Deck or Open Pile to draw.';

    if (isDiscardPhase) {
      if (hasSelectedCard) {
        if (isWinningDeclaration) {
          return 'Valid Show (0 Pts)! Tap Declare to win!';
        }

        return 'Card selected! Tap Discard or drop in Finish Slot.';
      }

      return 'Drew 14th card! Select 1 card to Discard or Declare.';
    }

    return 'Play your hand!';
  }

  Widget _buildToastPill(String message,
      {VoidCallback? onTap, bool isDesktop = false}) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 14 : 10,
        vertical: isDesktop ? 5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              color: const Color(0xFFFBBF24), size: isDesktop ? 14 : 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFDE68A),
                fontSize: isDesktop ? 12.0 : 10.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: pill,
      );
    }

    return pill;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<GameTableState>(gameTableProvider, (previous, next) {
      if (next.isAwaitingHumanDeclarationShow &&
          (previous == null || !previous.isAwaitingHumanDeclarationShow)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOpponentDeclarationModal(context, ref);
        });
      }
    });

    final tableState = ref.watch(gameTableProvider);

    final notifier = ref.read(gameTableProvider.notifier);
    final uiState = ref.watch(gameUIProvider);

    final gameState = tableState.gameState;

    final cardGroups = tableState.cardGroups;

    final isHumanTurn = notifier.isHumanTurn;

    final isDrawPhase = notifier.isDrawPhase;

    final isDiscardPhase = notifier.isDiscardPhase;

    final isGameComplete = notifier.isGameComplete;

    final aiPlayer = notifier.aiPlayer;

    final wildJoker = notifier.wildJokerCard;

    final isFirstDrop =
        gameState.turnNumber <= 1 && !tableState.hasDrawnThisTurn;

    final dropPenalty = isFirstDrop
        ? tableState.gameSettings.firstDropPenalty
        : tableState.gameSettings.middleDropPenalty;

    final canDrop = isHumanTurn &&
        !isGameComplete &&
        !tableState.isAwaitingHumanDeclarationShow;

    final canDiscard = notifier.canDiscard;

    final canDeclare = notifier.canDiscardAndDeclare ||
        tableState.isAwaitingHumanDeclarationShow;

    final size = MediaQuery.of(context).size;

    final isLandscape = size.width > size.height;

    final isDesktop = Responsive.isDesktop(context);

    final isTablet = Responsive.isTablet(context);

    final isMobileLandscape = Responsive.isMobileLandscape(context);

    final isTournamentOver =
        tableState.isHumanEliminated || tableState.isAiEliminated;

    final toastMessage = _computeToastMessage(
      isHumanTurn: isHumanTurn,
      isDrawPhase: isDrawPhase,
      isDiscardPhase: isDiscardPhase,
      isGameComplete: isGameComplete,
      hasSelectedCard: tableState.selectedCard != null,
      isAwaitingDeclarationShow: tableState.isAwaitingHumanDeclarationShow,
      isWinningDeclaration: notifier.remainingCardsFormValidDeclaration,
      isTournamentOver: isTournamentOver,
      currentRound: tableState.roundScores.length,
    );

    final nextDealNumber = tableState.roundScores.length + 1;

    final isPortrait = !isLandscape;

    // Virtual Design Canvas (1754 x 896 native reference space)

    final mayaAiCanvas = Center(
      child: AspectRatio(
        aspectRatio: 1754 / 896,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1754,
            height: 896,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // -------------------------------------------------------------

                // -------------------------------------------------------------
                // 1. LAYER 1: 3D PERSPECTIVE WARPED TABLE SURFACE (THE FLAT CARDS)
                // -------------------------------------------------------------
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(-1.15)
                        ..translate(0.0, 200.0),
                      child: SizedBox(
                        width: 1754,
                        height: 896,
                        child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 395,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Closed Deck Stack with Perpendicular Wild Joker Tucked Underneath
                                  _buildPerspectiveClosedDeckWithTuckedJoker(
                                    context: context,
                                    count: gameState.closedDeck.length,
                                    wildJoker: wildJoker,
                                    isClosedJoker:
                                        tableState.gameSettings.isClosedJoker,
                                    isJokerOpened:
                                        tableState.gameSettings.jokerMode ==
                                                'OPEN' ||
                                            tableState.hasHumanOpenedJoker,
                                    hasLife: notifier.hasHumanLife,
                                    onOpenClosedJoker: () =>
                                        notifier.openClosedJoker(),
                                    canDraw: isHumanTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromClosedDeck(),
                                  ),

                                  const SizedBox(width: 32),

                                  // 2. Open Discard Pile (Showing up to 5 overlapping cards + Drag & Drop Discard Target)
                                  _buildPerspectiveOpenPile(
                                    context: context,
                                    discardPile: gameState.openPile,
                                    wildJoker: notifier.effectiveHumanWildJoker,
                                    canDraw: isHumanTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromOpenDeck(),
                                    canDiscard: isHumanTurn && isDiscardPhase,
                                    onDiscardCard: (card) =>
                                        notifier.discardCard(card),
                                    onShowHistory: () {
                                      if (gameState.openPile.isNotEmpty) {
                                        DiscardHistoryModal.show(
                                          context,
                                          discardPile: gameState.openPile,
                                          wildJoker:
                                              notifier.effectiveHumanWildJoker,
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(width: 32),

                                  // 3. Finish / Declare Slot
                                  _buildPerspectiveFinishSlot(
                                    context: context,
                                    isActivated: canDeclare ||
                                        (isHumanTurn &&
                                            isDiscardPhase &&
                                            uiState.isDragging),
                                    canAcceptDrop: (isHumanTurn &&
                                            isDiscardPhase &&
                                            !tableState.isRoundOver) ||
                                        tableState
                                            .isAwaitingHumanDeclarationShow,
                                    canDeclare: canDeclare,
                                    onDeclare: canDeclare
                                        ? () {
                                            if (tableState
                                                .isAwaitingHumanDeclarationShow) {
                                              _handleSubmitDeclarationShow(
                                                  context, ref);
                                            } else {
                                              _handleDiscardAndDeclare(
                                                  context, ref);
                                            }
                                          }
                                        : null,
                                    onCardDeclared: ((isHumanTurn &&
                                                isDiscardPhase &&
                                                !tableState.isRoundOver) ||
                                            tableState
                                                .isAwaitingHumanDeclarationShow)
                                        ? (card) {
                                            if (tableState
                                                .isAwaitingHumanDeclarationShow) {
                                              _handleSubmitDeclarationShow(
                                                  context, ref);
                                            } else {
                                              _handleDiscardAndDeclare(
                                                  context, ref,
                                                  finishCard: card);
                                            }
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

                // Maya AI Host Floating Status Pill
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: InkWell(
                      onTap: tableState.isAwaitingHumanDeclarationShow
                          ? () => _showOpponentDeclarationModal(context, ref)
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      child: OpponentPanel(
                        opponent: aiPlayer,
                        isThinking: !isHumanTurn && !isGameComplete,
                        difficultyLabel: tableState.aiDifficultyLabel,
                        isDealer: tableState.isAiDealer,
                        scoreText: null,
                        isHostOverlay: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isMobileLandscape) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: GameTableBackground(
          child: _buildMobileLandscapeLayout(
            context,
            ref,
            tableState: tableState,
            notifier: notifier,
            toastMessage: toastMessage,
            isHumanTurn: isHumanTurn,
            isDrawPhase: isDrawPhase,
            isDiscardPhase: isDiscardPhase,
            isGameComplete: isGameComplete,
            isTournamentOver: isTournamentOver,
            wildJoker: wildJoker,
            canDrop: canDrop,
            dropPenalty: dropPenalty,
            canDiscard: canDiscard,
            canDeclare: canDeclare,
            cardGroups: cardGroups,
            nextDealNumber: nextDealNumber,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameTableBackground(
        child: Stack(
          children: [
            // 1. Center 3D Table Surface & Maya
            Positioned.fill(
              child: mayaAiCanvas,
            ),

            // 2. Top HUD Navigation & Control Bar (Pinned to literal top: 0 of screen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHudBar(
                context,
                ref,
                tableState: tableState,
                notifier: notifier,
                toastMessage: toastMessage,
                isGameComplete: isGameComplete,
                isTournamentOver: isTournamentOver,
                wildJoker: wildJoker,
              ),
            ),

            // 3. Player 13-Card Hand Tray (Pinned to literal bottom: 2 of screen, leaving only a few pixels)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Center(
                child: SizedBox(
                  width: isDesktop
                      ? 1440
                      : (Responsive.isTablet(context) ? 1120 : 960),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        child: PlayerHand(
                          cardGroups: cardGroups,
                          wildJokerCard: notifier.effectiveHumanWildJoker,
                          selectedCard: tableState.selectedCard,
                          selectedCards: tableState.selectedCards,
                          isDiscardPhase: isHumanTurn && isDiscardPhase,
                          onCardTap: (card) => notifier.selectCard(card),
                          onCardMoved: (card, fromGroupId, toGroupId) {
                            notifier.moveCardBetweenGroups(
                              card,
                              fromGroupId,
                              toGroupId,
                              cardGroups
                                  .firstWhere((g) => g.id == toGroupId,
                                      orElse: () => cardGroups.first)
                                  .cards
                                  .length,
                            );
                          },
                          onCardMovedToIndex:
                              (card, fromGroupId, toGroupId, insertIndex) {
                            notifier.moveCardBetweenGroups(
                                card, fromGroupId, toGroupId, insertIndex);
                          },
                          onCardReordered: (groupId, oldIndex, newIndex) {
                            notifier.moveCardWithinGroup(
                                groupId, oldIndex, newIndex);
                          },
                          onCardMovedToNewGroup: (card, fromGroupId) {
                            notifier.moveCardToNewGroup(card, fromGroupId);
                          },
                          onCardDragStarted: (card, groupId) {
                            ref
                                .read(gameUIProvider.notifier)
                                .startDrag(card, groupId);
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
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: tableState.isAwaitingHumanDeclarationShow
                            ? () => _showOpponentDeclarationModal(context, ref)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: RoyalLifeChecklistBar(
                          hasFirstLife: notifier.hasHumanLife,
                          hasSecondLife: notifier.hasHumanSecondLife,
                          points: tableState.currentScore,
                          isMyTurn: isHumanTurn,
                          turnSeconds: tableState.turnSecondsRemaining,
                          instructionText: toastMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Left Action Controls: Drop (20), Sort Hand, AI Group
            Positioned(
              left: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildLeftThumbControls(
                context,
                ref,
                canDrop: canDrop,
                dropPenalty: dropPenalty,
                notifier: notifier,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),

            // 5. Right Action Controls: Group, Discard, Declare Hand
            Positioned(
              right: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildRightThumbControls(
                context,
                ref,
                notifier: notifier,
                tableState: tableState,
                uiState: uiState,
                canDiscard: canDiscard,
                canDeclare: canDeclare,
                isGameComplete: isGameComplete,
                isTournamentOver: isTournamentOver,
                nextDealNumber: nextDealNumber,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),

            // 6. Card Animation Layer (Deals & discards flight)
            const Positioned.fill(
              child: CardAnimationLayer(),
            ),

            if (uiState.showSecretJokerReveal &&
                uiState.secretJokerCard != null)
              Positioned.fill(
                child: SecretJokerRevealOverlay(
                  wildJoker: uiState.secretJokerCard!,
                  onDismiss: () => ref
                      .read(gameUIProvider.notifier)
                      .dismissSecretJokerReveal(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MOBILE LANDSCAPE RESPONSIVE LAYOUT (Calibrated from Visual Layout Studio)
  // Canonical Reference Canvas: 1024 x 491 with Proportional FittedBox Scaling
  // ===========================================================================

  Widget _buildMobileLandscapeLayout(
    BuildContext context,
    WidgetRef ref, {
    required GameTableState tableState,
    required GameTableNotifier notifier,
    required String toastMessage,
    required bool isHumanTurn,
    required bool isDrawPhase,
    required bool isDiscardPhase,
    required bool isGameComplete,
    required bool isTournamentOver,
    required Card? wildJoker,
    required bool canDrop,
    required int dropPenalty,
    required bool canDiscard,
    required bool canDeclare,
    required List<CardGroup> cardGroups,
    required int nextDealNumber,
  }) {
    final uiState = ref.watch(gameUIProvider);
    final gameState = tableState.gameState;
    final poolLabel = '${tableState.gameSettings.eliminationScore} POOL';

    return Center(
      child: AspectRatio(
        aspectRatio: 1024.0 / 491.0,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1024.0,
            height: 491.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Center Table Cards (Inside Table Circle Felt - Tilted 46 deg)
                Positioned(
                  left: 396,
                  top: 243,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016)
                      ..rotateX(-0.8028)
                      ..translate(0.0, 0.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Closed Deck Stack with Perpendicular Tucked Wild Joker
                        _buildMobilePerspectiveClosedDeck(
                          context: context,
                          count: gameState.closedDeck.length,
                          wildJoker: wildJoker,
                          isClosedJoker: tableState.gameSettings.isClosedJoker,
                          isJokerOpened: tableState.gameSettings.jokerMode == 'OPEN' || tableState.hasHumanOpenedJoker,
                          hasLife: notifier.hasHumanLife,
                          onOpenClosedJoker: () => notifier.openClosedJoker(),
                          canDraw: isHumanTurn && isDrawPhase,
                          onDraw: () => notifier.drawFromClosedDeck(),
                        ),
                        const SizedBox(width: 28),
                        // Open Discard Pile
                        _buildMobilePerspectiveOpenPile(
                          context: context,
                          discardPile: gameState.openPile,
                          wildJoker: notifier.effectiveHumanWildJoker,
                          canDraw: isHumanTurn && isDrawPhase,
                          onDraw: () => notifier.drawFromOpenDeck(),
                          canDiscard: isHumanTurn && isDiscardPhase,
                          onDiscardCard: (card) => notifier.discardCard(card),
                          onShowHistory: () {
                            if (gameState.openPile.isNotEmpty) {
                              DiscardHistoryModal.show(
                                context,
                                discardPile: gameState.openPile,
                                wildJoker: notifier.effectiveHumanWildJoker,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 28),
                        // Finish / Declare Slot
                        _buildMobilePerspectiveFinishSlot(
                          context: context,
                          isActivated: canDeclare || (isHumanTurn && isDiscardPhase && uiState.isDragging),
                          canAcceptDrop: (isHumanTurn && isDiscardPhase && !tableState.isRoundOver) ||
                              tableState.isAwaitingHumanDeclarationShow,
                          canDeclare: canDeclare,
                          onDeclare: canDeclare
                              ? () {
                                  if (tableState.isAwaitingHumanDeclarationShow) {
                                    _handleSubmitDeclarationShow(context, ref);
                                  } else {
                                    _handleDiscardAndDeclare(context, ref);
                                  }
                                }
                              : null,
                          onCardDeclared: ((isHumanTurn && isDiscardPhase && !tableState.isRoundOver) ||
                                  tableState.isAwaitingHumanDeclarationShow)
                              ? (card) {
                                  if (tableState.isAwaitingHumanDeclarationShow) {
                                    _handleSubmitDeclarationShow(context, ref);
                                  } else {
                                    _handleDiscardAndDeclare(context, ref, finishCard: card);
                                  }
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Top-Left Brand Pod
                Positioned(
                  left: 7,
                  top: 9,
                  width: 156,
                  height: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF210192A), Color(0xF7090F1A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x99D4AF37), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MAYA AI RUMMY',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0x33F2CA50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x88F2CA50), width: 1),
                            ),
                            child: Text(
                              poolLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF2CA50),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Left Status Pod (Turn countdown timer, 1st Life, 2nd Life, Deadwood)
                Positioned(
                  left: 6,
                  top: 56,
                  width: 156,
                  height: 58,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF20E1624), Color(0xF7080E18)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66D4AF37), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHumanTurn ? 'YOUR TURN' : 'MAYA TURN',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isHumanTurn ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x26F59E0B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '⏱️ ${tableState.turnSecondsRemaining}s',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    notifier.hasHumanLife ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 11,
                                    color: notifier.hasHumanLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '1st Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: notifier.hasHumanLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Icon(
                                    notifier.hasHumanSecondLife ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 11,
                                    color: notifier.hasHumanSecondLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '2nd Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: notifier.hasHumanSecondLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'DEADWOOD: ${tableState.currentScore} PTS',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: tableState.currentScore == 0 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Center Toast Banner
                Positioned(
                  left: 334,
                  top: 12,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF00E1828), Color(0xF016263E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x99F2CA50), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF2CA50), size: 13),
                        const SizedBox(width: 6),
                        Text(
                          toastMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFFBEB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Maya Host Badge
                Positioned(
                  left: 449,
                  top: 48,
                  child: InkWell(
                    onTap: tableState.isAwaitingHumanDeclarationShow
                        ? () => _showOpponentDeclarationModal(context, ref)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xE01E1030), Color(0xE010081C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x80D4AF37), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 15,
                            height: 15,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)]),
                            ),
                            alignment: Alignment.center,
                            child: const Text('D', style: TextStyle(color: Color(0xFF1A1200), fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Maya (AI Host)',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 6. Top Right: Declare Hand / Next Deal Button
                Positioned(
                  left: 808,
                  top: 10,
                  width: 129,
                  height: 30,
                  child: isGameComplete
                      ? InkWell(
                          onTap: () {
                            if (isTournamentOver) {
                              notifier.resetTournament();
                            } else {
                              _checkTournamentStatus(context, ref);
                            }
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF2CA50), Color(0xFFD4AF37), Color(0xFFAA771C)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF2CA50).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTournamentOver ? Icons.emoji_events_rounded : Icons.play_arrow_rounded,
                                  color: const Color(0xFF241A00),
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      isTournamentOver ? 'New Tourney' : 'Deal Next (#$nextDealNumber)',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF241A00),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: canDeclare
                              ? () {
                                  if (tableState.isAwaitingHumanDeclarationShow) {
                                    _handleSubmitDeclarationShow(context, ref);
                                  } else {
                                    _handleDiscardAndDeclare(context, ref);
                                  }
                                }
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: canDeclare ? 1.0 : 0.45,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF141B26), Color(0xFF0B1018)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF2CA50), width: 1.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF2CA50).withValues(alpha: canDeclare ? 0.35 : 0.0),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2CA50), size: 14),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Declare Hand',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFF2CA50),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),

                // 7. Top Right: 3-Dash MENU Button (Without Joker on right)
                Positioned(
                  left: 947,
                  top: 8,
                  width: 70,
                  height: 37,
                  child: InkWell(
                    onTap: () => _showMobileGameMenu(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1E0D), Color(0xFF151A22)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF2CA50), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF2CA50).withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                            ],
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'MENU',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFF2CA50),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 8. Left Thumb Action Buttons Stack (5 buttons from top to bottom)
                // Discard
                Positioned(
                  left: 14,
                  top: 252,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Discard',
                    icon: Icons.arrow_upward_rounded,
                    gradientColors: [const Color(0xFF1B2230), const Color(0xFF111722)],
                    borderColor: canDiscard ? const Color(0xFF60A5FA) : const Color(0xFF475569),
                    textColor: canDiscard ? Colors.white : const Color(0xFF94A3B8),
                    onTap: canDiscard
                        ? () {
                            if (tableState.selectedCard != null) {
                              notifier.discardCard(tableState.selectedCard!);
                            }
                          }
                        : null,
                  ),
                ),
                // Group
                Positioned(
                  left: 14,
                  top: 297,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Group',
                    icon: Icons.folder_rounded,
                    gradientColors: [const Color(0xFF2F62C9), const Color(0xFF1E4498)],
                    borderColor: const Color(0xFF60A5FA),
                    textColor: Colors.white,
                    onTap: () => notifier.groupSelectedCards(),
                  ),
                ),
                // Drop (40)
                Positioned(
                  left: 14,
                  top: 345,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Drop ($dropPenalty)',
                    icon: Icons.flag_rounded,
                    gradientColors: canDrop ? [const Color(0xFFA82020), const Color(0xFF7E1515)] : [const Color(0xFF221616), const Color(0xFF181010)],
                    borderColor: canDrop ? const Color(0xFFEF4444) : const Color(0x66EF4444),
                    textColor: canDrop ? Colors.white : const Color(0xFF94A3B8),
                    onTap: canDrop ? () => _handleDrop(context, ref) : null,
                  ),
                ),
                // Sort Hand
                Positioned(
                  left: 14,
                  top: 391,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Sort Hand',
                    icon: Icons.swap_vert_rounded,
                    gradientColors: [const Color(0xFF2D7D46), const Color(0xFF1E5C32)],
                    borderColor: const Color(0xFF10B981),
                    textColor: Colors.white,
                    onTap: () => notifier.sortHandAscending(),
                  ),
                ),
                // AI Group
                Positioned(
                  left: 14,
                  top: 437,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'AI Group',
                    icon: Icons.auto_awesome_rounded,
                    gradientColors: [const Color(0xFF6A3EA1), const Color(0xFF502A82)],
                    borderColor: const Color(0xFFA855F7),
                    textColor: Colors.white,
                    onTap: () => notifier.autoGroupHand(),
                  ),
                ),

                // 9. Grouped Player Hand (Exact measurements: 92px card width, 44px overlap, 16px group gap)
                Positioned(
                  left: 214,
                  top: 337,
                  width: 790,
                  child: PlayerHand(
                    cardGroups: cardGroups,
                    wildJokerCard: notifier.effectiveHumanWildJoker,
                    selectedCard: tableState.selectedCard,
                    selectedCards: tableState.selectedCards,
                    isDiscardPhase: isHumanTurn && isDiscardPhase,
                    customCardWidth: 92.0,
                    customCardHeight: 133.4,
                    customCardOverlap: 44.0,
                    customGroupSpacing: 16.0,
                    onCardTap: (card) => notifier.selectCard(card),
                    onCardMoved: (card, fromGroupId, toGroupId) {
                      notifier.moveCardBetweenGroups(
                        card,
                        fromGroupId,
                        toGroupId,
                        cardGroups.firstWhere((g) => g.id == toGroupId, orElse: () => cardGroups.first).cards.length,
                      );
                    },
                    onCardMovedToIndex: (card, fromGroupId, toGroupId, insertIndex) {
                      notifier.moveCardBetweenGroups(card, fromGroupId, toGroupId, insertIndex);
                    },
                    onCardReordered: (groupId, oldIndex, newIndex) {
                      notifier.moveCardWithinGroup(groupId, oldIndex, newIndex);
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
                ),

                // 10. Card Animation Layer (Deal & Discard flights)
                const Positioned.fill(
                  child: CardAnimationLayer(),
                ),

                if (uiState.showSecretJokerReveal && uiState.secretJokerCard != null)
                  Positioned.fill(
                    child: SecretJokerRevealOverlay(
                      wildJoker: uiState.secretJokerCard!,
                      onDismiss: () => ref.read(gameUIProvider.notifier).dismissSecretJokerReveal(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePerspectiveClosedDeck({
    required BuildContext context,
    required int count,
    required Card? wildJoker,
    required bool isClosedJoker,
    required bool isJokerOpened,
    required bool hasLife,
    required VoidCallback onOpenClosedJoker,
    required bool canDraw,
    required VoidCallback onDraw,
  }) {
    const double cardW = 58.0;
    const double cardH = 82.0;
    final bool showJokerFace = !isClosedJoker || isJokerOpened;

    return SizedBox(
      width: cardW + 36.0,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Perpendicular Wild Joker tucked horizontally underneath peeking to the left
          Positioned(
            left: 2,
            top: (cardH - cardW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: (showJokerFace && wildJoker != null)
                    ? CardWidget(
                        card: wildJoker,
                        isWildJoker: true,
                        width: cardW,
                        height: cardH,
                      )
                    : CardBackWidget(
                        width: cardW,
                        height: cardH,
                        onTap: (!showJokerFace && hasLife) ? onOpenClosedJoker : null,
                      ),
              ),
            ),
          ),
          // Face-down closed deck stack on top
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: canDraw ? onDraw : null,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: canDraw
                          ? const Color(0xFFF2CA50).withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.7),
                      blurRadius: canDraw ? 10 : 6,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CardBackWidget(
                      width: cardW,
                      height: cardH,
                      onTap: canDraw ? onDraw : null,
                    ),
                    Positioned(
                      bottom: -4,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xF20E141E),
                          border: Border.all(color: const Color(0xFFF2CA50), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CLOSED ($count)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF2CA50),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePerspectiveOpenPile({
    required BuildContext context,
    required List<Card> discardPile,
    required Card? wildJoker,
    required bool canDraw,
    required VoidCallback onDraw,
    required bool canDiscard,
    required void Function(Card)? onDiscardCard,
    required VoidCallback onShowHistory,
  }) {
    const double cardW = 58.0;
    const double cardH = 82.0;
    final topCard = discardPile.isNotEmpty ? discardPile.last : null;

    final pileWidget = Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: canDraw
                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.7),
            blurRadius: canDraw ? 10 : 6,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (topCard != null)
            CardWidget(
              card: topCard,
              width: cardW,
              height: cardH,
              isWildJoker: wildJoker != null && topCard.rank == wildJoker.rank,
              onTap: canDraw ? onDraw : onShowHistory,
            )
          else
            Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: const Center(
                child: Text('EMPTY', style: TextStyle(color: Colors.white38, fontSize: 9)),
              ),
            ),
          Positioned(
            bottom: -14,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'OPEN PILE',
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return DragTarget<Card>(
      onWillAcceptWithDetails: (details) => canDiscard,
      onAcceptWithDetails: (details) {
        if (onDiscardCard != null) {
          onDiscardCard(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool isTargetHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: isTargetHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: pileWidget,
        );
      },
    );
  }

  Widget _buildMobilePerspectiveFinishSlot({
    required BuildContext context,
    required bool isActivated,
    required bool canAcceptDrop,
    required bool canDeclare,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    const double cardW = 58.0;
    const double cardH = 82.0;

    return DragTarget<Card>(
      onWillAcceptWithDetails: (details) => canAcceptDrop,
      onAcceptWithDetails: (details) {
        if (onCardDeclared != null) {
          onCardDeclared(details.data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final active = isActivated || isHovering || canDeclare;

        return GestureDetector(
          onTap: canDeclare ? onDeclare : null,
          child: Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: active
                    ? [const Color(0x33F59E0B), const Color(0x22FBBF24)]
                    : [const Color(0x33120424), const Color(0x220A0214)],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? const Color(0xFFFBBF24) : const Color(0x55F59E0B),
                width: active ? 2.0 : 1.2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: const Color(0xFFF2CA50), size: active ? 18 : 14),
                      Text(
                        'FINISH',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF2CA50),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '14th Card',
                        style: GoogleFonts.outfit(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xAAF2CA50),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'DECLARE',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFFF2CA50) : Colors.white60,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobilePillButton({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 14),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileGameMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Center(
          child: Container(
            width: 360,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF010192A), Color(0xF7090F1A)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF2CA50), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFF2CA50).withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_rounded, color: Color(0xFFF2CA50), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'ROYAL GAME MENU',
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFFF2CA50),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: Color(0x33D4AF37), height: 1),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: Icons.leaderboard_rounded,
                  iconColor: const Color(0xFF60A5FA),
                  title: 'Live Scorecard',
                  subtitle: 'Round scores & elimination tracker',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openScoreCard(context, ref);
                  },
                ),
                _buildMenuItem(
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFFA78BFA),
                  title: 'Game Action Logs',
                  subtitle: 'Audited turn & discard event history',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openGameLogs(context, ref);
                  },
                ),
                _buildMenuItem(
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  title: 'Table Settings',
                  subtitle: 'Audio, animations & card options',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openSettings(context, ref);
                  },
                ),
                _buildMenuItem(
                  icon: Icons.android_rounded,
                  iconColor: const Color(0xFF34D399),
                  title: 'Download Android App',
                  subtitle: 'Direct native .apk installer for mobile',
                  highlight: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showDownloadApkDialog(context);
                  },
                ),
                _buildMenuItem(
                  icon: Icons.exit_to_app_rounded,
                  iconColor: const Color(0xFFF87171),
                  title: 'Exit Game',
                  subtitle: 'Leave current table session',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleExitGame(context, ref);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDownloadApkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1726),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF2CA50), width: 1.8),
          ),
          title: Row(
            children: [
              const Icon(Icons.android_rounded, color: Color(0xFF34D399), size: 28),
              const SizedBox(width: 10),
              Text(
                'Download Android App',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFF2CA50),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get the native Maya AI Rummy experience on your Android phone for smoother 60fps animations and offline play.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x2210B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct APK v1.0.0 • No Play Store required',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6EE7B7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white60, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(const ClipboardData(text: 'https://github.com/vamsikrishnabendalam/maya-ai-rummy/releases/latest/download/maya_rummy.apk'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text(
                      'APK download link copied to clipboard!',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded, color: Color(0xFF0F1726)),
              label: Text(
                'Copy Download Link',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F1726),
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2CA50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlight = false,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? const Color(0x1F10B981) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? const Color(0xFF10B981)
                : (isDestructive ? const Color(0x66EF4444) : const Color(0x22D4AF37)),
            width: highlight ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: isDestructive ? const Color(0xFFFCA5A5) : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  // --- 3D Perspective Card Elements for Flat Table Surface ---

  static const double _tableCardW = 84.0;

  static const double _tableCardH = 117.6;

  /// Closed Deck Stack with Perpendicular Wild Joker tucked horizontally underneath

  /// Closed Deck Stack with Perpendicular Wild Joker tucked horizontally underneath
  Widget _buildPerspectiveClosedDeckWithTuckedJoker({
    required BuildContext context,
    required int count,
    required Card? wildJoker,
    required bool isClosedJoker,
    required bool isJokerOpened,
    required bool hasLife,
    required VoidCallback onOpenClosedJoker,
    required bool canDraw,
    required VoidCallback onDraw,
  }) {
    final bool showJokerFace = !isClosedJoker || isJokerOpened;
    const double jokerW = 65.0;
    const double jokerH = 91.0;

    return SizedBox(
      width: _tableCardW + 42.0,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // 1. Perpendicular Wild Joker tucked under the closed deck peeking to the left
          Positioned(
            left: 8,
            top: (_tableCardH - jokerW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: jokerW,
                height: jokerH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: (showJokerFace && wildJoker != null)
                    ? CardWidget(
                        card: wildJoker,
                        isWildJoker: false,
                        width: jokerW,
                        height: jokerH,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CardBackWidget(
                            width: jokerW,
                            height: jokerH,
                            showPulse: false,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.shade700,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: Colors.amber.shade200,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // 2. Physical 3D paper stack effect: layered card rims under top card
          Positioned(
            right: 4.5,
            top: 4.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6D5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x445D4037), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2.5,
            top: 2.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F0E4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x335D4037), width: 0.8),
              ),
            ),
          ),

          // 3. Top Interactive Closed Deck Card
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: canDraw ? onDraw : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: canDraw
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.65),
                      blurRadius: canDraw ? 14 : 7,
                      spreadRadius: canDraw ? 2.5 : 0,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: CardBackWidget(
                  width: _tableCardW,
                  height: _tableCardH,
                  showPulse: canDraw,
                ),
              ),
            ),
          ),

          // 4. Deck Count Chip Badge
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1E12), Color(0xFF140D07)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2CA50), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFDE68A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open Discard Pile showing up to 5 overlapping discarded cards + Drag & Drop Discard Target
  Widget _buildPerspectiveOpenPile({
    required BuildContext context,
    required List<Card> discardPile,
    required Card? wildJoker,
    required bool canDraw,
    required VoidCallback onDraw,
    required bool canDiscard,
    required void Function(Card)? onDiscardCard,
    required VoidCallback onShowHistory,
  }) {
    final visibleDiscards = discardPile.length <= 5
        ? discardPile
        : discardPile.sublist(discardPile.length - 5);
    final count = visibleDiscards.length;
    final double stepX =
        _tableCardW * 0.46; // ~50% overlap showing half of each previous card
    final totalWidth =
        count <= 1 ? _tableCardW : (_tableCardW + (count - 1) * stepX);

    final pileWidget = SizedBox(
      width: totalWidth,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count == 0)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: _tableCardW,
                height: _tableCardH,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'EMPTY',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),

          // Render last up to 5 cards overlapping horizontally
          for (var i = 0; i < count; i++) ...[
            Positioned(
              left: i * stepX,
              top: 0,
              child: GestureDetector(
                onTap: (i == count - 1 && canDraw) ? onDraw : null,
                child: Container(
                  width: _tableCardW,
                  height: _tableCardH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (i == count - 1 && canDraw)
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                            : Colors.black.withValues(alpha: 0.5),
                        blurRadius: (i == count - 1 && canDraw) ? 12 : 5,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: CardWidget(
                    card: visibleDiscards[i],
                    isWildJoker:
                        JokerUtils.isWildJoker(visibleDiscards[i], wildJoker),
                    width: _tableCardW,
                    height: _tableCardH,
                  ),
                ),
              ),
            ),
          ],

          // History Modal Button on top right of the discard fan
          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onShowHistory,
                child: Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFBBF24), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: Color(0xFFFDE68A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Wrap in DragTarget for Drag & Drop Discarding!
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => canDiscard,
      onAcceptWithDetails: (details) {
        if (details.data is CardDragData) {
          onDiscardCard?.call((details.data as CardDragData).card);
        } else if (details.data is Card) {
          onDiscardCard?.call(details.data as Card);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.75),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: pileWidget,
        );
      },
    );
  }

  /// Finish / Declare Slot with Drag & Drop declaration support
  Widget _buildPerspectiveFinishSlot({
    required BuildContext context,
    required bool isActivated,
    required bool canAcceptDrop,
    required bool canDeclare,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    Widget buildSlotContainer(bool isHovering) {
      final active = isActivated || isHovering || canDeclare;
      return GestureDetector(
        onTap: canDeclare ? onDeclare : null,
        child: Container(
          width: _tableCardW,
          height: _tableCardH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      const Color(0x44F59E0B),
                      const Color(0x22FBBF24),
                    ]
                  : [
                      const Color(0x33120424),
                      const Color(0x220A0214),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFFFBBF24) : const Color(0x55F59E0B),
              width: active ? 2.2 : 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFFBBF24)
                          .withValues(alpha: isHovering ? 0.8 : 0.55),
                      blurRadius: isHovering ? 20 : 14,
                      spreadRadius: isHovering ? 3.5 : 2.5,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: active
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFFBBF24).withValues(alpha: 0.6),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                'FINISH',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: active ? const Color(0xFFFDE68A) : Colors.white70,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '14th Card',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFFFDE68A).withValues(alpha: 0.8)
                      : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onCardDeclared != null) {
      return DragTarget<Object>(
        onWillAcceptWithDetails: (_) => canAcceptDrop,
        onAcceptWithDetails: (details) {
          if (details.data is CardDragData) {
            onCardDeclared((details.data as CardDragData).card);
          } else if (details.data is Card) {
            onCardDeclared(details.data as Card);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.8),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: buildSlotContainer(isHovering),
          );
        },
      );
    }

    return buildSlotContainer(false);
  }

  Widget _buildTopHudBar(
    BuildContext context,
    WidgetRef ref, {
    required dynamic tableState,
    required dynamic notifier,
    required String toastMessage,
    required bool isGameComplete,
    required bool isTournamentOver,
    required Card? wildJoker,
  }) {
    final size = MediaQuery.of(context).size;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isTablet = Responsive.isTablet(context) ||
        (size.width >= 768 && size.width < 1024);
    final isLockedJoker = tableState.gameSettings.isClosedJoker &&
        tableState.gameSettings.jokerMode != 'OPEN' &&
        !tableState.hasHumanOpenedJoker;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isDesktop ? 6 : 4),
        bottom: isDesktop ? 8 : 5,
        left: isDesktop ? 18 : 8,
        right: isDesktop ? 18 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF09141A), Color(0xFF040A0D)],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left and Right HUD Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Title, Game mode badges, Mini Joker
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAYA AI RUMMY',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF2CA50),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  if (isDesktop || size.width >= 960) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 8 : 5,
                        vertical: isDesktop ? 3.5 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2CA50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '6-MAX',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 10.0 : 8.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFF2CA50),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 6 : 4),
                  ],
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 8 : 5,
                      vertical: isDesktop ? 3.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isDesktop || size.width >= 800
                          ? '${tableState.gameSettings.eliminationScore} POOL'
                          : '${tableState.gameSettings.eliminationScore}P',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD0C5AF),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  _buildMiniWildJokerPill(wildJoker, isLockedJoker,
                      isDesktop: isDesktop),
                ],
              ),

              // Right: Scorecard Button, Virtual Coins & Table rules pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Right Scorecard Button for Mid-Game / Round Review
                  InkWell(
                    onTap: () => _openScoreCard(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E2413), Color(0xFF181F26)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF2CA50).withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_chart_rounded,
                            size: isDesktop ? 14 : 11.5,
                            color: const Color(0xFFF2CA50),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Scorecard',
                            style: GoogleFonts.cinzel(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Top Right Game Logs Button
                  InkWell(
                    onTap: () => _openGameLogs(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_edu_rounded,
                            size: isDesktop ? 14 : 11.5,
                            color: const Color(0xFF93C5FD),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Logs',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDBEAFE),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Top Right Settings Button to configure Timer, Drop Rules, Elimination
                  InkWell(
                    onTap: () => _openSettings(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E2413), Color(0xFF181F26)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: isDesktop ? 14 : 11.5,
                            color: const Color(0xFFF2CA50),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Settings',
                            style: GoogleFonts.cinzel(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  // Top Right Exit Button
                  InkWell(
                    onTap: () => _handleExitGame(context, ref),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3F1417), Color(0xFF1A0A0C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: isDesktop ? 14 : 11.5,
                            color: const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Exit',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFCA5A5),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Exactly Center-Screen Informative Toast Pill (Guaranteed Horizontally Centered)
          Center(
            child: _buildToastPill(
              toastMessage,
              isDesktop: isDesktop,
              onTap: tableState.isAwaitingHumanDeclarationShow
                  ? () => _showOpponentDeclarationModal(context, ref)
                  : (isGameComplete
                      ? () {
                          if (isTournamentOver) {
                            notifier.resetTournament();
                          } else {
                            _checkTournamentStatus(context, ref);
                          }
                        }
                      : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniWildJokerPill(Card? wildJoker, bool isLocked,
      {bool isDesktop = false}) {
    String rankStr = '7';

    String suitStr = '♠';

    bool isRed = false;

    if (wildJoker != null) {
      if (wildJoker.isPrintedJoker) {
        rankStr = 'JKR';

        suitStr = '★';
      } else {
        switch (wildJoker.rank) {
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

          default:
            rankStr = '7';
            break;
        }

        switch (wildJoker.suit) {
          case Suit.hearts:
            suitStr = '♥';

            isRed = true;

            break;

          case Suit.diamonds:
            suitStr = '♦';

            isRed = true;

            break;

          case Suit.clubs:
            suitStr = '♣';

            isRed = false;

            break;

          case Suit.spades:
            suitStr = '♠';

            isRed = false;

            break;

          default:
            suitStr = '♠';

            isRed = false;
        }
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 11 : 8,
        vertical: isDesktop ? 4.5 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF222B32).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'JOKER',
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 10.5 : 8.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD0C5AF),
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: isDesktop ? 7 : 5),
          if (isLocked || wildJoker == null)
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 6 : 4, vertical: isDesktop ? 2 : 1),
              decoration: BoxDecoration(
                color: const Color(0xFF141D24),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded,
                      size: isDesktop ? 11 : 8.5,
                      color: const Color(0xFFF2CA50)),
                  const SizedBox(width: 2),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: isDesktop ? 9.5 : 7.5,
                      color: const Color(0xFFF2CA50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 6 : 4, vertical: isDesktop ? 2 : 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rankStr,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 12 : 10,
                      fontWeight: FontWeight.w900,
                      color: isRed
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF141D24),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    suitStr,
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 9,
                      color: isRed
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF141D24),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(width: isDesktop ? 6 : 4),
          Icon(
            Icons.workspace_premium_rounded,
            size: isDesktop ? 16 : 13,
            color: const Color(0xFFF2CA50),
          ),
        ],
      ),
    );
  }

  // --- Bottom Player Hand Dock ---

  Widget _buildBottomPlayerDock(
    BuildContext context,
    WidgetRef ref, {
    required dynamic tableState,
    required dynamic notifier,
    required List<CardGroup> cardGroups,
    required bool isHumanTurn,
    required bool isDiscardPhase,
    required bool canDrop,
    required int dropPenalty,
    required bool canDiscard,
    required bool canDeclare,
    required bool isGameComplete,
    required bool isTournamentOver,
    required int nextDealNumber,
  }) {
    final uiState = ref.watch(gameUIProvider);

    final size = MediaQuery.of(context).size;

    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;

    final isTablet = Responsive.isTablet(context) ||
        (size.width >= 768 && size.width < 1024);

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final isMobileLandscape = !isPortrait && !isDesktop;

    if (isMobileLandscape) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerHand(
              cardGroups: cardGroups,
              wildJokerCard: notifier.effectiveHumanWildJoker,
              selectedCard: tableState.selectedCard,
              selectedCards: tableState.selectedCards,
              isDiscardPhase: isHumanTurn && isDiscardPhase,
              onCardTap: (card) => notifier.selectCard(card),
              onCardMoved: (card, fromGroupId, toGroupId) {
                notifier.moveCardBetweenGroups(
                  card,
                  fromGroupId,
                  toGroupId,
                  cardGroups
                      .firstWhere((g) => g.id == toGroupId,
                          orElse: () => cardGroups.first)
                      .cards
                      .length,
                );
              },
              onCardMovedToIndex: (card, fromGroupId, toGroupId, insertIndex) {
                notifier.moveCardBetweenGroups(
                    card, fromGroupId, toGroupId, insertIndex);
              },
              onCardReordered: (groupId, oldIndex, newIndex) {
                notifier.moveCardWithinGroup(groupId, oldIndex, newIndex);
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
            const SizedBox(height: 2),
            RoyalLifeChecklistBar(
              hasFirstLife: notifier.hasHumanLife,
              hasSecondLife: notifier.hasHumanSecondLife,
              points: tableState.currentScore,
              isMyTurn: isHumanTurn,
              turnSeconds: tableState.turnSecondsRemaining,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 10,
        vertical: isDesktop ? 4 : 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bottom Controls + Hand Rack Row

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left Thumb Controls: Drop, Sort Hand

              _buildLeftThumbControls(
                context,
                ref,
                canDrop: canDrop,
                dropPenalty: dropPenalty,
                notifier: notifier,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),

              // Center Hand Rack

              Expanded(
                child: PlayerHand(
                  cardGroups: cardGroups,
                  wildJokerCard: notifier.effectiveHumanWildJoker,
                  selectedCard: tableState.selectedCard,
                  isDiscardPhase: isHumanTurn && isDiscardPhase,
                  onCardTap: (card) => notifier.selectCard(card),
                  onCardMoved: (card, fromGroupId, toGroupId) {
                    notifier.moveCardBetweenGroups(
                      card,
                      fromGroupId,
                      toGroupId,
                      cardGroups
                          .firstWhere((g) => g.id == toGroupId,
                              orElse: () => cardGroups.first)
                          .cards
                          .length,
                    );
                  },
                  onCardMovedToIndex:
                      (card, fromGroupId, toGroupId, insertIndex) {
                    notifier.moveCardBetweenGroups(
                        card, fromGroupId, toGroupId, insertIndex);
                  },
                  onCardReordered: (groupId, oldIndex, newIndex) {
                    notifier.moveCardWithinGroup(groupId, oldIndex, newIndex);
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
              ),

              // Right Thumb Controls: Group, Discard, Declare (or Scorecard, Next Deal when complete)

              _buildRightThumbControls(
                context,
                ref,
                notifier: notifier,
                tableState: tableState,
                uiState: uiState,
                canDiscard: canDiscard,
                canDeclare: canDeclare,
                isGameComplete: isGameComplete,
                isTournamentOver: isTournamentOver,
                nextDealNumber: nextDealNumber,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ],
          ),

          SizedBox(height: isDesktop ? 4 : 2),

          // Meld Status Bar directly BELOW cards

          RoyalLifeChecklistBar(
            hasFirstLife: notifier.hasHumanLife,
            hasSecondLife: notifier.hasHumanSecondLife,
            points: tableState.currentScore,
            isMyTurn: isHumanTurn,
            turnSeconds: tableState.turnSecondsRemaining,
          ),
        ],
      ),
    );
  }

  // --- Left Thumb Controls (Drop, Sort Hand) ---

  // --- Left Thumb Controls (Drop, Sort Hand, AI Group) - Royal Casino Theme ---
  Widget _buildLeftThumbControls(
    BuildContext context,
    WidgetRef ref, {
    required bool canDrop,
    required int dropPenalty,
    required dynamic notifier,
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final double padH = isDesktop ? 18.0 : (isTablet ? 14.0 : 10.0);
    final double padV = isDesktop ? 11.0 : (isTablet ? 9.0 : 7.0);
    final double iconSize = isDesktop ? 19.0 : (isTablet ? 16.0 : 14.0);
    final double fontSize = isDesktop ? 14.0 : (isTablet ? 12.0 : 10.5);
    final double gap = isDesktop ? 9.0 : 6.0;

    return Padding(
      padding: EdgeInsets.only(right: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drop Button (Royal Crimson/Bronze Theme)
          InkWell(
            onTap: canDrop ? () => _handleDrop(context, ref) : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: canDrop
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                      )
                    : null,
                color: canDrop ? null : const Color(0xFF1B2228),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canDrop
                      ? const Color(0xFFFCA5A5)
                      : const Color(0x66D4AF37),
                  width: canDrop ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: canDrop
                        ? const Color(0xFFDC2626).withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.4),
                    blurRadius: canDrop ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: iconSize,
                    color: canDrop
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Drop ($dropPenalty)',
                    style: GoogleFonts.outfit(
                      color: canDrop
                          ? const Color(0xFFFFF1F2)
                          : const Color(0xFF94A3B8),
                      fontSize: fontSize,
                      fontWeight: canDrop ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // 2. Sort Button (Ascending Suit Order - Royal Emerald/Gold Theme)
          InkWell(
            onTap: () => notifier.sortHandAscending(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF15803D), Color(0xFF0E4B24)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF86EFAC),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded,
                      size: iconSize, color: const Color(0xFFDCFCE7)),
                  const SizedBox(width: 5),
                  Text(
                    'Sort Hand',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFDCFCE7),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // 3. Dedicated AI Group Button (Smart Auto-Melder - Royal Amethyst/Gold Theme)
          InkWell(
            onTap: () => notifier.autoGroupHand(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF2CA50),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: iconSize, color: const Color(0xFFFDE68A)),
                  const SizedBox(width: 5),
                  Text(
                    'AI Group',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFDE68A),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Right Thumb Controls (Group, Discard, Declare Hand) - Royal Casino Theme ---
  Widget _buildRightThumbControls(
    BuildContext context,
    WidgetRef ref, {
    required dynamic notifier,
    required dynamic tableState,
    required GameUIState uiState,
    required bool canDiscard,
    required bool canDeclare,
    required bool isGameComplete,
    required bool isTournamentOver,
    required int nextDealNumber,
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final double padH = isDesktop ? 18.0 : (isTablet ? 14.0 : 10.0);
    final double padV = isDesktop ? 11.0 : (isTablet ? 9.0 : 7.0);
    final double iconSize = isDesktop ? 19.0 : (isTablet ? 16.0 : 14.0);
    final double fontSize = isDesktop ? 14.0 : (isTablet ? 12.0 : 10.5);
    final double declareFontSize = isDesktop ? 14.5 : (isTablet ? 13.0 : 11.5);
    final double declarePadH = isDesktop ? 26.0 : (isTablet ? 20.0 : 16.0);
    final double gap = isDesktop ? 9.0 : 6.0;
    final bool isHumanTurn = notifier.isHumanTurn;
    final bool isDiscardPhase = notifier.isDiscardPhase;
    final isFinishButtonActive =
        canDeclare || (isHumanTurn && isDiscardPhase && uiState.isDragging);
    final canAcceptFinishDrop =
        (isHumanTurn && isDiscardPhase && !tableState.isRoundOver) ||
            tableState.isAwaitingHumanDeclarationShow;

    if (isGameComplete) {
      return Padding(
        padding: EdgeInsets.only(left: isDesktop ? 10 : 6, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                if (isTournamentOver) {
                  notifier.resetTournament();
                } else {
                  _checkTournamentStatus(context, ref);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: declarePadH, vertical: padV + 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF2CA50),
                      Color(0xFFD4AF37),
                      Color(0xFFAA771C)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTournamentOver
                          ? Icons.emoji_events_rounded
                          : Icons.play_arrow_rounded,
                      size: iconSize + 2,
                      color: const Color(0xFF241A00),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isTournamentOver
                          ? 'New Tournament'
                          : 'Deal Next Round (#$nextDealNumber)',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF241A00),
                        fontSize: declareFontSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _openScoreCard(context, ref),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 10, vertical: padV + 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF182128),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                      width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.leaderboard_rounded,
                        size: 16, color: Color(0xFFFDE68A)),
                    const SizedBox(width: 4),
                    Text(
                      'Scorecard',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFDE68A),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Group + Discard
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Group Button (Groups selected cards - Royal Sapphire/Gold Theme)
              InkWell(
                onTap: () => notifier.groupSelectedCards(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF93C5FD),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded,
                          size: iconSize, color: const Color(0xFFEFF6FF)),
                      const SizedBox(width: 5),
                      Text(
                        'Group',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFEFF6FF),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 8 : 5),

              // 2. Discard Button (Royal Amber/Gold Theme with DragTarget support)
              DragTarget<Object>(
                onWillAcceptWithDetails: (_) =>
                    isHumanTurn && isDiscardPhase && !tableState.isRoundOver,
                onAcceptWithDetails: (details) {
                  Card? droppedCard;
                  if (details.data is CardDragData) {
                    droppedCard = (details.data as CardDragData).card;
                  } else if (details.data is Card) {
                    droppedCard = details.data as Card;
                  }
                  if (droppedCard != null) {
                    notifier.discardCard(droppedCard);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  final active = canDiscard ||
                      isHovering ||
                      (isHumanTurn && isDiscardPhase && uiState.isDragging);
                  return InkWell(
                    onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 20 : 12,
                        vertical: padV,
                      ),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              )
                            : null,
                        color: active ? null : const Color(0xFF1B2228),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHovering
                              ? const Color(0xFFFFFBEB)
                              : (active
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0x66D4AF37)),
                          width: active ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: active
                                ? const Color(0xFFF59E0B).withValues(
                                    alpha: isHovering ? 0.95 : 0.7)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: active ? (isHovering ? 14 : 10) : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: iconSize,
                            color: active
                                ? const Color(0xFF1F1200)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHovering ? 'Drop to Discard' : 'Discard',
                            style: GoogleFonts.outfit(
                              color: active
                                  ? const Color(0xFF1F1200)
                                  : const Color(0xFF94A3B8),
                              fontSize: fontSize,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: gap),

          // 3. Declare Hand (or Submit Show) Full Width Button (Royal Gold Trophy Theme + DragTarget)
          DragTarget<Object>(
            onWillAcceptWithDetails: (_) => canAcceptFinishDrop,
            onAcceptWithDetails: (details) {
              Card? droppedCard;
              if (details.data is CardDragData) {
                droppedCard = (details.data as CardDragData).card;
              } else if (details.data is Card) {
                droppedCard = details.data as Card;
              }
              if (tableState.isAwaitingHumanDeclarationShow) {
                _handleSubmitDeclarationShow(context, ref);
              } else {
                _handleDiscardAndDeclare(context, ref, finishCard: droppedCard);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              final active = canDeclare || isHovering || isFinishButtonActive;
              return InkWell(
                onTap: canDeclare
                    ? () {
                        if (tableState.isAwaitingHumanDeclarationShow) {
                          _handleSubmitDeclarationShow(context, ref);
                        } else {
                          _handleDiscardAndDeclare(context, ref);
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: declarePadH,
                    vertical: padV + 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFF59E0B),
                              Color(0xFFD97706),
                              Color(0xFFB45309)
                            ],
                          )
                        : null,
                    color: active ? null : const Color(0xFF1B2228),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFFEF08A)
                          : const Color(0x66D4AF37),
                      width: active ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: active
                            ? const Color(0xFFF59E0B)
                                .withValues(alpha: isHovering ? 0.95 : 0.7)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: active ? (isHovering ? 16 : 12) : 4,
                        offset: const Offset(0, 3),
                      ),
                      if (active)
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: iconSize + 2,
                        color: active
                            ? const Color(0xFF241A00)
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tableState.isAwaitingHumanDeclarationShow
                            ? 'Declare Hand (${tableState.currentScore}p)'
                            : 'Declare Hand',
                        style: GoogleFonts.outfit(
                          color: active
                              ? const Color(0xFF241A00)
                              : const Color(0xFF94A3B8),
                          fontSize: declareFontSize,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCompleteBar(
    BuildContext context,
    WidgetRef ref, {
    required bool isDesktop,
    required bool isTournamentOver,
    required int nextDealNumber,
  }) {
    final notifier = ref.read(gameTableProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 10,
            vertical: isDesktop ? 5 : 3,
          ),
          child: Row(
            children: [
              // Scorecard Button

              Expanded(
                flex: 1,
                child: InkWell(
                  onTap: () => _openScoreCard(context, ref),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: isDesktop ? 9 : 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart_outlined,
                            size: 14, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text(
                          'Scorecard',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Group Button (inspect hand grouping)

              InkWell(
                onTap: () => notifier.autoGroupHand(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isDesktop ? 9 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF042F2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 13, color: Color(0xFF00E5FF)),
                      SizedBox(width: 4),
                      Text(
                        'Group',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Primary Action: Next Deal or New Tournament

              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    if (isTournamentOver) {
                      notifier.resetTournament();
                    } else {
                      _checkTournamentStatus(context, ref);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: isDesktop ? 9 : 7),
                    decoration: BoxDecoration(
                      gradient: isTournamentOver
                          ? const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFF10B981)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isTournamentOver
                            ? const Color(0xFFFDA4AF)
                            : const Color(0xFFFDE68A),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isTournamentOver
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF10B981))
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isTournamentOver
                              ? Icons.restart_alt_rounded
                              : Icons.play_arrow_rounded,
                          size: 17,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isTournamentOver
                                ? 'Start New Tournament'
                                : 'Deal Next Round (#$nextDealNumber)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScoreCard(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);

    final notifier = ref.read(gameTableProvider.notifier);

    final isRoundComplete = notifier.isGameComplete;

    final isTournamentOver =
        tableState.isHumanEliminated || tableState.isAiEliminated;

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
          isRoundComplete: isRoundComplete,
          onClose: () => Navigator.of(ctx).pop(),
          onResetTournament: () {
            Navigator.of(ctx).pop();

            notifier.resetTournament();
          },
          onNextDeal: (isRoundComplete && !isTournamentOver)
              ? () {
                  Navigator.of(ctx).pop();

                  _checkTournamentStatus(context, ref);
                }
              : null,
          onViewLogs: () => _openGameLogs(context, ref),
        );
      },
    );
  }

  void _openGameLogs(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    GameLogsModal.show(
      context,
      logs: tableState.actionLogs,
      totalRounds:
          tableState.roundScores.length + (tableState.isRoundOver ? 0 : 1),
      onDownloadLogs: ({int? roundNumber, bool asJson = true}) {
        notifier.downloadLogs(roundNumber: roundNumber, asJson: asJson);
      },
      onGetLogsText: ({int? roundNumber}) {
        return notifier.getLogsText(roundNumber: roundNumber);
      },
    );
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);
    final isTournamentOver =
        tableState.isHumanEliminated || tableState.isAiEliminated;
    // Settings cannot be edited after tournament starts
    final isTournamentActive = !isTournamentOver;

    showDialog(
      context: context,
      builder: (ctx) {
        return GameSettingsModal(
          currentSettings: tableState.gameSettings,
          isReadOnly: isTournamentActive,
          onSave: (newSettings) {
            if (isTournamentActive) return;
            notifier.updateSettings(newSettings);
            ref
                .read(homeProvider.notifier)
                .setTurnTimer(newSettings.turnTimerSeconds);
            ref.read(homeProvider.notifier).setJokerMode(newSettings.jokerMode);
          },
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  Future<void> _handleExitGame(BuildContext context, WidgetRef ref) async {
    final tableState = ref.read(gameTableProvider);
    final isTournamentOver =
        tableState.isHumanEliminated || tableState.isAiEliminated;

    if (!isTournamentOver) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141E18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Exit Game?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Your active tournament will be terminated and unsaved progress will be lost. Do you wish to leave the table?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Stay & Play',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              child: const Text(
                'Exit to Lobby',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );

      if (shouldExit != true) return;
    }

    if (!context.mounted) return;
    ref.read(gameTableProvider.notifier).cancelTurnTimer();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _handleDiscardAndDeclare(BuildContext context, WidgetRef ref,
      {Card? finishCard}) {
    final notifier = ref.read(gameTableProvider.notifier);
    final openJoker = notifier.wildJokerCard;
    final result = notifier.discardAndDeclareSelectedCard(finishCard);
    final tableState = ref.read(gameTableProvider);
    final roundScore = tableState.roundScores.isNotEmpty
        ? tableState.roundScores.last
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return DeclarationResultModal(
          result: result,
          openJoker: openJoker,
          roundScore: roundScore,
          onDismiss: () {
            Navigator.of(ctx).pop();
          },
          onNewGame: () {
            Navigator.of(ctx).pop();
            _checkTournamentStatus(context, ref);
          },
          onViewScoreCard: () {
            Navigator.of(ctx).pop();
            _openScoreCard(context, ref);
          },
        );
      },
    );
  }

  void _showOpponentDeclarationModal(BuildContext context, WidgetRef ref) {
    final tableState = ref.read(gameTableProvider);
    final botPartition = tableState.botDeclarationResult;
    if (botPartition == null) return;

    OpponentDeclarationModal.show(
      context: context,
      declarerName: 'Maya (AI Host)',
      botDeclarationResult: botPartition,
      finishCard: tableState.botDiscardCard,
      wildJoker: ref.read(gameTableProvider.notifier).wildJokerCard,
      onRearrange: () {
        Navigator.of(context).pop();
      },
      onDeclareFinalHand: () {
        Navigator.of(context).pop();
        _handleSubmitDeclarationShow(context, ref);
      },
    );
  }

  void _handleSubmitDeclarationShow(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameTableProvider.notifier);

    final tableState = ref.read(gameTableProvider);

    final currentDeadwood = tableState.currentScore;

    // Check if an even lower optimal score exists with HandPartitioner

    final allCards = notifier.allGroupedCards();

    final optimalPartition =
        HandPartitioner.findBestPartition(allCards, notifier.wildJokerCard);

    final optimalDeadwood = optimalPartition.penaltyScore;

    void executeSubmit() {
      notifier.submitHumanDeclarationShow();

      final updatedState = ref.read(gameTableProvider);

      final humanScore = updatedState.currentScore;

      final isBotWinner = (updatedState.roundScores.isNotEmpty &&
          updatedState.roundScores.last.aiScore == 0);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF14241C),
                      Color(0xFF0F1B15),
                      Color(0xFF09120E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFFFEF08A), Color(0xFFD4AF37)],
                              ),
                            ),
                            child: Icon(
                              isBotWinner ? Icons.emoji_events_rounded : Icons.celebration_rounded,
                              color: const Color(0xFF241A00),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Round ${updatedState.roundScores.length} Complete!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFEF08A),
                                  ),
                                ),
                                Text(
                                  isBotWinner
                                      ? 'Maya Bot declared a valid show (0 pts)'
                                      : 'You won by default (0 pts)!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Final Hand Deadwood Score Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x4D000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isBotWinner
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                                : const Color(0xFF4ADE80).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Final Hand Penalty:',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '$humanScore PTS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: humanScore == 0
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Maya Bot Score:',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  isBotWinner ? '0 PTS (Winner)' : '${updatedState.roundScores.last.aiScore} PTS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isBotWinner
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFF87171),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cumulative Scores
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x33000000),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x22D4AF37)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Total: ${updatedState.totalHumanScore} pts',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFEF08A),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Maya Total: ${updatedState.totalAiScore} pts',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Actions
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.table_chart_rounded, size: 16),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFEF08A),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _openScoreCard(context, ref);
                            },
                            label: const Text('Scorecard'),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Review Table'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: const Color(0xFF241A00),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _checkTournamentStatus(context, ref);
                            },
                            label: Text(
                              'Next Deal',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
              Text('Lower Score Available!',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your current arrangement has $currentDeadwood PTS.\n\n'
            'Auto-Arrange can reorganize your sequences and jokers to achieve $optimalDeadwood PTS (saves ${currentDeadwood - optimalDeadwood} pts)!',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.4),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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

    final isFirstDrop =
        tableState.gameState.turnNumber <= 1 && !tableState.hasDrawnThisTurn;

    final penalty = isFirstDrop
        ? tableState.gameSettings.firstDropPenalty
        : tableState.gameSettings.middleDropPenalty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141E18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Drop Current Hand?',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'You will drop this hand and receive $penalty penalty points (${isFirstDrop ? "First Drop" : "Middle Drop"}).',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(ctx).pop();

                notifier.dropCurrentHand();

                _checkTournamentStatus(context, ref);
              },
              child: const Text('Confirm Drop',
                  style: TextStyle(color: Colors.white)),
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
      final isHumanWinner =
          tableState.isAiEliminated && !tableState.isHumanEliminated;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF141E18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: const Text('View Scorecard',
                    style: TextStyle(color: AppColors.accent)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();

                  // Close to review final table state
                },
                child: const Text('Review Table'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () {
                  Navigator.of(ctx).pop();

                  notifier.resetTournament();
                },
                child: const Text('New Tournament',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  final double strokeWidth;

  final double dash;

  final double gap;

  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dash = 6.0,
    this.gap = 4.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;

      while (distance < metric.length) {
        final length =
            (distance + dash > metric.length) ? metric.length - distance : dash;

        dashPath.addPath(
            metric.extractPath(distance, distance + length), Offset.zero);

        distance += dash + gap;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
