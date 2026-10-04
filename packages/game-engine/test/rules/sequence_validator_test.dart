import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  final openJoker = Card(suit: Suit.diamonds, rank: Rank.three, deckIndex: 0);
  final printedJoker = Card(deckIndex: 0, isPrintedJoker: true);

  group('SequenceValidator', () {
    test('Pure sequence: A-2-3 (Ace-low)', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.pure));
    });

    test('Pure sequence: Q-K-A (Ace-high)', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.pure));
    });

    test('Pure sequence: 4-5-6-7 (Length 4)', () {
      final cards = [
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.pure));
    });

    test('Invalid wraparound sequence: K-A-2 is strictly invalid', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isFalse);
    });

    test('Invalid sequence: Q-A-K out of order or disjoint', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isFalse);
    });

    test('Impure sequence: 4-5-Joker (Printed Joker)', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        printedJoker,
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.impure));
    });

    test('Impure sequence: Q-K + Open Joker as Ace (CRITICAL BUG FIX)', () {
      // Open joker is 3 of diamonds (so any 3 is a wildcard)
      final wildThree = Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0);
      final cards = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        wildThree,
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.impure));
      expect(res.missingCards.any((c) => c.rank == Rank.ace || c.rank == Rank.jack), isTrue);
    });

    test('Impure sequence: Q + Open Joker + A (Joker as King)', () {
      final wildThree = Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0);
      final cards = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        wildThree,
        Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.impure));
      expect(res.missingCards.first.rank, equals(Rank.king));
    });

    test('Impure sequence: Joker + K + A (Joker as Queen)', () {
      final wildThree = Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0);
      final cards = [
        wildThree,
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
      ];
      final res = SequenceValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.type, equals(SequenceType.impure));
      expect(res.missingCards.first.rank, equals(Rank.queen));
    });
  });

  group('SetValidator', () {
    test('Valid 3-card pure set: 7H 7C 7D', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0),
      ];
      final res = SetValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.isImpure, isFalse);
    });

    test('Valid 4-card pure set: KH KC KS KD', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
      ];
      final res = SetValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.isImpure, isFalse);
    });

    test('Valid impure set with Open Joker: 7H 7C + Open Joker', () {
      final wildThree = Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0);
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        wildThree,
      ];
      final res = SetValidator.validate(cards, openJoker);
      expect(res.isValid, isTrue);
      expect(res.isImpure, isTrue);
    });

    test('Invalid set: duplicate same suit 7H 7H 7C', () {
      final cards = [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 1),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
      ];
      final res = SetValidator.validate(cards, openJoker);
      expect(res.isValid, isFalse);
    });

    test('Invalid set: duplicate same suit with wild joker (e.g. 6D, KH wild, 6S, 6S)', () {
      final wildKing = Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0);
      final cards = [
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0),
        wildKing,
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 1),
      ];
      final res = SetValidator.validate(cards, wildKing);
      expect(res.isValid, isFalse);
      expect(res.reason, contains('cannot contain duplicate cards of the same suit'));
    });
  });

  group('HandPartitioner & DeclarationValidator', () {
    final validator = DeclarationValidator();

    test('Valid declaration: 1 pure sequence + 1 impure sequence (Q-K-A with Joker) + 2 sets', () {
      final pureSeq = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ];
      // Impure Q-K-A with Open Joker!
      final wildThree = Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0);
      final impureSeq = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        wildThree,
      ];
      final set1 = [
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
      ];
      final set2 = [
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0),
      ];

      final groups = [pureSeq, impureSeq, set1, set2];
      final result = validator.validate(groups, openJoker);
      expect(result.isValid, isTrue);
      expect(result.penaltyScore, equals(0));
    });

    test('Invalid declaration: missing pure sequence', () {
      final wildThree = Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0);
      final impure1 = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        wildThree,
      ];
      final impure2 = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        printedJoker,
      ];
      final set1 = [
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
      ];
      final set2 = [
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0),
      ];

      final groups = [impure1, impure2, set1, set2];
      final result = validator.validate(groups, openJoker);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('pure sequence'));
    });

    test('Invalid declaration: 12 valid cards + 1 unmatched card', () {
      final pureSeq = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ];
      final pureSeq2 = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
      ];
      final set1 = [
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
      ];
      final set2 = [
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
      ];
      final unmatched = [
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0),
      ];

      final groups = [pureSeq, pureSeq2, set1, set2, unmatched];
      final result = validator.validate(groups, openJoker);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('card(s) are not part of any valid group'));
    });
  });
}
