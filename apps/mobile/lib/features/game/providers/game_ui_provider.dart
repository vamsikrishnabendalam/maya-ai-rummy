import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart' show Card;

/// Types of game actions for animation triggers
enum GameActionType {
  none,
  dealing,
  drewFromClosed,
  drewFromOpen,
  discarded,
  sorted,
  grouped,
  declared,
  botDrew,
  botDiscarded,
}

/// Phases of the discard/draw animation
enum AnimationPhase {
  idle,
  cardFlying,
  cardLanding,
  complete,
}

/// UI-only state for the game table — drag/drop, animations, selections.
/// Kept separate from game logic to avoid unnecessary rebuilds.
class GameUIState {
  final bool isDragging;
  final Card? draggedCard;
  final String? draggedFromGroupId;
  final String? hoveredGroupId;
  final bool showDiscardZone;
  final bool showDeclareConfirm;
  final GameActionType lastAction;
  final AnimationPhase animationPhase;
  final Card? animatingCard;
  final int? newCardIndex;

  const GameUIState({
    this.isDragging = false,
    this.draggedCard,
    this.draggedFromGroupId,
    this.hoveredGroupId,
    this.showDiscardZone = false,
    this.showDeclareConfirm = false,
    this.lastAction = GameActionType.none,
    this.animationPhase = AnimationPhase.idle,
    this.animatingCard,
    this.newCardIndex,
  });

  GameUIState copyWith({
    bool? isDragging,
    Card? draggedCard,
    String? draggedFromGroupId,
    String? hoveredGroupId,
    bool? showDiscardZone,
    bool? showDeclareConfirm,
    GameActionType? lastAction,
    AnimationPhase? animationPhase,
    Card? animatingCard,
    int? newCardIndex,
  }) {
    return GameUIState(
      isDragging: isDragging ?? this.isDragging,
      draggedCard: draggedCard ?? this.draggedCard,
      draggedFromGroupId: draggedFromGroupId ?? this.draggedFromGroupId,
      hoveredGroupId: hoveredGroupId ?? this.hoveredGroupId,
      showDiscardZone: showDiscardZone ?? this.showDiscardZone,
      showDeclareConfirm: showDeclareConfirm ?? this.showDeclareConfirm,
      lastAction: lastAction ?? this.lastAction,
      animationPhase: animationPhase ?? this.animationPhase,
      animatingCard: animatingCard ?? this.animatingCard,
      newCardIndex: newCardIndex ?? this.newCardIndex,
    );
  }

  /// Reset to idle state
  GameUIState reset() => const GameUIState();
}

/// Notifier for UI-only state changes.
class GameUINotifier extends StateNotifier<GameUIState> {
  GameUINotifier() : super(const GameUIState());

  void startDrag(Card card, String fromGroupId) {
    state = state.copyWith(
      isDragging: true,
      draggedCard: card,
      draggedFromGroupId: fromGroupId,
      showDiscardZone: true,
    );
  }

  void updateHoveredGroup(String? groupId) {
    state = state.copyWith(hoveredGroupId: groupId);
  }

  void endDrag() {
    state = GameUIState(
      lastAction: state.lastAction,
    );
  }

  void triggerAction(GameActionType action, {Card? card}) {
    state = state.copyWith(
      lastAction: action,
      animationPhase: AnimationPhase.cardFlying,
      animatingCard: card,
    );

    // Auto-advance animation phase after delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (state.animationPhase == AnimationPhase.cardFlying) {
        state = state.copyWith(animationPhase: AnimationPhase.cardLanding);
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (state.animationPhase == AnimationPhase.cardLanding) {
        state = state.copyWith(
          animationPhase: AnimationPhase.idle,
          lastAction: GameActionType.none,
        );
      }
    });
  }

  void setNewCardIndex(int index) {
    state = state.copyWith(newCardIndex: index);
    // Clear highlight after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (state.newCardIndex == index) {
        state = state.copyWith(newCardIndex: -1);
      }
    });
  }

  void showDeclareDialog() {
    state = state.copyWith(showDeclareConfirm: true);
  }

  void hideDeclareDialog() {
    state = state.copyWith(showDeclareConfirm: false);
  }

  void resetUI() {
    state = const GameUIState();
  }
}

/// Provider for game UI state.
final gameUIProvider =
    StateNotifierProvider<GameUINotifier, GameUIState>((ref) {
  return GameUINotifier();
});
