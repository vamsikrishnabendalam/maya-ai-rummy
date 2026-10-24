import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  test('Deck initialization gives 54 cards for 1 deck, 108 cards for 2 decks', () {
    var deck1 = Deck.initialize(1, 42);
    expect(deck1.length, equals(54));
    var deck2 = Deck.initialize(2, 42);
    expect(deck2.length, equals(108));
  });

  test('Deck shuffle is deterministic', () {
    var deck1 = Deck.initialize(2, 42);
    var deck2 = Deck.initialize(2, 42);
    expect(deck1.cards.first, equals(deck2.cards.first));
  });
}
