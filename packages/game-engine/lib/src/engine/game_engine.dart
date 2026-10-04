import '../models/game_config.dart';
import '../models/game_state.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_action.dart';
import 'state_machine.dart';

class GameEngine {
  GameState createGame(GameConfig config, int seed) {
    var deck = Deck.initialize(config.deckCount, seed);
    List<Player> players = [];
    for (int i = 0; i < config.maxPlayers; i++) {
      players.add(Player(id: 'p$i'));
    }

    // Deal cards
    for (int i = 0; i < 13; i++) {
      for (var p in players) {
        p.hand.add(deck.draw());
      }
    }

    var openPile = [deck.draw()];
    var wildJoker = deck.draw();

    return GameState(
      gameId: config.gameId,
      players: players,
      openPile: openPile,
      closedDeck: deck.cards,
      wildJoker: wildJoker,
      currentPlayerIndex: 0,
      phase: GamePhase.DRAW_PHASE,
    );
  }

  GameState processAction(GameState state, GameAction action) {
    return StateMachine.process(state, action);
  }

  GameState getPlayerView(GameState state, String playerId) {
    var playersCopy = state.players.map((p) {
      if (p.id == playerId) return p;
      return Player(id: p.id, hand: [], score: p.score, status: p.status);
    }).toList();
    return state.copyWith(players: playersCopy, closedDeck: []);
  }
}
