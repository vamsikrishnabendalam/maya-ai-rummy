import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:ai_engine/ai_engine.dart';

void main() {
  group('AIPlayer', () {
    final aiPlayer = AIPlayer();
    final config = AIConfig.beginner();
    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);

    test('AI calculates next move correctly', () {
      final hand = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.jack, deckIndex: 0),
      ];

      final obs = AIObservation(
        hand: hand,
        discardPile: [Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0)],
        wildJoker: wildJoker,
        closedDeckRemaining: 80,
        turnNumber: 1,
        opponents: {},
        knownDeadCards: [],
      );

      final decision = aiPlayer.calculateNextMove(obs, config);
      expect(decision, isNotNull);
      expect(decision.discardCard, isNotNull);
      expect(hand.contains(decision.discardCard), isTrue);
    });
  });
}
