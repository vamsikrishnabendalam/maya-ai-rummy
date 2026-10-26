import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';

void main() {
  test('Player can declare with the card drawn from open pile into finish slot', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(gameTableProvider.notifier);

    // Allow startNewGame microtask to finish
    await Future.delayed(const Duration(milliseconds: 50));

    final wildJoker = Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);
    final card6S = Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0);

    // Setup 13 cards forming a complete winning declaration:
    // Group 1: 4D 5D 6D (Pure Sequence)
    // Group 2: 9D 10D JD (Pure Sequence)
    // Group 3: 5H PJ 6H (Impure Sequence)
    // Group 4: AS 2S AD AH (Set with 2S as wild joker)
    final g1 = CardGroup(
      id: 'g1',
      type: CardGroupType.pureSequence,
      cards: [
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0),
      ],
      isValid: true,
    );
    final g2 = CardGroup(
      id: 'g2',
      type: CardGroupType.pureSequence,
      cards: [
        Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
      ],
      isValid: true,
    );
    final g3 = CardGroup(
      id: 'g3',
      type: CardGroupType.impureSequence,
      cards: [
        Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0),
        Card(isPrintedJoker: true, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0),
      ],
      isValid: true,
    );
    final g4 = CardGroup(
      id: 'g4',
      type: CardGroupType.set,
      cards: [
        Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
      ],
      isValid: true,
    );
    // Group 5: 14th card (6S) drawn from open pile
    final g5 = CardGroup(
      id: 'g5',
      type: CardGroupType.deadwood,
      cards: [card6S],
      isValid: false,
    );

    final humanPlayerHand = [
      ...g1.cards,
      ...g2.cards,
      ...g3.cards,
      ...g4.cards,
      ...g5.cards,
    ];

    final gameState = notifier.state.gameState.copyWith(
      phase: GamePhase.DISCARD_PHASE,
      currentPlayerIndex: 0,
      wildJoker: wildJoker,
      cardDrawnFromOpenThisTurn: card6S, // 6S was drawn from open pile this turn!
      players: [
        Player(id: 'human_player', hand: humanPlayerHand),
        Player(id: 'ai_bot_1', hand: []),
      ],
    );

    notifier.state = notifier.state.copyWith(
      gameState: gameState,
      cardGroups: [g1, g2, g3, g4, g5],
      selectedCard: card6S, // Selected 6S to discard / declare
      hasDrawnThisTurn: true,
      hasHumanOpenedJoker: true,
    );

    // Verify:
    // 1. Standard discard to open pile is FORBIDDEN for open-drawn card:
    expect(notifier.canDiscard, isFalse, reason: 'Cannot discard card drawn from open pile back to open pile');

    // 2. Declaration into finish slot IS ALLOWED:
    expect(notifier.canDiscardAndDeclare, isTrue, reason: 'Can declare 14th card into finish slot even if drawn from open pile');

    // 3. Hand partitions into a winning declaration:
    expect(notifier.remainingCardsFormValidDeclaration, isTrue);

    // 4. Executing declaration concludes game with 0 points:
    final partitionResult = notifier.discardAndDeclareSelectedCard();
    expect(partitionResult.isValidDeclaration, isTrue);
    expect(notifier.state.gameState.phase, equals(GamePhase.COMPLETE));
    expect(notifier.humanPlayer.score, equals(0));
    expect(notifier.humanPlayer.status, equals(PlayerStatus.DECLARED));
  });
}
