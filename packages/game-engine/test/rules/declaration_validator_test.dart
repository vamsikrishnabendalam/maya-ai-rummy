import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  group('DeclarationValidator', () {
    final validator = DeclarationValidator();
    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);

    test('Valid declaration with 1 pure sequence, 1 impure sequence, and 2 sets', () {
      final pureSeq = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ];
      final impureSeq = [
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0), // Wild Joker
      ];
      final set1 = [
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
      ];
      final set2 = [
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
      ];

      final groups = [pureSeq, impureSeq, set1, set2];
      final result = validator.validate(groups, wildJoker);
      expect(result.isValid, isTrue);
      expect(result.penaltyScore, equals(0));
    });

    test('Invalid declaration when missing pure sequence', () {
      final impureSeq1 = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0),
      ];
      final impureSeq2 = [
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(isPrintedJoker: true, deckIndex: 0),
      ];
      final set1 = [
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
      ];
      final set2 = [
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
      ];

      final groups = [impureSeq1, impureSeq2, set1, set2];
      final result = validator.validate(groups, wildJoker);
      expect(result.isValid, isFalse);
      expect(result.penaltyScore, equals(80));
    });

    test('Valid set of 5 cards containing 3 wild jokers (4C 4H 5D 5C 5S where 5 is wild)', () {
      final wild5H = Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0);
      final setOf5 = [
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0), // Wild Joker
        Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),    // Wild Joker
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),   // Wild Joker
      ];
      final res = SetValidator.validate(setOf5, wild5H);
      expect(res.isValid, isTrue);
      expect(res.isImpure, isTrue);
    });

    test('Invalid set: duplicate same suit in impure set (4C 4C 5D where 5 is wild)', () {
      final wild5H = Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0);
      final invalidSet = [
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 1),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
      ];
      final res = SetValidator.validate(invalidSet, wild5H);
      expect(res.isValid, isFalse);
    });
  });
}
