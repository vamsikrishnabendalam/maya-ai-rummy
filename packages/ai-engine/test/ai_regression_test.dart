import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:ai_engine/ai_engine.dart';

void main() {
  group('AI Engine Regression & Rule Compliance Tests', () {
    final strategyEngine = BotStrategyEngine();
    final threatTracker = OpponentThreatTracker();
    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);

    test('1. 6-7-8 Bug: Bot holding 7♥, 8♥ drawing 6♥ must NOT discard 7♥ (protects pure seq)', () {
      // 14-card hand holding 6♥, 7♥, 8♥ (pure sequence) along with high deadwood K♣
      final hand14 = [
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0), // Deadwood to discard
        Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),  // Wild joker
        Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0), // Pure sequence
        Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0), // Pure sequence
        Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0), // Pure sequence
      ];

      final config = AIConfig(level: AILevel.advanced);
      final eval = strategyEngine.decideDiscard(hand14, wildJoker, config, threatTracker, 3);

      // Best discard MUST be the isolated deadwood card K♣
      expect(eval.bestDiscard.suit, equals(Suit.clubs));
      expect(eval.bestDiscard.rank, equals(Rank.king));

      // 6♥, 7♥, 8♥ must NEVER be chosen as discard
      expect(eval.bestDiscard.rank, isNot(equals(Rank.six)));
      expect(eval.bestDiscard.rank, isNot(equals(Rank.seven)));
      expect(eval.bestDiscard.rank, isNot(equals(Rank.eight)));

      // Verifying candidate penalties: 7♥ must have breaksPureSequence == true
      final sevenCand = eval.allCandidates.firstWhere(
        (c) => c.card.suit == Suit.hearts && c.card.rank == Rank.seven,
      );
      expect(sevenCand.breaksPureSequence, isTrue);
      expect(sevenCand.totalScore, lessThan(eval.allCandidates.first.totalScore));
    });

    test('2. Protect Pure Sequence: 4♥ 5♥ 6♥ strictly protected against discard', () {
      final hand14 = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0), // Deadwood candidate
      ];

      final config = AIConfig(level: AILevel.intermediate);
      final eval = strategyEngine.decideDiscard(hand14, wildJoker, config, threatTracker, 5);

      // Best discard must be from isolated deadwood, NOT 4♥, 5♥, 6♥
      final pureCards = [
        Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ];
      for (final pc in pureCards) {
        expect(eval.bestDiscard, isNot(equals(pc)));
      }
    });

    test('3. Protect Sets: 7♥ 7♣ 7♠ protected against discard when holding deadwood 10♠', () {
      final hand14 = [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0), // Set
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),   // Deadwood
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0), // Pure sequence
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0), // Pure sequence
        Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),  // Pure sequence
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
      ];

      final config = AIConfig(level: AILevel.advanced);
      final eval = strategyEngine.decideDiscard(hand14, wildJoker, config, threatTracker, 4);

      // Best discard must be deadwood (10♠ or 9♣), NEVER breaking the 7-7-7 set
      expect(eval.bestDiscard.rank, isNot(equals(Rank.seven)));
      final sevenCand = eval.allCandidates.firstWhere(
        (c) => c.card.suit == Suit.hearts && c.card.rank == Rank.seven,
      );
      expect(sevenCand.breaksCompletedMeld, isTrue);
    });

    test('4. Q♠ K♠ Joker: Valid impure sequence where Joker acts as Ace', () {
      final openJokerCard = Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0);
      final jokerCard = Card(deckIndex: 0, isPrintedJoker: true);

      final sequenceGroup = [
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        jokerCard, // Acts as Ace
      ];

      final validation = SequenceValidator.validate(sequenceGroup, openJokerCard);
      expect(validation.isValid, isTrue);
      expect(validation.type, equals(SequenceType.impure));
    });

    test('5. Open Joker is Printed Joker: Ace becomes the universal Wild Joker rank', () {
      final printedCutCard = Card(deckIndex: 0, isPrintedJoker: true);

      // Verify JokerUtils single source of truth
      final wildRank = JokerUtils.getEffectiveWildRank(printedCutCard);
      expect(wildRank, equals(Rank.ace));
      expect(JokerUtils.getOpenJokerDescription(printedCutCard), contains('Ace is Wild'));

      // Any Ace is now a wild joker
      final aceOfHearts = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
      expect(JokerUtils.isWildJoker(aceOfHearts, printedCutCard), isTrue);
      expect(JokerUtils.isJoker(aceOfHearts, printedCutCard), isTrue);

      final sequence = [
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
        aceOfHearts,
      ];

      final seqValidation = SequenceValidator.validate(sequence, printedCutCard);
      expect(seqValidation.isValid, isTrue);
      expect(seqValidation.type, equals(SequenceType.impure));
    });

    test('6. Bot drawing from Open Pile: Discarding that exact drawn card is prohibited', () {
      final drawnFromOpen = Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0);
      final hand14 = [
        drawnFromOpen,
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0), // Deadwood K♠
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
      ];

      final config = AIConfig(level: AILevel.advanced);
      final eval = strategyEngine.decideDiscard(
        hand14,
        wildJoker,
        config,
        threatTracker,
        5,
        cardDrawnFromOpenPile: drawnFromOpen,
      );

      // Best discard must NEVER be the card drawn from the open pile!
      expect(eval.bestDiscard, isNot(equals(drawnFromOpen)));

      // Candidate for drawnFromOpen must have extreme penalty (-9999999.0)
      final drawnCand = eval.allCandidates.firstWhere((c) => c.card == drawnFromOpen);
      expect(drawnCand.totalScore, lessThan(-9000000.0));
    });

    test('7. Log File 1790200997019 Bug: Bot holding pure sequence + deadwood must NOT pick 6♥ or Q♦ from open pile', () {
      final wildJoker3S = Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0);
      // Maya Bot's exact hand from game log 1790200997019 before drawing 6♥:
      // 8♠, 9♠, 10♠, A♥, 2♥, 5♦, 6♦, 9♦, 10♦, 9♣, 10♣, 5♠, 8♥
      final hand13 = [
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 1),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 1),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 1),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 1),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 1),
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
      ];

      final openCard6H = Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0);
      final knowledge6H = BotKnowledgeState(
        ownHand: hand13,
        openJoker: wildJoker3S,
        openPile: [openCard6H],
        visibleDiscardHistory: [openCard6H],
        closedDeckRemaining: 30,
        turnNumber: 5,
      );

      final config = AIConfig(level: AILevel.advanced);
      final drawResult6H = strategyEngine.decideDraw(knowledge6H, config, threatTracker);

      // Bot MUST draw from closed deck, NOT pick 6♥!
      expect(drawResult6H.choice, equals(DrawChoice.closedDeck));
      expect(drawResult6H.openCardUtility, equals(0.0));

      final openCardQD = Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0);
      final knowledgeQD = BotKnowledgeState(
        ownHand: hand13,
        openJoker: wildJoker3S,
        openPile: [openCardQD],
        visibleDiscardHistory: [openCardQD],
        closedDeckRemaining: 30,
        turnNumber: 6,
      );

      final drawResultQD = strategyEngine.decideDraw(knowledgeQD, config, threatTracker);

      // Bot MUST draw from closed deck, NOT pick Q♦!
      expect(drawResultQD.choice, equals(DrawChoice.closedDeck));
      expect(drawResultQD.openCardUtility, equals(0.0));
    });

    test('8. HandPartitioner tiebreaker: pure sequence takes priority over sets when deadwood is equal', () {
      // Hand with 8♠, 9♠, 10♠ (pure sequence) and 10♦, 10♣ and 9♦, 9♣
      final hand = [
        Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ];

      final partition = HandPartitioner.findBestPartition(hand, wildJoker);

      // Must preserve the pure sequence [8♠, 9♠, 10♠]
      expect(partition.pureSequenceCount, greaterThanOrEqualTo(1));
      final hasPure8910 = partition.groups.any((g) =>
          g.type == HandGroupType.pureSequence &&
          g.cards.any((c) => c.suit == Suit.spades && c.rank == Rank.eight));
      expect(hasPure8910, isTrue);
    });
  });
}
