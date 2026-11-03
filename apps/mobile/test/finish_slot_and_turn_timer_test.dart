import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/game_settings.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';

void main() {
  group('Finish Slot Drag & Drop and Turn Timer Options', () {
    test('Finish slot can declare directly via explicit finishCard without prior selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameTableProvider.notifier);
      addTearDown(notifier.cancelTurnTimer);

      final p1 = const Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0);
      final p2 = const Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0);
      final p3 = const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0);

      final s1 = const Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0);
      final s2 = const Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0);
      final s3 = const Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0);

      final t1 = const Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0);
      final t2 = const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0);
      final t3 = const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0);

      final st1 = const Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0);
      final st2 = const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0);
      final st3 = const Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);
      final st4 = const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0);

      // 14th card to be dropped into Finish slot
      final finishCard = const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0);

      final g1 = CardGroup(id: 'g1', type: CardGroupType.pureSequence, cards: [p1, p2, p3], isValid: true);
      final g2 = CardGroup(id: 'g2', type: CardGroupType.pureSequence, cards: [s1, s2, s3], isValid: true);
      final g3 = CardGroup(id: 'g3', type: CardGroupType.pureSequence, cards: [t1, t2, t3], isValid: true);
      final g4 = CardGroup(id: 'g4', type: CardGroupType.set, cards: [st1, st2, st3, st4], isValid: true);
      final g5 = CardGroup(id: 'g5', type: CardGroupType.deadwood, cards: [finishCard], isValid: false);

      final wildJoker = const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0);

      final gameState = GameState(
        gameId: 'test_game',
        players: [
          Player(id: 'human_player', hand: [p1, p2, p3, s1, s2, s3, t1, t2, t3, st1, st2, st3, st4, finishCard]),
          Player(id: 'ai_bot_1', hand: []),
        ],
        closedDeck: [],
        openPile: [],
        wildJoker: wildJoker,
        phase: GamePhase.DISCARD_PHASE,
        turnNumber: 2,
      );

      notifier.state = notifier.state.copyWith(
        gameState: gameState,
        cardGroups: [g1, g2, g3, g4, g5],
        selectedCard: null, // Note: no card selected via click/tap!
        hasDrawnThisTurn: true,
        hasHumanOpenedJoker: true,
      );

      // Verify selectedCard is null
      expect(notifier.state.selectedCard, isNull);

      // Dropping finishCard into Finish slot declares directly
      final result = notifier.discardAndDeclareSelectedCard(finishCard);
      expect(result.isValidDeclaration, isTrue);
      expect(notifier.state.gameState.phase, equals(GamePhase.COMPLETE));
      expect(notifier.humanPlayer.score, equals(0));
      expect(notifier.humanPlayer.status, equals(PlayerStatus.DECLARED));

      // Discard pile now contains the finishCard
      expect(notifier.state.gameState.openPile.last, equals(finishCard));
    });

    test('Turn timer settings support [30, 45, 60, 0] with No Limit handling', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameTableProvider.notifier);
      addTearDown(notifier.cancelTurnTimer);

      // Test 45s
      notifier.setTurnTimer(45);
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(45));

      // Test 60s
      notifier.setTurnTimer(60);
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(60));
      expect(notifier.state.turnSecondsRemaining, equals(60));

      // Test 0 (No Limit)
      notifier.setTurnTimer(0);
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(0));
      expect(notifier.state.turnSecondsRemaining, equals(0));

      // Test startNewGame preserves 60s
      notifier.setTurnTimer(60);
      notifier.startNewGame();
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(60));
      expect(notifier.state.turnSecondsRemaining, equals(60));

      // Test startNewGame preserves No Limit (0)
      notifier.setTurnTimer(0);
      notifier.startNewGame();
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(0));
      expect(notifier.state.turnSecondsRemaining, equals(0));

      // Test updateSettings preserves and propagates
      final settings = const GameSettings(turnTimerSeconds: 45);
      notifier.updateSettings(settings);
      expect(notifier.state.gameSettings.turnTimerSeconds, equals(45));
      expect(notifier.state.turnSecondsRemaining, equals(45));
    });
    test('startNextRound cleanly clears finishCard from previous round and logs with correct roundNumber', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameTableProvider.notifier);
      addTearDown(notifier.cancelTurnTimer);

      final finishCard = const Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0);
      final p1 = const Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0);
      final p2 = const Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0);
      final p3 = const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0);
      final s1 = const Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0);
      final s2 = const Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0);
      final s3 = const Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0);
      final t1 = const Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0);
      final t2 = const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0);
      final t3 = const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0);
      final st1 = const Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0);
      final st2 = const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0);
      final st3 = const Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0);
      final st4 = const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0);

      final g1 = CardGroup(id: 'g1', type: CardGroupType.pureSequence, cards: [p1, p2, p3], isValid: true);
      final g2 = CardGroup(id: 'g2', type: CardGroupType.pureSequence, cards: [s1, s2, s3], isValid: true);
      final g3 = CardGroup(id: 'g3', type: CardGroupType.pureSequence, cards: [t1, t2, t3], isValid: true);
      final g4 = CardGroup(id: 'g4', type: CardGroupType.set, cards: [st1, st2, st3, st4], isValid: true);
      final g5 = CardGroup(id: 'g5', type: CardGroupType.deadwood, cards: [finishCard], isValid: false);

      final wildJoker = const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0);

      final gameState = GameState(
        gameId: 'round1_game',
        players: [
          Player(id: 'human_player', hand: [p1, p2, p3, s1, s2, s3, t1, t2, t3, st1, st2, st3, st4, finishCard]),
          Player(id: 'ai_bot_1', hand: []),
        ],
        closedDeck: [],
        openPile: [],
        wildJoker: wildJoker,
        phase: GamePhase.DISCARD_PHASE,
        turnNumber: 2,
      );

      notifier.state = notifier.state.copyWith(
        gameState: gameState,
        cardGroups: [g1, g2, g3, g4, g5],
        hasDrawnThisTurn: true,
        hasHumanOpenedJoker: true,
      );

      // Round 1 declaration with 4♥
      notifier.discardAndDeclareSelectedCard(finishCard);
      expect(notifier.state.finishCard, equals(finishCard));
      expect(notifier.state.isRoundOver, isTrue);

      // Verify Round 1 logs recorded roundNumber == 1
      final declareLog = notifier.state.actionLogs.lastWhere((l) => l.action == 'Declare');
      expect(declareLog.roundNumber, equals(1));
      final roundResultLog = notifier.state.actionLogs.lastWhere((l) => l.action == 'Round Result');
      expect(roundResultLog.roundNumber, equals(1));

      // Now start next round (Round 2)
      notifier.startNextRound();

      // Verify finishCard is cleanly reset to null in Round 2!
      expect(notifier.state.finishCard, isNull);
      expect(notifier.state.isRoundOver, isFalse);
      expect(notifier.state.currentRoundNumber, equals(2));
    });

    test('startNextRound cleanly clears botDiscardCard when Maya bot declares in Round 1', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameTableProvider.notifier);
      addTearDown(notifier.cancelTurnTimer);

      final botFinishCard = const Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0);

      // Simulate Maya bot declaring in Round 1
      notifier.state = notifier.state.copyWith(
        gameState: GameState(
          gameId: 'round1_bot_declares',
          players: [
            Player(id: 'human_player', hand: []),
            Player(id: 'ai_bot_1', hand: []),
          ],
          closedDeck: [],
          openPile: [],
          wildJoker: const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
          phase: GamePhase.DISCARD_PHASE,
        ),
        botDiscardCard: botFinishCard,
        botDeclarationResult: const HandPartitionResult(
          isValidDeclaration: true,
          penaltyScore: 0,
          errorMessage: '',
          pureSequenceCount: 1,
          totalSequenceCount: 2,
          groups: [],
          unmatchedCards: [],
        ),
        isAwaitingHumanDeclarationShow: true,
      );
      expect(notifier.state.botDiscardCard, equals(botFinishCard));

      // Human submits show to conclude Round 1
      notifier.submitHumanDeclarationShow();
      expect(notifier.state.isRoundOver, isTrue);

      // Now dealer starts Round 2
      notifier.startNextRound();

      // Both finishCard and botDiscardCard MUST be null in Round 2!
      expect(notifier.state.botDiscardCard, isNull);
      expect(notifier.state.finishCard, isNull);
      expect(notifier.state.isRoundOver, isFalse);
      expect(notifier.state.currentRoundNumber, equals(2));
    });
  });
}
