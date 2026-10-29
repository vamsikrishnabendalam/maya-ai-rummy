import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
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
import '../widgets/score_card_modal.dart';
import '../widgets/game_settings_modal.dart';
import '../widgets/card_animation_layer.dart';
import '../widgets/royal_life_checklist_bar.dart';
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
    if (isAwaitingDeclarationShow) return 'Maya Bot declared! Arrange cards and tap Submit Show.';
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

  Widget _buildToastPill(String message, {VoidCallback? onTap, bool isDesktop = false}) {
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
          Icon(Icons.auto_awesome, color: const Color(0xFFFBBF24), size: isDesktop ? 14 : 12),
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

    final isFirstDrop = gameState.turnNumber <= 1 && !tableState.hasDrawnThisTurn;
    final dropPenalty = isFirstDrop
        ? tableState.gameSettings.firstDropPenalty
        : tableState.gameSettings.middleDropPenalty;
    final canDrop = isHumanTurn && !isGameComplete && !tableState.isAwaitingHumanDeclarationShow;
    final canDiscard = notifier.canDiscard;
    final canDeclare = notifier.canDiscardAndDeclare || tableState.isAwaitingHumanDeclarationShow;

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isDesktop = Responsive.isDesktop(context);
    final isMobileLandscape = Responsive.isMobileLandscape(context);

    final isTournamentOver = tableState.isHumanEliminated || tableState.isAiEliminated;

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
                // 1. LAYER 1: 3D PERSPECTIVE WARPED TABLE SURFACE (THE FLAT CARDS)
                // -------------------------------------------------------------
                Positioned.fill(
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
                          // Central Table Cards Row: Decreased compact size, Wild Joker tucked under Closed Deck, perfectly even horizontal alignment
                          Positioned(
                            top: 365,
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
                                    isClosedJoker: tableState.gameSettings.isClosedJoker,
                                    isJokerOpened: tableState.gameSettings.jokerMode == 'OPEN' || tableState.hasHumanOpenedJoker,
                                    hasLife: notifier.hasHumanLife,
                                    onOpenClosedJoker: () => notifier.openClosedJoker(),
                                    canDraw: isHumanTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromClosedDeck(),
                                  ),

                                  const SizedBox(width: 32),

                                  // 2. Open Discard Pile
                                  _buildPerspectiveOpenPile(
                                    context: context,
                                    topCard: gameState.openPile.isNotEmpty ? gameState.openPile.last : null,
                                    wildJoker: wildJoker,
                                    canDraw: isHumanTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromOpenDeck(),
                                    onShowHistory: () {
                                      if (gameState.openPile.isNotEmpty) {
                                        DiscardHistoryModal.show(
                                          context,
                                          discardPile: gameState.openPile,
                                          wildJoker: wildJoker,
                                        );
                                      }
                                    },
                                    lastDiscardFrom: gameState.openPile.isNotEmpty ? 'Maya' : null,
                                  ),

                                  const SizedBox(width: 32),

                                  // 3. Finish / Declare Slot
                                  _buildPerspectiveFinishSlot(
                                    context: context,
                                    canDeclare: canDeclare,
                                    onDeclare: canDeclare ? () {
                                      if (tableState.isAwaitingHumanDeclarationShow) {
                                        _handleSubmitDeclarationShow(context, ref);
                                      } else {
                                        _handleDiscardAndDeclare(context, ref);
                                      }
                                    } : null,
                                    onCardDeclared: canDeclare ? (card) {
                                      notifier.selectCard(card);
                                      if (tableState.isAwaitingHumanDeclarationShow) {
                                        _handleSubmitDeclarationShow(context, ref);
                                      } else {
                                        _handleDiscardAndDeclare(context, ref);
                                      }
                                    } : null,
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

                // -------------------------------------------------------------
                // 2. LAYER 2: 2D OVERLAY FOREGROUND HUD LAYER (SHARP & UNWARPED)
                // -------------------------------------------------------------
                // Top HUD Navigation & Control Bar
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

                // Maya AI Host Floating Status Pill
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: OpponentPanel(
                      opponent: aiPlayer,
                      isThinking: !isHumanTurn && !isGameComplete,
                      difficultyLabel: tableState.aiDifficultyLabel,
                      isDealer: tableState.isAiDealer,
                      scoreText: '${tableState.totalAiScore} pts',
                      isHostOverlay: true,
                    ),
                  ),
                ),

                // Table Pot Banner directly below host pill
                Positioned(
                  top: 94,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                          const Text(
                            'TABLE POT',
                            style: TextStyle(
                              color: Color(0xFFD0C5AF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '🪙 1,200',
                            style: TextStyle(
                              color: Color(0xFFF2CA50),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF99907C),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Point: 10 pts',
                            style: TextStyle(
                              color: Color(0xFFDAE4ED),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Player 13-Card Hand Tray (Centered on Table Axis, Info Bar BELOW Cards)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: Center(
                    child: SizedBox(
                      width: 960,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerHand(
                            cardGroups: cardGroups,
                            wildJokerCard: notifier.effectiveHumanWildJoker,
                            selectedCard: tableState.selectedCard,
                            selectedCards: tableState.selectedCard != null ? {tableState.selectedCard!} : const <Card>{},
                            isDiscardPhase: isHumanTurn && isDiscardPhase,
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
                          const SizedBox(height: 4),
                          RoyalLifeChecklistBar(
                            hasFirstLife: notifier.hasHumanLife,
                            hasSecondLife: notifier.hasHumanSecondLife,
                            points: tableState.currentScore,
                            isMyTurn: isHumanTurn,
                            turnSeconds: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Left Action Controls: Drop (20), Sort Hand
                Positioned(
                  left: 48,
                  bottom: 14,
                  child: _buildLeftThumbControls(
                    context,
                    ref,
                    canDrop: canDrop,
                    dropPenalty: dropPenalty,
                    notifier: notifier,
                    isDesktop: true,
                    isTablet: false,
                  ),
                ),

                // Right Action Controls: Group, Discard, Declare Hand
                Positioned(
                  right: 48,
                  bottom: 14,
                  child: _buildRightThumbControls(
                    context,
                    ref,
                    notifier: notifier,
                    tableState: tableState,
                    canDiscard: canDiscard,
                    canDeclare: canDeclare,
                    isGameComplete: isGameComplete,
                    isTournamentOver: isTournamentOver,
                    nextDealNumber: nextDealNumber,
                    isDesktop: true,
                    isTablet: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameTableBackground(
        child: Stack(
          children: [
            SafeArea(
              child: mayaAiCanvas,
            ),

            // Card Animation Layer (Deals & discards flight)
            const Positioned.fill(
              child: CardAnimationLayer(),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3D Perspective Card Elements for Flat Table Surface ---
  static const double _tableCardW = 62.0;
  static const double _tableCardH = 88.0;

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
    const double jokerW = 52.0;
    const double jokerH = 74.0;

    return SizedBox(
      width: _tableCardW + 36.0,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // 1. Perpendicular Wild Joker tucked under the closed deck peeking to the left
          Positioned(
            left: 6,
            top: 7,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: GestureDetector(
                onTap: (!showJokerFace && hasLife) ? onOpenClosedJoker : null,
                child: Container(
                  width: jokerW,
                  height: jokerH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
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
                              showPulse: hasLife,
                            ),
                            Container(
                              padding: const EdgeInsets.all(5),
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
                                size: 14,
                                color: hasLife ? Colors.black : Colors.amber.shade200,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          // 2. Closed Deck Stack (Depth layers)
          Positioned(
            right: 3.0,
            top: 3.0,
            child: CardBackWidget(width: _tableCardW - 3.0, height: _tableCardH - 3.0),
          ),
          Positioned(
            right: 1.5,
            top: 1.5,
            child: CardBackWidget(width: _tableCardW - 1.5, height: _tableCardH - 1.5),
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
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.6),
                      blurRadius: canDraw ? 10 : 5,
                      spreadRadius: canDraw ? 2 : 0,
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

          // Deck count badge
          Positioned(
            top: 3.5,
            right: 3.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF2CA50), width: 0.8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // Draw Banner Hint
          if (canDraw)
            Positioned(
              top: -10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Text(
                  'DRAW',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerspectiveOpenPile({
    required BuildContext context,
    required Card? topCard,
    required Card? wildJoker,
    required bool canDraw,
    required VoidCallback onDraw,
    required VoidCallback onShowHistory,
    required String? lastDiscardFrom,
  }) {
    return SizedBox(
      width: _tableCardW,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: canDraw ? onDraw : null,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: canDraw
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.55),
                    blurRadius: canDraw ? 10 : 5,
                    spreadRadius: canDraw ? 2 : 0,
                  ),
                ],
              ),
              child: topCard != null
                  ? CardWidget(
                      card: topCard,
                      isWildJoker: JokerUtils.isWildJoker(topCard, wildJoker),
                      width: _tableCardW,
                      height: _tableCardH,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Center(
                        child: Text(
                          'EMPTY',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ),
                    ),
            ),
          ),
          // History Modal Button
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onShowHistory,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFBBF24), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 3,
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
          // "From: Maya" floating badge at the bottom of the card
          Positioned(
            bottom: -16,
            left: -24,
            right: -24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF222B32).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'From: ',
                      style: TextStyle(color: Color(0xFFD0C5AF), fontSize: 8.5),
                    ),
                    Text(
                      lastDiscardFrom ?? 'Maya',
                      style: const TextStyle(
                        color: Color(0xFFF2CA50),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
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

  Widget _buildPerspectiveFinishSlot({
    required BuildContext context,
    required bool canDeclare,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    final baseSlot = GestureDetector(
      onTap: canDeclare ? onDeclare : null,
      child: Container(
        width: _tableCardW,
        height: _tableCardH,
        decoration: BoxDecoration(
          color: canDeclare
              ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canDeclare ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B).withValues(alpha: 0.45),
            width: canDeclare ? 2.0 : 1.5,
          ),
          boxShadow: canDeclare
              ? [
                  BoxShadow(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                    blurRadius: 11,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: canDeclare ? const Color(0xFFFBBF24) : const Color(0xFFFBBF24).withValues(alpha: 0.65),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              'FINISH',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: canDeclare ? const Color(0xFFFDE68A) : Colors.white70,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              '14th Card',
              style: TextStyle(
                fontSize: 8.0,
                color: canDeclare ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );

    if (onCardDeclared != null) {
      return DragTarget<Object>(
        onWillAcceptWithDetails: (_) => canDeclare,
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
              border: isHovering ? Border.all(color: const Color(0xFF10B981), width: 2.0) : null,
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                        blurRadius: 11,
                      )
                    ]
                  : null,
            ),
            child: baseSlot,
          );
        },
      );
    }

    return baseSlot;
  }

  // --- Top HUD Bar ---
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
    final isTablet = Responsive.isTablet(context) || (size.width >= 768 && size.width < 1024);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final isMobileLandscape = !isPortrait && !isDesktop;
    final isLockedJoker = tableState.gameSettings.isClosedJoker &&
        tableState.gameSettings.jokerMode != 'OPEN' &&
        !tableState.hasHumanOpenedJoker;

    final authUser = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);
    final userCoins = authUser?.coins ?? homeState.coins;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 8,
        vertical: isDesktop ? 7 : 3.5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        border: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: isDesktop ? 36 : (isTablet ? 32 : 28),
              height: isDesktop ? 36 : (isTablet ? 32 : 28),
              decoration: const BoxDecoration(
                color: Color(0xFF182128),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                size: isDesktop ? 18 : 15,
                color: const Color(0xFFDAE4ED),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 10 : 6),

          // Brand Title
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

          // 6-Max Badge (hidden on mobile landscape to save horizontal space)
          if (isDesktop || size.width >= 880) ...[
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

          // Stake / Pool Badge
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

          // Mini Wild Joker Indicator Card Pill
          _buildMiniWildJokerPill(wildJoker, isLockedJoker, isDesktop: isDesktop),
          SizedBox(width: isDesktop ? 8 : 5),

          // Guidance Toast Pill
          Expanded(
            child: Center(
              child: _buildToastPill(
                toastMessage,
                isDesktop: isDesktop,
                onTap: isGameComplete
                    ? () {
                        if (isTournamentOver) {
                          notifier.resetTournament();
                        } else {
                          _checkTournamentStatus(context, ref);
                        }
                      }
                    : null,
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 5),

          // Available Coins Pill (User Virtual Coins)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : 8,
              vertical: isDesktop ? 6 : 3.5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF182128),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                width: 0.8,
              ),
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
                  '🪙',
                  style: TextStyle(fontSize: isDesktop ? 15 : 11),
                ),
                const SizedBox(width: 3),
                Text(
                  _formatCoins(userCoins),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: isDesktop ? 13 : 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF2CA50),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 5),

          // Drop Rules Pill (compact and conditionally shown)
          if (isDesktop || size.width >= 820) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 10 : 6,
                vertical: isDesktop ? 5 : 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF141D24),
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFD0C5AF),
                    fontSize: isDesktop ? 11 : 8.5,
                  ),
                  children: [
                    const TextSpan(text: 'D: '),
                    TextSpan(
                      text: '${tableState.gameSettings.firstDropPenalty}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFDAE4ED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '/'),
                    TextSpan(
                      text: '${tableState.gameSettings.middleDropPenalty}',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFDAE4ED),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 8 : 5),
          ],

          // Scorecard Button
          InkWell(
            onTap: () => _openScoreCard(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: isDesktop ? 36 : (isTablet ? 32 : 28),
              height: isDesktop ? 36 : (isTablet ? 32 : 28),
              decoration: const BoxDecoration(
                color: Color(0xFF182128),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: isDesktop ? 19 : 16, color: const Color(0xFFDAE4ED)),
            ),
          ),
          SizedBox(width: isDesktop ? 7 : 5),

          // Settings Button
          InkWell(
            onTap: () => _openSettings(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: isDesktop ? 36 : (isTablet ? 32 : 28),
              height: isDesktop ? 36 : (isTablet ? 32 : 28),
              decoration: const BoxDecoration(
                color: Color(0xFF182128),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_outlined, size: isDesktop ? 19 : 16, color: const Color(0xFFDAE4ED)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Mini Wild Joker Pill ---
  Widget _buildMiniWildJokerPill(Card? wildJoker, bool isLocked, {bool isDesktop = false}) {
    String rankStr = '7';
    String suitStr = '♠';
    bool isRed = false;

    if (wildJoker != null) {
      if (wildJoker.isPrintedJoker) {
        rankStr = 'JKR';
        suitStr = '★';
      } else {
        switch (wildJoker.rank) {
          case Rank.ace: rankStr = 'A'; break;
          case Rank.king: rankStr = 'K'; break;
          case Rank.queen: rankStr = 'Q'; break;
          case Rank.jack: rankStr = 'J'; break;
          case Rank.ten: rankStr = '10'; break;
          case Rank.nine: rankStr = '9'; break;
          case Rank.eight: rankStr = '8'; break;
          case Rank.seven: rankStr = '7'; break;
          case Rank.six: rankStr = '6'; break;
          case Rank.five: rankStr = '5'; break;
          case Rank.four: rankStr = '4'; break;
          case Rank.three: rankStr = '3'; break;
          case Rank.two: rankStr = '2'; break;
          default: rankStr = '7'; break;
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
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4, vertical: isDesktop ? 2 : 1),
              decoration: BoxDecoration(
                color: const Color(0xFF141D24),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: isDesktop ? 11 : 8.5, color: const Color(0xFFF2CA50)),
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
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 6 : 4, vertical: isDesktop ? 2 : 1),
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
                      color: isRed ? const Color(0xFFB91C1C) : const Color(0xFF141D24),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    suitStr,
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 9,
                      color: isRed ? const Color(0xFFB91C1C) : const Color(0xFF141D24),
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
    final size = MediaQuery.of(context).size;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isTablet = Responsive.isTablet(context) || (size.width >= 768 && size.width < 1024);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
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
              selectedCards: tableState.selectedCard != null ? {tableState.selectedCard!} : const <Card>{},
              isDiscardPhase: isHumanTurn && isDiscardPhase,
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
            const SizedBox(height: 2),
            RoyalLifeChecklistBar(
              hasFirstLife: notifier.hasHumanLife,
              hasSecondLife: notifier.hasHumanSecondLife,
              points: tableState.currentScore,
              isMyTurn: isHumanTurn,
              turnSeconds: 30,
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

              // Right Thumb Controls: Group, Discard, Declare (or Scorecard, Next Deal when complete)
              _buildRightThumbControls(
                context,
                ref,
                notifier: notifier,
                tableState: tableState,
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
            turnSeconds: 30,
          ),
        ],
      ),
    );
  }

  // --- Left Thumb Controls (Drop, Sort Hand) ---
  Widget _buildLeftThumbControls(
    BuildContext context,
    WidgetRef ref, {
    required bool canDrop,
    required int dropPenalty,
    required dynamic notifier,
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final double padH = isDesktop ? 16.0 : (isTablet ? 12.0 : 8.0);
    final double padV = isDesktop ? 10.0 : (isTablet ? 8.0 : 6.0);
    final double iconSize = isDesktop ? 17.0 : (isTablet ? 15.0 : 13.0);
    final double fontSize = isDesktop ? 13.0 : (isTablet ? 11.0 : 9.5);
    final double gap = isDesktop ? 8.0 : 5.0;

    return Padding(
      padding: EdgeInsets.only(right: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drop Button
          InkWell(
            onTap: canDrop ? () => _handleDrop(context, ref) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                color: canDrop
                    ? const Color(0xFF93000A).withValues(alpha: 0.85)
                    : const Color(0xFF141D24).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canDrop ? const Color(0xFFFFB4AB).withValues(alpha: 0.6) : Colors.white12,
                  width: 0.8,
                ),
                boxShadow: canDrop
                    ? [
                        BoxShadow(
                          color: const Color(0xFF93000A).withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: iconSize,
                    color: canDrop ? const Color(0xFFFFDAD6) : Colors.white24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Drop ($dropPenalty)',
                    style: GoogleFonts.outfit(
                      color: canDrop ? const Color(0xFFFFDAD6) : Colors.white30,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // Sort Hand / Auto Group Button
          InkWell(
            onTap: () => notifier.autoGroupHand(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                color: const Color(0xFF1C5338),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF33CA90).withValues(alpha: 0.6),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1C5338).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: iconSize, color: const Color(0xFF8DC5A2)),
                  const SizedBox(width: 4),
                  Text(
                    'Sort Hand',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF8DC5A2),
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

  // --- Right Thumb Controls (Group, Discard, Declare Hand OR Next Deal) ---
  Widget _buildRightThumbControls(
    BuildContext context,
    WidgetRef ref, {
    required dynamic notifier,
    required dynamic tableState,
    required bool canDiscard,
    required bool canDeclare,
    required bool isGameComplete,
    required bool isTournamentOver,
    required int nextDealNumber,
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final double padH = isDesktop ? 16.0 : (isTablet ? 11.0 : 7.0);
    final double padV = isDesktop ? 10.0 : (isTablet ? 8.0 : 6.0);
    final double iconSize = isDesktop ? 17.0 : (isTablet ? 14.0 : 12.0);
    final double fontSize = isDesktop ? 13.0 : (isTablet ? 11.0 : 9.5);
    final double declareFontSize = isDesktop ? 13.5 : (isTablet ? 11.5 : 10.0);
    final double declareIconSize = isDesktop ? 18.0 : (isTablet ? 15.0 : 13.0);
    final double declarePadH = isDesktop ? 22.0 : (isTablet ? 16.0 : 14.0);
    final double gap = isDesktop ? 8.0 : 5.0;

    if (isGameComplete) {
      return Padding(
        padding: EdgeInsets.only(left: isDesktop ? 10 : 6, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scorecard Button
            InkWell(
              onTap: () => _openScoreCard(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 18 : 10,
                  vertical: padV,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF182128),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF2CA50).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_chart_outlined, size: iconSize, color: const Color(0xFFF2CA50)),
                    const SizedBox(width: 4),
                    Text(
                      'Scorecard',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF2CA50),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: gap),

            // Deal Next Round Button
            InkWell(
              onTap: () {
                if (isTournamentOver) {
                  notifier.resetTournament();
                } else {
                  _checkTournamentStatus(context, ref);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 10,
                  vertical: padV,
                ),
                decoration: BoxDecoration(
                  gradient: isTournamentOver
                      ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF43F5E)])
                      : const LinearGradient(colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)]),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTournamentOver ? Icons.restart_alt_rounded : Icons.play_arrow_rounded,
                      size: iconSize + 1,
                      color: isTournamentOver ? Colors.white : const Color(0xFF241A00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTournamentOver ? 'New Tournament' : 'Deal Next Round (#$nextDealNumber)',
                      style: GoogleFonts.outfit(
                        color: isTournamentOver ? Colors.white : const Color(0xFF241A00),
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

    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Group + Discard
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group Button
              InkWell(
                onTap: () {
                  if (tableState.selectedCard != null) {
                    notifier.moveCardToNewGroup(tableState.selectedCard!, '');
                  } else {
                    notifier.autoGroupHand();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  decoration: BoxDecoration(
                    color: const Color(0xFF182128),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Text(
                    'Group',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFDAE4ED),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 6 : 4),

              // Discard Button
              InkWell(
                onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 18 : 9,
                    vertical: padV,
                  ),
                  decoration: BoxDecoration(
                    gradient: canDiscard
                        ? const LinearGradient(
                            colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)],
                          )
                        : null,
                    color: canDiscard ? null : const Color(0xFF141D24).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: canDiscard
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_rounded,
                        size: iconSize,
                        color: canDiscard ? const Color(0xFF241A00) : Colors.white24,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Discard',
                        style: GoogleFonts.outfit(
                          color: canDiscard ? const Color(0xFF241A00) : Colors.white30,
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
          SizedBox(height: gap),

          // Bottom: Declare Hand (or Submit Show) Full Width Button
          InkWell(
            onTap: canDeclare
                ? () {
                    if (tableState.isAwaitingHumanDeclarationShow) {
                      _handleSubmitDeclarationShow(context, ref);
                    } else {
                      _handleDiscardAndDeclare(context, ref);
                    }
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: declarePadH,
                vertical: padV,
              ),
              decoration: BoxDecoration(
                gradient: canDeclare
                    ? const LinearGradient(
                        colors: [Color(0xFF33CA90), Color(0xFF10B981)],
                      )
                    : null,
                color: canDeclare ? null : const Color(0xFF141D24).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                boxShadow: canDeclare
                    ? [
                        BoxShadow(
                          color: const Color(0xFF33CA90).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: declareIconSize,
                    color: canDeclare ? const Color(0xFF005035) : Colors.white24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tableState.isAwaitingHumanDeclarationShow ? 'Submit Show' : 'Declare Hand',
                    style: GoogleFonts.outfit(
                      color: canDeclare ? const Color(0xFF005035) : Colors.white30,
                      fontSize: declareFontSize,
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
        constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
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
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart_outlined, size: 14, color: AppColors.accent),
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
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: Color(0xFF00E5FF)),
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
                          color: (isTournamentOver ? const Color(0xFFE11D48) : const Color(0xFF10B981))
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
                          isTournamentOver ? Icons.restart_alt_rounded : Icons.play_arrow_rounded,
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
    final isTournamentOver = tableState.isHumanEliminated || tableState.isAiEliminated;

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
            // User closed to review table; Next Deal button is available on table!
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
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // User closed dialog to review table; Next Deal button is available on table!
                },
                child: const Text('Review Table'),
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
        final length = (distance + dash > metric.length) ? metric.length - distance : dash;
        dashPath.addPath(metric.extractPath(distance, distance + length), Offset.zero);
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
