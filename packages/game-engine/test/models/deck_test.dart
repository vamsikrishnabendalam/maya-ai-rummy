import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  test('Deck initialization gives 106 cards', () {
    var deck = Deck.initialize(2, 42);
    expect(deck.length, equals(106));
  });

  test('Deck shuffle is deterministic', () {
    var deck1 = Deck.initialize(2, 42);
    var deck2 = Deck.initialize(2, 42);
    expect(deck1.cards.first, equals(deck2.cards.first));
  });
}
