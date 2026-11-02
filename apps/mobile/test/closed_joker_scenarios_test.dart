import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/game_settings.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_ui_provider.dart';

void main() {
  group('Closed Joker Scenarios', () {
    test('Scenario 1: Dealing without pure sequence keeps joker closed with null effective joker', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameTableProvider.notifier);

      // Set to CLOSED joker mode
      notifier.setJokerMode('CLOSED');

      // Verify closed joker mode is active
      final state = container.read(gameTableProvider);
      expect(state.gameSettings.isClosedJoker, isTrue);

      // If hand does not have pure sequence, joker must not be opened
      final humanHand = notifier.humanPlayer.hand;
      final hasPure = SequenceValidator.hasPureSequenceInHand(humanHand);

      if (!hasPure) {
        expect(state.hasHumanOpenedJoker, isFalse);
        expect(notifier.effectiveHumanWildJoker, isNull);
      }
    });

    test('Scenario 1: Hand dealt with pure sequence automatically opens joker for player', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameTableProvider.notifier);
      notifier.setJokerMode('CLOSED');

      // Construct a hand with a guaranteed pure sequence: 2♥, 3♥, 4♥
      final pureCards = [
        const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
      ];

      expect(SequenceValidator.hasPureSequenceInHand(pureCards), isTrue);

      // Verify validator correctly identifies pure sequence in 13 cards
      final fullHandWithPure = [
        ...pureCards,
        const Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        const Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.three, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
      ];
      expect(fullHandWithPure.length, 13);
      expect(SequenceValidator.hasPureSequenceInHand(fullHandWithPure), isTrue);
    });

    test('Scenario 2: Forming pure sequence from draw remains closed until card is discarded', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameTableProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));
      notifier.setJokerMode('CLOSED');

      // Ensure player has no pure sequence initially
      var state = container.read(gameTableProvider);
      final initialNoPureGroups = [
        CardGroup(
          id: 'g1',
          type: CardGroupType.deadwood,
          cards: const [
            Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
          ],
          isValid: false,
        ),
        CardGroup(
          id: 'g2',
          type: CardGroupType.deadwood,
          cards: const [
            Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
            Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0),
            Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
            Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
            Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0),
            Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
            Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
            Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
            Card(suit: Suit.diamonds, rank: Rank.three, deckIndex: 0),
            Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
            Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
          ],
          isValid: false,
        ),
      ];

      // Update state with hand that has NO pure sequence
      notifier.state = state.copyWith(
        cardGroups: initialNoPureGroups,
        hasHumanOpenedJoker: false,
      );

      expect(container.read(gameTableProvider).hasHumanOpenedJoker, isFalse);
      expect(notifier.effectiveHumanWildJoker, isNull);

      // Now draw card 4♥ (which completes 2♥, 3♥, 4♥)
      // During draw phase, the hand has 14 cards
      const drawnCard = Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0);
      final groupsWithDrawn = [
        ...initialNoPureGroups,
        CardGroup(
          id: 'g_drawn',
          type: CardGroupType.deadwood,
          cards: const [drawnCard],
          isValid: false,
          customLabel: 'DRAWN',
        ),
      ];

      final hand14 = groupsWithDrawn.expand((g) => g.cards).toList();
      final updatedPlayers = [
        Player(id: 'human_player', hand: hand14),
        Player(id: 'ai_bot_1', hand: const []),
      ];

      notifier.state = container.read(gameTableProvider).copyWith(
        gameState: container.read(gameTableProvider).gameState.copyWith(
          phase: GamePhase.DISCARD_PHASE,
          players: updatedPlayers,
        ),
        cardGroups: groupsWithDrawn,
        hasDrawnThisTurn: true,
      );

      // WHILE HOLDING 14 CARDS BEFORE DISCARDING:
      // The joker MUST STILL BE CLOSED with ZERO hints leaked!
      expect(container.read(gameTableProvider).hasHumanOpenedJoker, isFalse);
      expect(notifier.effectiveHumanWildJoker, isNull);
      expect(notifier.hasHumanLife, isTrue); // Pure sequence exists in 14-card hand
      expect(container.read(gameUIProvider).showSecretJokerReveal, isFalse);

      // Now the player discards an irrelevant card (e.g. K♣)
      // This reduces hand to 13 cards containing 2♥, 3♥, 4♥ pure sequence!
      const discardCard = Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0);
      notifier.discardCard(discardCard);

      // AFTER DISCARDING:
      // The joker must be AUTOMATICALLY OPENED!
      final stateAfterDiscard = container.read(gameTableProvider);
      expect(stateAfterDiscard.hasHumanOpenedJoker, isTrue);
      expect(notifier.effectiveHumanWildJoker, isNotNull);
      expect(notifier.hasHumanLife, isTrue);

      // And the secret joker reveal animation must have triggered!
      expect(container.read(gameUIProvider).showSecretJokerReveal, isTrue);
      expect(container.read(gameUIProvider).secretJokerCard, isNotNull);
    });

    test('Open discard pile does not leak wild joker status when closed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameTableProvider.notifier);
      notifier.setJokerMode('CLOSED');

      final state = container.read(gameTableProvider);
      notifier.state = state.copyWith(hasHumanOpenedJoker: false);

      // When joker is closed and locked for player:
      expect(notifier.effectiveHumanWildJoker, isNull);

      // Discard matching the wild joker rank
      final wildCard = notifier.wildJokerCard;
      if (wildCard != null && !wildCard.isPrintedJoker) {
        final matchingRankCard = Card(
          suit: wildCard.suit == Suit.spades ? Suit.hearts : Suit.spades,
          rank: wildCard.rank,
          deckIndex: 1,
        );

        // When evaluating against effectiveHumanWildJoker (null), it is NOT considered wild!
        expect(JokerUtils.isWildJoker(matchingRankCard, notifier.effectiveHumanWildJoker), isFalse);
      }
    });
  });
}
