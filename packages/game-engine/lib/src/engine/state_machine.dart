import '../models/game_state.dart';
import '../models/game_action.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../rules/declaration_validator.dart';
import '../rules/scoring.dart';

class StateMachine {
  static GameState process(GameState state, GameAction action) {
    if (state.phase == GamePhase.COMPLETE) {
      throw StateError('Game is already complete');
    }

    if (action.playerId != state.currentPlayerId) {
      throw StateError('Not player\'s turn');
    }

    if (action is DrawFromClosedDeck) {
      if (state.phase != GamePhase.DRAW_PHASE) throw StateError('Not in draw phase');
      var card = state.closedDeck.removeLast();
      var p = state.players.firstWhere((p) => p.id == action.playerId);
      p.hand.add(card);
      return state.copyWith(
        phase: GamePhase.DISCARD_PHASE,
        closedDeck: state.closedDeck,
        players: state.players,
        clearCardDrawnFromOpenThisTurn: true,
      );
    } 
    
    if (action is DrawFromOpenDeck) {
      if (state.phase != GamePhase.DRAW_PHASE) throw StateError('Not in draw phase');
      if (state.openPile.isEmpty) throw StateError('Open pile is empty');
      var card = state.openPile.removeLast();
      var p = state.players.firstWhere((p) => p.id == action.playerId);
      p.hand.add(card);
      return state.copyWith(
        phase: GamePhase.DISCARD_PHASE,
        openPile: state.openPile,
        players: state.players,
        cardDrawnFromOpenThisTurn: card,
      );
    }

    if (action is DiscardCard) {
      if (state.phase != GamePhase.DISCARD_PHASE) throw StateError('Not in discard phase');
      if (state.cardDrawnFromOpenThisTurn != null && state.cardDrawnFromOpenThisTurn == action.card) {
        throw StateError('Cannot discard the card drawn from the open pile in the same turn');
      }
      var p = state.players.firstWhere((p) => p.id == action.playerId);
      if (!p.hand.contains(action.card)) throw StateError('Card not in hand');
      p.hand.remove(action.card);
      state.openPile.add(action.card);
      
      int nextIdx = (state.currentPlayerIndex + 1) % state.players.length;
      return state.copyWith(
        phase: GamePhase.DRAW_PHASE,
        currentPlayerIndex: nextIdx,
        turnNumber: state.turnNumber + 1,
        players: state.players,
        openPile: state.openPile,
        clearCardDrawnFromOpenThisTurn: true,
      );
    }

    if (action is DeclareHand) {
      final declaringPlayer = state.players.firstWhere((p) => p.id == action.playerId);
      final wildJoker = state.wildJoker ?? Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);

      final valResult = DeclarationValidator().validate(action.groups, wildJoker);

      if (valResult.isValid) {
        declaringPlayer.score = 0;
        declaringPlayer.status = PlayerStatus.DECLARED;

        // Calculate scores for remaining players
        for (final p in state.players) {
          if (p.id != declaringPlayer.id && p.status == PlayerStatus.ACTIVE) {
            p.score = Scoring.calculateDeadwood(p.hand, wildJoker);
          }
        }

        return state.copyWith(
          phase: GamePhase.COMPLETE,
          players: state.players,
        );
      } else {
        // Invalid declaration penalty
        declaringPlayer.score = valResult.penaltyScore;
        // Turn passes to next player
        int nextIdx = (state.currentPlayerIndex + 1) % state.players.length;
        return state.copyWith(
          phase: GamePhase.DRAW_PHASE,
          currentPlayerIndex: nextIdx,
          turnNumber: state.turnNumber + 1,
          players: state.players,
        );
      }
    }

    if (action is DropGame) {
      final droppingPlayer = state.players.firstWhere((p) => p.id == action.playerId);
      droppingPlayer.status = PlayerStatus.DROPPED;
      droppingPlayer.score = action.type == DropType.FIRST_DROP ? 20 : 40;

      final activePlayers = state.players.where((p) => p.status == PlayerStatus.ACTIVE).toList();
      if (activePlayers.length <= 1) {
        if (activePlayers.isNotEmpty) {
          activePlayers.first.score = 0;
        }
        return state.copyWith(
          phase: GamePhase.COMPLETE,
          players: state.players,
        );
      }

      int nextIdx = (state.currentPlayerIndex + 1) % state.players.length;
      return state.copyWith(
        phase: GamePhase.DRAW_PHASE,
        currentPlayerIndex: nextIdx,
        turnNumber: state.turnNumber + 1,
        players: state.players,
      );
    }

    return state;
  }
}
