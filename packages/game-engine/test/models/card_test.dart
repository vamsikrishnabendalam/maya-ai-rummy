import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  test('Card equality', () {
    var c1 = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
    var c2 = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
    expect(c1, equals(c2));
  });

  test('Card serialization', () {
    var c1 = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
    var json = c1.toJson();
    var c2 = Card.fromJson(json);
    expect(c1, equals(c2));
  });
}
