import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../../providers/game_ui_provider.dart';
import '../widgets/game_table_background.dart';
import '../widgets/opponent_panel.dart';
import '../widgets/center_table.dart';
import '../widgets/player_hand.dart';
import '../widgets/declaration_result_modal.dart';
import '../widgets/score_card_modal.dart';
import '../widgets/game_settings_modal.dart';
import '../widgets/card_animation_layer.dart';
import '../widgets/royal_rummy_oval_table.dart';
import '../widgets/royal_life_checklist_bar.dart';

/// The main game table screen — assembles all gameplay, manual discard,
/// grouping suggestions, declaration, settings, and tournament scorecard
/// with full Mobile Landscape and Portrait responsive support.
class GameTableScreen extends ConsumerWidget {
  const GameTableScreen({Key? key}) : super(key: key);

  String _computeToastMessage({
    required bool isHumanTurn,
    required bool isDrawPhase,
    required bool isDiscardPhase,
    required bool isGameComplete,
    required bool hasSelectedCard,
    required bool isAwaitingDeclarationShow,
    required bool isWinningDeclaration,
  }) {
    if (isGameComplete) return 'Round completed! Check results.';
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

  Widget _buildToastPill(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final toastMessage = _computeToastMessage(
      isHumanTurn: isHumanTurn,
      isDrawPhase: isDrawPhase,
      isDiscardPhase: isDiscardPhase,
      isGameComplete: isGameComplete,
      hasSelectedCard: tableState.selectedCard != null,
      isAwaitingDeclarationShow: tableState.isAwaitingHumanDeclarationShow,
      isWinningDeclaration: notifier.remainingCardsFormValidDeclaration,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF05080F),
      body: GameTableBackground(
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // --- 1. Compact Top Navigation Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        // Home Back Button
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
                                Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 12),
                                SizedBox(width: 4),
                                Text('Home', style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),

                        // Royal 13 Branding
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'ROYAL 13',
                                style: TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Pool Mode Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${tableState.gameSettings.eliminationScore} POOL',
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Landscape Toast Guidance Pill
                        if (isLandscape) ...[
                          const Spacer(),
                          _buildToastPill(toastMessage),
                        ],

                        const Spacer(),

                        // Scorecard Button
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
                                Icon(Icons.table_chart_outlined, color: AppColors.accent, size: 14),
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
                        const SizedBox(width: 6),

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
                            child: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Portrait Toast Guidance Banner
                  if (!isLandscape)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _buildToastPill(toastMessage),
                    ),

                  // --- 2. Main Arena (Table, Opponent, Decks, Thumb-Zones) ---
                  Expanded(
                    child: Stack(
                      children: [
                        // Center 2.5D Royal Oval Table
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLandscape ? 40.0 : 8.0,
                              vertical: 2.0,
                            ),
                            child: RoyalRummyOvalTable(
                              isPortrait: !isLandscape,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Opponent Maya Bot
                                  OpponentPanel(
                                    opponent: aiPlayer,
                                    isThinking: !isHumanTurn && !isGameComplete,
                                    difficultyLabel: tableState.aiDifficultyLabel,
                                    isDealer: tableState.isAiDealer,
                                  ),
                                  const SizedBox(height: 2),

                                  // Center Decks: Closed + Perpendicular Wild Joker, Open + History, Finish Slot
                                  Expanded(
                                    child: Center(
                                      child: CenterTable(
                                        closedDeckCount: gameState.closedDeck.length,
                                        openPile: gameState.openPile,
                                        wildJoker: wildJoker,
                                        isClosedJoker: tableState.gameSettings.isClosedJoker,
                                        isJokerOpened: tableState.gameSettings.jokerMode == 'OPEN' || tableState.hasHumanOpenedJoker,
                                        hasLife: notifier.hasHumanLife,
                                        onOpenClosedJoker: () => notifier.openClosedJoker(),
                                        canDraw: isHumanTurn && isDrawPhase,
                                        onDrawClosed: () => notifier.drawFromClosedDeck(),
                                        onDrawOpen: () => notifier.drawFromOpenDeck(),
                                        canDeclare: canDeclare,
                                        onDeclare: canDeclare ? () {
                                          if (tableState.isAwaitingHumanDeclarationShow) {
                                            _handleSubmitDeclarationShow(context, ref);
                                          } else {
                                            _handleDiscardAndDeclare(context, ref);
                                          }
                                        } : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- Landscape Left Thumb-Zone (Drop, Auto Group) ---
                        if (isLandscape)
                          Positioned(
                            left: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Drop Button
                                  InkWell(
                                    onTap: canDrop ? () => _handleDrop(context, ref) : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: canDrop
                                            ? const Color(0xFF3E0A16).withValues(alpha: 0.95)
                                            : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: canDrop ? const Color(0xFFF43F5E) : Colors.white12,
                                        ),
                                        boxShadow: canDrop
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.flag_rounded,
                                            size: 16,
                                            color: canDrop ? const Color(0xFFFDA4AF) : Colors.white24,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Drop',
                                            style: TextStyle(
                                              color: canDrop ? const Color(0xFFFDA4AF) : Colors.white30,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$dropPenalty pt',
                                            style: TextStyle(
                                              color: canDrop ? const Color(0xFFFDA4AF).withValues(alpha: 0.7) : Colors.white24,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Auto Group Button
                                  InkWell(
                                    onTap: () => notifier.autoGroupHand(),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF042F2E).withValues(alpha: 0.95),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFF00E5FF)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, size: 16, color: Color(0xFF00E5FF)),
                                          SizedBox(height: 2),
                                          Text(
                                            'Auto',
                                            style: TextStyle(
                                              color: Color(0xFF00E5FF),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            'Group',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 8,
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
                          ),

                        // --- Landscape Right Thumb-Zone (Discard, Declare) ---
                        if (isLandscape)
                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Discard Button
                                  InkWell(
                                    onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        gradient: canDiscard
                                            ? const LinearGradient(
                                                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                              )
                                            : null,
                                        color: canDiscard ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: canDiscard ? const Color(0xFFFDE68A) : Colors.white12,
                                        ),
                                        boxShadow: canDiscard
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                                  blurRadius: 10,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.send_rounded,
                                            size: 16,
                                            color: canDiscard ? Colors.black : Colors.white24,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Discard',
                                            style: TextStyle(
                                              color: canDiscard ? Colors.black : Colors.white30,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Declare / Show Button
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
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        gradient: canDeclare
                                            ? const LinearGradient(
                                                colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                                              )
                                            : null,
                                        color: canDeclare ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: canDeclare ? const Color(0xFFA7F3D0) : Colors.white12,
                                        ),
                                        boxShadow: canDeclare
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                                  blurRadius: 12,
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.emoji_events_rounded,
                                            size: 16,
                                            color: canDeclare ? Colors.black : Colors.white24,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            tableState.isAwaitingHumanDeclarationShow ? 'Submit' : 'Declare',
                                            style: TextStyle(
                                              color: canDeclare ? Colors.black : Colors.white30,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- 3. Portrait 4-Button Action Grid (Drop, Auto Group, Discard, Declare) ---
                  if (!isLandscape)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      child: Row(
                        children: [
                          // Drop
                          Expanded(
                            child: InkWell(
                              onTap: canDrop ? () => _handleDrop(context, ref) : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: canDrop
                                      ? const Color(0xFF3E0A16)
                                      : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: canDrop ? const Color(0xFFF43F5E) : Colors.white12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.flag_rounded, size: 13, color: canDrop ? const Color(0xFFFDA4AF) : Colors.white24),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Drop ($dropPenalty)',
                                      style: TextStyle(
                                        color: canDrop ? const Color(0xFFFDA4AF) : Colors.white30,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Auto Group
                          Expanded(
                            child: InkWell(
                              onTap: () => notifier.autoGroupHand(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF042F2E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF00E5FF)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 13, color: Color(0xFF00E5FF)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Auto Group',
                                      style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Discard
                          Expanded(
                            child: InkWell(
                              onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: canDiscard
                                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
                                      : null,
                                  color: canDiscard ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: canDiscard ? const Color(0xFFFDE68A) : Colors.white12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 13, color: canDiscard ? Colors.black : Colors.white24),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Discard',
                                      style: TextStyle(
                                        color: canDiscard ? Colors.black : Colors.white30,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // Declare / Submit
                          Expanded(
                            child: InkWell(
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
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: canDeclare
                                      ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF14B8A6)])
                                      : null,
                                  color: canDeclare ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: canDeclare ? const Color(0xFFA7F3D0) : Colors.white12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.emoji_events_rounded, size: 13, color: canDeclare ? Colors.black : Colors.white24),
                                    const SizedBox(width: 4),
                                    Text(
                                      tableState.isAwaitingHumanDeclarationShow ? 'Submit' : 'Declare',
                                      style: TextStyle(
                                        color: canDeclare ? Colors.black : Colors.white30,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
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

                  // --- 4. Royal Life Checklist & Points Bar ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: RoyalLifeChecklistBar(
                      hasFirstLife: notifier.hasHumanLife,
                      hasSecondLife: notifier.hasHumanSecondLife,
                      points: tableState.currentScore,
                      isMyTurn: isHumanTurn,
                      turnSeconds: 30,
                    ),
                  ),

                  // --- 5. Touch-Friendly Player Hand with Royal Ribbons ---
                  PlayerHand(
                    cardGroups: cardGroups,
                    wildJokerCard: notifier.effectiveHumanWildJoker,
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
                  const SizedBox(height: 6),
                ],
              ),
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
