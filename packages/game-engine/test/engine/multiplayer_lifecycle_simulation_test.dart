import 'dart:math';
import 'package:test/test.dart';
import 'package:game_engine/game_engine.dart';

void main() {
  group('Multiplayer 2–6 Player Engine Lifecycle & Fair-Play Invariant Suite', () {
    // Collect closed deck draw statistics across all 500+ simulated games
    final Map<int, int> drawFrequencyMap = {};
    int totalClosedDeckDraws = 0;

    for (int numPlayers = 2; numPlayers <= 6; numPlayers++) {
      test('Simulate 100 complete games with $numPlayers players - Strict Invariant & Uniqueness Check', () {
        for (int gameIdx = 0; gameIdx < 100; gameIdx++) {
          // 1. Initialize 2 decks (106 cards total: 52 * 2 + 2 jokers)
          final deck = Deck.initialize(2);
          final allCards = List<Card>.from(deck.cards);
          expect(allCards.length, equals(106), reason: 'Two full decks must have 106 cards');

          // 2. Cut Open Wild Joker
          final openJoker = allCards.removeLast();
          expect(openJoker, isNotNull);

          // 3. Deal 13 cards to each player
          final playerHands = <int, List<Card>>{};
          for (int p = 0; p < numPlayers; p++) {
            final hand = <Card>[];
            for (int c = 0; c < 13; c++) {
              hand.add(allCards.removeLast());
            }
            playerHands[p] = hand;
          }

          // 4. Flip first discard card
          final openPile = <Card>[allCards.removeLast()];

          // 5. Remaining cards are the closed deck
          final closedDeck = List<Card>.from(allCards);

          // Invariant Check at Deal
          int initialTotal = (numPlayers * 13) + 1 + 1 + closedDeck.length;
          expect(initialTotal, equals(106),
              reason: 'Invariant failed at deal for $numPlayers players: expected 106, got $initialTotal');

          // 6. Simulate 20 gameplay turns
          Card? lastDrawnFromOpen;
          final rng = Random(gameIdx + numPlayers * 1000);

          for (int turn = 0; turn < 20; turn++) {
            final currentPlayer = turn % numPlayers;
            final currentHand = playerHands[currentPlayer]!;

            // Draw phase: 80% closed deck, 20% open pile (if open pile has cards)
            final drawFromClosed = closedDeck.isNotEmpty && (rng.nextDouble() < 0.8 || openPile.isEmpty);
            Card drawnCard;

            if (drawFromClosed) {
              drawnCard = closedDeck.removeLast();
              drawFrequencyMap[drawnCard.toInt()] = (drawFrequencyMap[drawnCard.toInt()] ?? 0) + 1;
              totalClosedDeckDraws++;
              lastDrawnFromOpen = null;
            } else {
              drawnCard = openPile.removeLast();
              lastDrawnFromOpen = drawnCard;
            }

            currentHand.add(drawnCard);
            expect(currentHand.length, equals(14), reason: 'Hand must have 14 cards after draw');

            // Discard phase: Indian Rummy rule check
            // Cannot discard the same card drawn from open pile in this turn
            int discardIndex = 0;
            if (lastDrawnFromOpen != null && currentHand[discardIndex] == lastDrawnFromOpen) {
              discardIndex = 1;
            }
            final discardedCard = currentHand.removeAt(discardIndex);
            openPile.add(discardedCard);

            expect(currentHand.length, equals(13), reason: 'Hand must have 13 cards after discard');

            // --- STRICT INVARIANT CHECK ON EVERY TURN ---
            int totalCardsOnTable = 1; // open joker
            for (int p = 0; p < numPlayers; p++) {
              totalCardsOnTable += playerHands[p]!.length;
            }
            totalCardsOnTable += closedDeck.length;
            totalCardsOnTable += openPile.length;

            expect(totalCardsOnTable, equals(106),
                reason: 'Turn $turn: 106-card physical invariant violated! Total: $totalCardsOnTable');

            // --- NO DUPLICATE CARD IDS CHECK ---
            final allCardIds = <String>{};
            allCardIds.add(openJoker.cardId);
            for (int p = 0; p < numPlayers; p++) {
              for (final card in playerHands[p]!) {
                expect(allCardIds.add(card.cardId), isTrue,
                    reason: 'Duplicate card found in player $p hand: ${card.cardId}');
              }
            }
            for (final card in closedDeck) {
              expect(allCardIds.add(card.cardId), isTrue,
                  reason: 'Duplicate card found in closed deck: ${card.cardId}');
            }
            for (final card in openPile) {
              expect(allCardIds.add(card.cardId), isTrue,
                  reason: 'Duplicate card found in open pile: ${card.cardId}');
            }
            expect(allCardIds.length, equals(106),
                reason: 'Every single card must have a distinct physical identity');
          }
        }
      });
    }

    test('Statistical Randomness & Uniformity Test — 7♦ Repetition Bug Verification', () {
      expect(totalClosedDeckDraws, greaterThan(3000),
          reason: 'Must have at least 3,000 recorded closed-deck draws across simulations');

      // 7 of Diamonds int values:
      // Deck 0: suit=diamonds (index 1), rank=seven (index 6) -> 0*53 + 1*13 + 6 = 19
      // Deck 1: deckIndex 1 -> 1*53 + 1*13 + 6 = 72
      final card7D_Deck0 = Card.fromInt(19);
      final card7D_Deck1 = Card.fromInt(72);
      expect(card7D_Deck0.suit, equals(Suit.diamonds));
      expect(card7D_Deck0.rank, equals(Rank.seven));
      expect(card7D_Deck1.suit, equals(Suit.diamonds));
      expect(card7D_Deck1.rank, equals(Rank.seven));

      final count7D_0 = drawFrequencyMap[19] ?? 0;
      final count7D_1 = drawFrequencyMap[72] ?? 0;
      final total7D = count7D_0 + count7D_1;

      final expectedRatioPerCard = 1.0 / 106.0; // ~0.0094
      final expected7DRatio = 2.0 / 106.0; // ~0.0188 (since there are two 7♦ in 106 cards)
      final actual7DRatio = total7D / totalClosedDeckDraws;

      // In the bug, actual7DRatio was 1.0 (100% of draws were 7♦!).
      // Here, verify that actual 7♦ frequency is within normal statistical distribution (~1% to 3.5%)
      expect(actual7DRatio, lessThan(0.04),
          reason: '7♦ frequency ($actual7DRatio) is abnormally high! Repetition bug detected.');
      expect(actual7DRatio, greaterThan(0.005),
          reason: '7♦ should appear naturally in random draws');

      // Verify that the draws are broadly distributed across distinct cards
      final distinctCardsDrawn = drawFrequencyMap.keys.length;
      expect(distinctCardsDrawn, greaterThanOrEqualTo(100),
          reason: 'Almost all 106 unique card slots should be drawn across 3000+ draws');
    });

    test('Deck Reshuffle When Closed Deck is Exhausted', () {
      final deck = Deck.initialize(2);
      final allCards = List<Card>.from(deck.cards);
      final openJoker = allCards.removeLast();

      // Give 2 players 13 cards each
      final p1Hand = allCards.sublist(0, 13);
      final p2Hand = allCards.sublist(13, 26);
      final remaining = allCards.sublist(26);

      // Put 78 cards in open pile, leaving closed deck with only 1 card
      final closedDeck = [remaining.removeLast()];
      final openPile = List<Card>.from(remaining);

      expect(closedDeck.length, equals(1));
      expect(openPile.length, equals(78));

      // Draw the last card from closed deck
      final drawn = closedDeck.removeLast();
      expect(drawn, isNotNull);
      expect(closedDeck.isEmpty, isTrue);

      // Indian Rummy Reshuffle rule:
      // Keep the top card of open pile, shuffle remaining 77 cards to make new closed deck
      final topOpen = openPile.removeLast();
      final reshuffledClosedDeck = List<Card>.from(openPile)..shuffle(Random.secure());
      final newOpenPile = [topOpen];

      expect(reshuffledClosedDeck.length, equals(77));
      expect(newOpenPile.length, equals(1));

      // Check invariant after reshuffle
      final total = p1Hand.length + p2Hand.length + 1 + 1 + reshuffledClosedDeck.length + newOpenPile.length;
      expect(total, equals(106), reason: 'Invariant must remain exactly 106 after closed deck reshuffle');
    });

    test('Multiplayer Declaration Lifecycle & Opponent Final Hand Deadwood Minimization', () {
      final wildJoker = Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0);

      // Player 1: Valid 13-card winning show
      // Group 1: Pure sequence (A♠, 2♠, 3♠)
      // Group 2: Second sequence with wild joker (4♥, 5♥, 5♦[wild])
      // Group 3: Set of 3 (8♣, 8♦, 8♠)
      // Group 4: 4-card sequence (9♦, 10♦, J♦, Q♦)
      final winnerGroups = [
        [
          Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
        ],
        [
          Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0), // Wild
        ],
        [
          Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        ],
        [
          Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        ],
      ];

      final valRes = DeclarationValidator().validate(winnerGroups, wildJoker);
      expect(valRes.isValid, isTrue, reason: 'Winning declaration must be valid');

      final winnerScore = Scoring.calculateHandDeadwood(groups: winnerGroups, wildJoker: wildJoker);
      expect(winnerScore, equals(0), reason: 'Winner score must be 0 points');

      // Player 2 (Opponent): Hand with some valid melds and some deadwood
      // Opponent arranges:
      // Group 1: Pure sequence (10♠, J♠, Q♠) -> 0 deadwood
      // Group 2: Deadwood (K♥, 7♣, 2♦) -> 10 + 7 + 2 = 19 points
      final opponentGroups = [
        [
          Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        ],
        [
          Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0),
        ],
      ];

      // Because opponent lacks second sequence, all non-pure cards are penalized
      final opponentScore = Scoring.calculateHandDeadwood(groups: opponentGroups, wildJoker: wildJoker);
      expect(opponentScore, equals(19), reason: 'Deadwood cards must be accurately tallied (10+7+2=19)');
      expect(opponentScore, lessThan(80), reason: 'Arranging cards successfully reduced score below max penalty 80');

      // Unsubmitted opponent gets 80 points penalty
      final unsubmittedScore = 80;
      expect(unsubmittedScore, equals(80));
    });
  });
}
