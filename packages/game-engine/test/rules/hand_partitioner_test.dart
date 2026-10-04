import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:game_engine/src/rules/hand_partitioner.dart';

void main() {
  group('HandPartitioner.findBestPartition', () {
    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0);

    test('Strict Invariant: Total cards across all groups equals input hand length exactly', () {
      final hand = [
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0), // Pure seq
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0), // Set with wild joker
        Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
      ];

      expect(hand.length, equals(13));

      final partition = HandPartitioner.findBestPartition(hand, wildJoker);

      final totalCardsInGroups = partition.groups.fold<int>(0, (sum, g) => sum + g.cards.length);
      expect(totalCardsInGroups, equals(13), reason: 'Must have exactly 13 cards across all groups, no duplicates');

      final flattenedCards = partition.groups.expand((g) => g.cards).toList();
      for (final card in hand) {
        expect(flattenedCards.where((c) => c == card).length, equals(1),
            reason: 'Card $card should appear exactly once');
      }
    });

    test('No melds possible: all 13 cards partitioned into deadwood without duplication', () {
      final hand = [
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0),
      ];

      expect(hand.length, equals(13));

      final partition = HandPartitioner.findBestPartition(hand, null);
      final totalCardsInGroups = partition.groups.fold<int>(0, (sum, g) => sum + g.cards.length);
      expect(totalCardsInGroups, equals(13));
    });

    test('14 cards (after drawing, before discard): all 14 cards preserved without duplication', () {
      final hand = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0),
      ];

      expect(hand.length, equals(14));

      final partition = HandPartitioner.findBestPartition(hand, wildJoker);
      final totalCardsInGroups = partition.groups.fold<int>(0, (sum, g) => sum + g.cards.length);
      expect(totalCardsInGroups, equals(14));
    });

    test('Optimal Joker Rearrangement: Joker assigned to high-value meld to minimize deadwood', () {
      final wildJoker = Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0);
      final hand = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0), // Pure seq
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0), // High pair: 20 pts
        Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0),  // Low pair: 5 pts
        wildJoker,                                             // Wild Joker
        Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0), // 7 pts
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),    // 9 pts
        Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),     // 10 pts
        Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),  // 10 pts
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),    // 7 pts
      ];

      expect(hand.length, equals(13));

      final partition = HandPartitioner.findBestPartition(hand, wildJoker);

      // If Joker was placed with 2♣ 3♣: deadwood would be 63 pts.
      // Because Joker is placed with K♠ Q♠: deadwood is 48 pts!
      expect(partition.penaltyScore, equals(48),
          reason: 'Joker must be placed with high-value cards K♠ Q♠ to save 20 pts instead of 5 pts');

      final jokerGroup = partition.groups.firstWhere((g) => g.cards.contains(wildJoker));
      expect(jokerGroup.cards.any((c) => c.rank == Rank.king), isTrue);
      expect(jokerGroup.cards.any((c) => c.rank == Rank.queen), isTrue);
    });
  });

  group('Scoring.calculateHandDeadwood', () {
    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0);

    test('Winning hand (pure seq + impure seq + 2 sets) scores exactly 0', () {
      final groups = [
        [
          Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        ], // pure sequence (0 pts)
        [
          Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0), // wild joker
        ], // impure sequence (0 pts)
        [
          Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
        ], // set (0 pts)
        [
          Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
        ], // set (0 pts)
      ];

      final score = Scoring.calculateHandDeadwood(groups: groups, wildJoker: wildJoker);
      expect(score, equals(0));
    });

    test('1 pure sequence exempts pure seq, remaining deadwood cards are scored accurately', () {
      final groups = [
        [
          Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        ], // pure sequence -> EXEMPT (0 pts)
        [
          Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0), // 2 pts
          Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0), // 3 pts
        ],
        [
          Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0), // 10 pts
        ],
      ];

      // Total expected = 2 + 3 + 10 = 15 points
      final score = Scoring.calculateHandDeadwood(groups: groups, wildJoker: wildJoker);
      expect(score, equals(15));
    });

    test('No pure sequence: all cards count as deadwood, capped at maxPenalty', () {
      final groups = [
        [
          Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0), // 10
          Card(suit: Suit.hearts, rank: Rank.jack, deckIndex: 0), // 10
          Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0), // 10
          Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0), // 10
          Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0), // 10
          Card(suit: Suit.clubs, rank: Rank.ace, deckIndex: 0), // 10
          Card(suit: Suit.diamonds, rank: Rank.ace, deckIndex: 0), // 10
          Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0), // 10
          Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0), // 9
        ],
      ];

      // Sum is 89, capped at 80
      final score = Scoring.calculateHandDeadwood(groups: groups, wildJoker: wildJoker, maxPenalty: 80);
      expect(score, equals(80));
    });

    test('2 sequences exempt both sequences, only invalid cards are scored', () {
      final groups = [
        [
          Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        ], // Pure sequence -> exempt
        [
          Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0), // wild joker
        ], // Impure sequence -> exempt
        [
          Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0), // 2 pts
          Card(suit: Suit.diamonds, rank: Rank.three, deckIndex: 0), // 3 pts
        ],
      ];

      // 2 + 3 = 5 points
      final score = Scoring.calculateHandDeadwood(groups: groups, wildJoker: wildJoker);
      expect(score, equals(5));
    });

    test('Combinatorial Stress Test: 14 cards with 5 jokers completes in < 50ms without freeze', () {
      final openWildJoker = Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0);
      final stressHand = [
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0), // Wild Joker 1
        Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 1), // Wild Joker 2
        Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0), // Wild Joker 3
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 1), // Wild Joker 4
        Card(deckIndex: 0, isPrintedJoker: true), // Printed Joker 5
        Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
      ];

      expect(stressHand.length, equals(14));

      final stopwatch = Stopwatch()..start();
      final partition = HandPartitioner.findBestPartition(stressHand, openWildJoker);
      stopwatch.stop();

      // Must complete in under 50ms (typically < 3ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));

      final totalCardsInGroups = partition.groups.fold<int>(0, (sum, g) => sum + g.cards.length);
      expect(totalCardsInGroups, equals(14));
    });

    test('Set of 5 cards with 3 wild jokers is recognized and remains grouped as a valid set', () {
      final wildJoker = Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);
      final setOf5Cards = [
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0), // Wild Joker 1
        Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0), // Wild Joker 2
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0), // Wild Joker 3
      ];

      // 1. Direct validation via SetValidator
      final setValidation = SetValidator.validate(setOf5Cards, wildJoker);
      expect(setValidation.isValid, isTrue, reason: 'Set of 5 cards with 3 wild jokers must be valid');

      // 2. Evaluation via HandPartitioner.evaluateGroups
      final eval = HandPartitioner.evaluateGroups([setOf5Cards], wildJoker);
      expect(eval.groups.first.isValid, isTrue);
      expect(eval.groups.first.type, equals(HandGroupType.validSet));
      expect(eval.groups.first.cards.length, equals(5));

      // 3. Complete hand containing pure sequence, second sequence, and the 5-card set
      final hand = [
        // Pure sequence (4 cards)
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
        // Second sequence (4 cards)
        Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        // Set of 5 cards with 3 wild jokers
        ...setOf5Cards,
      ];
      expect(hand.length, equals(13));

      final bestPartition = HandPartitioner.findBestPartition(hand, wildJoker);
      final foundSet = bestPartition.groups.where((g) => g.type == HandGroupType.validSet).toList();
      expect(foundSet.isNotEmpty, isTrue);
      expect(foundSet.any((g) => g.cards.length == 5), isTrue,
          reason: 'Set of 5 cards with 3 wild jokers must not be broken into ungrouped deadwood');
    });
  });
}

