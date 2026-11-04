import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/auth/models/multiplayer_user.dart';
import 'package:maya_ai_rummy_mobile/features/auth/providers/auth_provider.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_ui_provider.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/models/table_models.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/providers/multiplayer_providers.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/services/multiplayer_service.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/services/multiplayer_action_queue.dart';

class MockAuthNotifier extends StateNotifier<MultiplayerUser?> implements AuthNotifier {
  MockAuthNotifier(MultiplayerUser? user) : super(user);

  @override
  bool get isAuthenticated => state != null;

  @override
  Future<MultiplayerUser?> signInWithGoogle() async => state;

  @override
  Future<MultiplayerUser> signInWithProfileDetails({
    required String name,
    required String email,
    String? photoURL,
  }) async => state!;

  @override
  Future<MultiplayerUser> signInAsGuest({String? name, bool forceNewSession = false}) async => state!;

  @override
  Future<void> updateGuestName(String newName) async {}

  @override
  Future<MultiplayerUser> completeProfile({
    required String name,
    required String dateOfBirth,
    required String country,
    String? photoURL,
  }) async => state!;

  @override
  Future<void> updateAvatar(String newPhotoUrl) async {}

  @override
  Future<void> signOut() async => state = null;
}

void main() {
  group('Multiplayer Final Hand Submission and Closed Joker Tests', () {
    test('Opponent can submit final hand when declaring and avoid 80 pts default penalty', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_opponent',
        displayName: 'Opponent Player',
        email: 'test@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final wildJoker = const Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0);
      final initialGame = MultiplayerGameState(
        gameId: 'game_test_declare',
        tableId: 'table_1',
        roomCode: '123456',
        tableName: 'Test Table',
        gameMode: 'Points Rummy',
        status: 'DECLARING',
        playerCount: 2,
        currentTurnPlayerId: 'user_declarant',
        turnNumber: 1,
        phase: 'DECLARATION',
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        firstDropPenalty: 20,
        middleDropPenalty: 40,
        maxPenalty: 80,
        entryType: 'POINTS',
        jokerMode: 'OPEN',
        openJoker: wildJoker,
        closedDeckRemaining: 30,
        openPile: const [Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0)],
        declaringPlayerId: 'user_declarant',
        declarationDeadline: DateTime.now().add(const Duration(seconds: 30)),
        players: const [
          TablePlayer(uid: 'user_declarant', displayName: 'Declarant', photoURL: '', seatIndex: 0),
          TablePlayer(uid: 'user_opponent', displayName: 'Opponent', photoURL: '', seatIndex: 1),
        ],
        submittedPlayerUids: const [],
        myHand: const [
          Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
        ],
      );

      service.setMockGame(initialGame);

      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(gameState: initialGame);

      expect(notifier.state.gameState!.isDeclaring, isTrue);
      expect(notifier.state.gameState!.submittedPlayerUids.contains('user_opponent'), isFalse);

      // Submit final hand
      await notifier.submitFinalHand();

      // Check that opponent UID is now marked as submitted
      expect(notifier.state.gameState!.submittedPlayerUids.contains('user_opponent'), isTrue);
    });

    test('Closed Joker triggers secret royal reveal animation when unlocked with pure sequence', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_1',
        displayName: 'Player One',
        email: 'test@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final wildJoker = const Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0);
      final closedGame = MultiplayerGameState(
        gameId: 'game_closed_joker',
        tableId: 'table_cj',
        roomCode: '654321',
        tableName: 'Closed Joker Table',
        gameMode: 'Points Rummy',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_1',
        turnNumber: 1,
        phase: 'DISCARD_PHASE',
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        firstDropPenalty: 20,
        middleDropPenalty: 40,
        maxPenalty: 80,
        entryType: 'POINTS',
        jokerMode: 'CLOSED',
        openJoker: wildJoker,
        closedDeckRemaining: 25,
        openPile: const [Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0)],
        openedJokerPlayerUids: const [],
        players: const [
          TablePlayer(uid: 'user_1', displayName: 'Player One', photoURL: '', seatIndex: 0),
          TablePlayer(uid: 'user_2', displayName: 'Player Two', photoURL: '', seatIndex: 1),
        ],
      );

      service.setMockGame(closedGame);

      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(gameState: closedGame);

      // Initially closed for user_1
      expect(closedGame.hasPlayerOpenedJoker('user_1'), isFalse);
      expect(closedGame.effectiveJokerForPlayer('user_1'), isNull);
      expect(container.read(gameUIProvider).showSecretJokerReveal, isFalse);

      // Call openClosedJoker()
      await notifier.openClosedJoker();

      // Effective joker is now revealed, and royal animation is triggered
      expect(notifier.state.gameState!.hasPlayerOpenedJoker('user_1'), isTrue);
      expect(notifier.state.gameState!.effectiveJokerForPlayer('user_1'), equals(wildJoker));
      expect(container.read(gameUIProvider).showSecretJokerReveal, isTrue);
      expect(container.read(gameUIProvider).secretJokerCard, equals(wildJoker));

      // Dismiss animation
      container.read(gameUIProvider.notifier).dismissSecretJokerReveal();
      expect(container.read(gameUIProvider).showSecretJokerReveal, isFalse);
    });
  
    test('Player holding 14 cards on turn is guaranteed DISCARD_PHASE and can discard cleanly even if incoming phase is DRAW_PHASE', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_cj',
        displayName: 'cj',
        email: 'cj@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      // 14 cards in hand (already drawn)
      final fourteenCards = List.generate(
        14,
        (i) => Card(suit: i == 13 ? Suit.spades : Suit.hearts, rank: Rank.values[i % 13], deckIndex: 0),
      );

      // State where incoming phase is erroneously DRAW_PHASE (e.g. before snapshot arrives or after openClosedJoker)
      final desyncGame = MultiplayerGameState(
        gameId: 'game_desync_test',
        tableId: 'table_1',
        roomCode: 'DESYNC',
        tableName: 'Desync Table',
        gameMode: 'Best of 2 Deals',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_cj',
        turnNumber: 5,
        phase: 'DRAW_PHASE', // Server/stale local phase
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        jokerMode: 'OPEN',
        openPile: const [Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0)],
        players: const [
          TablePlayer(uid: 'user_vk', displayName: 'vk', photoURL: '', seatIndex: 0),
          TablePlayer(uid: 'user_cj', displayName: 'cj', photoURL: '', seatIndex: 1, cardCount: 14),
        ],
        myHand: fourteenCards,
      );

      // TableModels invariant check
      expect(desyncGame.isDrawPhase, isFalse, reason: 'Holding 14 cards must never be in Draw Phase');
      expect(desyncGame.isDiscardPhase, isTrue, reason: 'Holding 14 cards must always be in Discard Phase');

      service.setMockGame(desyncGame);
      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        gameState: desyncGame,
        cardGroups: [
          CardGroup(id: 'grp_0', type: CardGroupType.deadwood, cards: fourteenCards, isValid: false),
        ],
      );

      // Select a card to discard
      final cardToDiscard = fourteenCards.last;
      notifier.selectCard(cardToDiscard);

      expect(notifier.state.selectedCard, equals(cardToDiscard));

      // Discard the card
      await notifier.discardSelectedCard();

      // Hand must now be 13 cards and selected card cleared
      final allRemaining = notifier.state.cardGroups.expand((g) => g.cards).toList();
      expect(allRemaining.length, equals(13));
      expect(allRemaining.contains(cardToDiscard), isFalse);
    });

    test('Closed Joker cannot be unlocked while holding 14 cards before discard', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_1',
        displayName: 'Player One',
        email: 'p1@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      const wildJoker = Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0);
      final fourteenCardsWithPureSeq = [
        const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0), // Pure Sequence!
        const Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        const Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
        const Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.ten, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.jack, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0), // 14th card
      ];

      final closedGame = MultiplayerGameState(
        gameId: 'game_closed_14_test',
        tableId: 'tbl_1',
        roomCode: 'CJ1401',
        tableName: 'Closed Joker 14-Card Test',
        gameMode: 'Points Rummy',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_1',
        turnNumber: 1,
        phase: 'DISCARD_PHASE',
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        jokerMode: 'CLOSED',
        openJoker: wildJoker,
        closedDeckRemaining: 25,
        openPile: const [Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0)],
        openedJokerPlayerUids: const [],
        players: const [
          TablePlayer(uid: 'user_1', displayName: 'Player One', photoURL: '', seatIndex: 0, cardCount: 14),
          TablePlayer(uid: 'user_2', displayName: 'Player Two', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        myHand: fourteenCardsWithPureSeq,
      );

      service.setMockGame(closedGame);
      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        gameState: closedGame,
        cardGroups: [
          CardGroup(
            id: 'grp_seq',
            type: CardGroupType.pureSequence,
            cards: fourteenCardsWithPureSeq.sublist(0, 3),
            isValid: true,
          ),
          CardGroup(
            id: 'grp_rest',
            type: CardGroupType.deadwood,
            cards: fourteenCardsWithPureSeq.sublist(3),
            isValid: false,
          ),
        ],
        hasDrawnThisTurn: true,
      );

      // Attempt to open Closed Joker while holding 14 cards (before discard)
      await notifier.openClosedJoker();

      // Must remain closed!
      expect(notifier.state.gameState!.hasPlayerOpenedJoker('user_1'), isFalse);
      expect(notifier.state.gameState!.effectiveJokerForPlayer('user_1'), isNull);

      // Now discard 14th card to complete turn
      notifier.selectCard(fourteenCardsWithPureSeq.last);
      await notifier.discardSelectedCard();

      // Hand is now 13 cards with pure sequence: Closed Joker unlocks!
      expect(notifier.state.gameState!.hasPlayerOpenedJoker('user_1'), isTrue);
      expect(notifier.state.gameState!.effectiveJokerForPlayer('user_1'), equals(wildJoker));
    });

    test('Dropping on first turn of 201 Pool game transitions to ROUND_OVER with 20 penalty pts, not COMPLETED', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_dropper',
        displayName: 'Dropping Player',
        email: 'drop@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final poolGame = MultiplayerGameState(
        gameId: 'game_pool_drop_test',
        tableId: 'tbl_pool_1',
        roomCode: 'PL201D',
        tableName: 'Pool 201 Table',
        gameMode: 'Pool 201',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_dropper',
        turnNumber: 0,
        phase: 'DRAW_PHASE',
        firstDropPenalty: 20,
        middleDropPenalty: 40,
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        jokerMode: 'OPEN',
        openPile: const [Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0)],
        currentRound: 1,
        players: const [
          TablePlayer(uid: 'user_dropper', displayName: 'Dropping Player', photoURL: '', seatIndex: 0, cardCount: 13, score: 0),
          TablePlayer(uid: 'user_other', displayName: 'Other Player', photoURL: '', seatIndex: 1, cardCount: 13, score: 0),
        ],
        myHand: const [],
      );

      service.setMockGame(poolGame);
      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(gameState: poolGame);

      // Dropping player takes first drop
      await notifier.dropGame();

      // Game must NOT be COMPLETED! It must be ROUND_OVER with roundHistory recorded and next round scheduled!
      final updatedGame = notifier.state.gameState!;
      expect(updatedGame.status, equals('ROUND_OVER'));
      expect(updatedGame.roundHistory.length, equals(1));
      final round1 = updatedGame.roundHistory.first;
      expect(round1['round'], equals(1));
      expect(round1['winnerUid'], equals('user_other'));

      // Cumulative score of dropper is 20
      final dropperResult = (round1['results'] as List).firstWhere((r) => r['uid'] == 'user_dropper');
      expect(dropperResult['cumulativeScore'], equals(20));
      expect(dropperResult['isEliminated'], isFalse);
    });

    test('Declaring with finish card preserves finishCard in MultiplayerGameState and table state', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_declarer',
        displayName: 'Declarer',
        email: 'dec@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      const finishCard = Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0);
      final thirteenValidCards = [
        const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.four, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
        const Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.eight, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0),
        const Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.jack, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
        const Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
      ];

      final game = MultiplayerGameState(
        gameId: 'game_dec_finish_test',
        tableId: 'tbl_dec_1',
        roomCode: 'DCF001',
        tableName: 'Declare Finish Table',
        gameMode: 'Points Rummy',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_declarer',
        turnNumber: 3,
        phase: 'DISCARD_PHASE',
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        jokerMode: 'OPEN',
        openJoker: const Card(suit: Suit.diamonds, rank: Rank.seven, deckIndex: 0),
        openPile: const [Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0)],
        players: const [
          TablePlayer(uid: 'user_declarer', displayName: 'Declarer', photoURL: '', seatIndex: 0, cardCount: 14),
          TablePlayer(uid: 'user_opp', displayName: 'Opponent', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        myHand: [...thirteenValidCards, finishCard],
      );

      service.setMockGame(game);
      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        gameState: game,
        cardGroups: [
          CardGroup(id: 'g1', type: CardGroupType.pureSequence, cards: thirteenValidCards.sublist(0, 3), isValid: true),
          CardGroup(id: 'g2', type: CardGroupType.pureSequence, cards: thirteenValidCards.sublist(3, 6), isValid: true),
          CardGroup(id: 'g3', type: CardGroupType.pureSequence, cards: thirteenValidCards.sublist(6, 9), isValid: true),
          CardGroup(id: 'g4', type: CardGroupType.pureSequence, cards: thirteenValidCards.sublist(9, 13), isValid: true),
          CardGroup(id: 'g_fin', type: CardGroupType.deadwood, cards: const [finishCard], isValid: false),
        ],
      );

      final res = await notifier.declareWithCard(finishCard);
      expect(res!['isValid'], isTrue);
      expect(notifier.state.finishCard, equals(finishCard));
      expect(notifier.state.gameState!.finishCard, equals(finishCard));
    });

    test('startNextRound cleanly clears declarationDeadline, finishCard, and declarer from Round 1', () async {
      final service = MultiplayerService();
      final round1OverGame = MultiplayerGameState(
        gameId: 'game_r1_transition',
        tableId: 'tbl_r1',
        roomCode: 'R1R201',
        tableName: 'Pool 201 Table',
        gameMode: 'Pool 201',
        status: 'ROUND_OVER',
        currentRound: 1,
        playerCount: 2,
        currentTurnPlayerId: 'user_p1',
        turnNumber: 15,
        phase: 'DECLARATION',
        turnTimerSeconds: 30,
        declarationDeadline: DateTime.now().add(const Duration(seconds: 30)),
        finishCard: const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
        declaringPlayerId: 'user_p1',
        declaringPlayerName: 'Player 1',
        submittedPlayerUids: const ['user_p1', 'user_p2'],
        openedJokerPlayerUids: const ['user_p1', 'user_p2'],
        finalResults: const [
          MultiplayerFinalResult(uid: 'user_p1', displayName: 'Player 1', photoURL: '', seatIndex: 0, score: 0, isWinner: true),
          MultiplayerFinalResult(uid: 'user_p2', displayName: 'Player 2', photoURL: '', seatIndex: 1, score: 23, isWinner: false),
        ],
        jokerMode: 'CLOSED',
        openJoker: const Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        openPile: const [Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0)],
        players: const [
          TablePlayer(uid: 'user_p1', displayName: 'Player 1', photoURL: '', seatIndex: 0, cardCount: 13, isHost: true),
          TablePlayer(uid: 'user_p2', displayName: 'Player 2', photoURL: '', seatIndex: 1, cardCount: 13, isHost: false),
        ],
        dealerPlayerId: 'user_p1',
      );

      service.setMockGame(round1OverGame);

      await service.startNextRound('game_r1_transition');

      final round2Game = service.getMockGame('game_r1_transition')!;
      expect(round2Game.currentRound, equals(2));
      expect(round2Game.status, equals('IN_PROGRESS'));
      expect(round2Game.phase, equals('DRAW_PHASE'));
      expect(round2Game.declarationDeadline, isNull);
      expect(round2Game.finishCard, isNull);
      expect(round2Game.declaringPlayerId, isNull);
      expect(round2Game.declaringPlayerName, isNull);
      expect(round2Game.openedJokerPlayerUids, isEmpty);
      expect(round2Game.submittedPlayerUids, isEmpty);
      expect(round2Game.finalResults, isEmpty);
      expect(round2Game.winnerPlayerId, isNull);
    });

    test('openClosedJoker is strictly rejected if game is not IN_PROGRESS', () async {
      final service = MultiplayerService();
      final roundOverGame = MultiplayerGameState(
        gameId: 'game_joker_reject',
        tableId: 'tbl_j1',
        roomCode: 'JKR001',
        tableName: 'Closed Joker Table',
        gameMode: 'Pool 201',
        status: 'ROUND_OVER',
        currentRound: 1,
        playerCount: 2,
        currentTurnPlayerId: 'user_p1',
        turnNumber: 10,
        phase: 'DECLARATION',
        jokerMode: 'CLOSED',
        openJoker: const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        players: const [
          TablePlayer(uid: 'user_p1', displayName: 'Player 1', photoURL: '', seatIndex: 0, cardCount: 13),
          TablePlayer(uid: 'user_p2', displayName: 'Player 2', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        openedJokerPlayerUids: const [],
      );

      service.setMockGame(roundOverGame);
      await service.openClosedJoker(gameId: 'game_joker_reject', myUid: 'user_p2');

      final unchanged = service.getMockGame('game_joker_reject')!;
      expect(unchanged.openedJokerPlayerUids, isEmpty);
    });

    test('Round 2 invalid declaration applies 80 pts penalty, updates roundHistory and cumulative scores', () async {
      final service = MultiplayerService();
      final round2Game = MultiplayerGameState(
        gameId: 'game_r2_invalid_test',
        tableId: 'tbl_deals_2',
        roomCode: 'DEALS2',
        tableName: 'Best of 2 Deals',
        gameMode: 'Best of 2 Deals',
        status: 'IN_PROGRESS',
        currentRound: 2,
        playerCount: 2,
        currentTurnPlayerId: 'user_p2',
        turnNumber: 5,
        phase: 'DISCARD_PHASE',
        turnTimerSeconds: 30,
        jokerMode: 'CLOSED',
        openJoker: const Card(suit: Suit.spades, rank: Rank.eight, deckIndex: 0),
        openPile: const [Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0)],
        players: const [
          TablePlayer(uid: 'user_p1', displayName: 'vamsi', photoURL: '', seatIndex: 0, cardCount: 13, score: 0, isHost: true),
          TablePlayer(uid: 'user_p2', displayName: 'jagadeesh', photoURL: '', seatIndex: 1, cardCount: 14, score: 24, isHost: false),
        ],
        roundHistory: const [
          {
            'round': 1,
            'winnerUid': 'user_p1',
            'winnerName': 'vamsi',
            'results': [
              {'uid': 'user_p1', 'displayName': 'vamsi', 'roundScore': 0, 'cumulativeScore': 0, 'isEliminated': false},
              {'uid': 'user_p2', 'displayName': 'jagadeesh', 'roundScore': 24, 'cumulativeScore': 24, 'isEliminated': false},
            ],
          }
        ],
        dealerPlayerId: 'user_p1',
      );

      service.setMockGame(round2Game);

      // Jagadeesh declares with an invalid meld (no pure sequence)
      final discardCard = const Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0);
      final invalidGroups = [
        [const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0), const Card(suit: Suit.hearts, rank: Rank.five, deckIndex: 0), const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0)],
        [const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0), const Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0), const Card(suit: Suit.spades, rank: Rank.nine, deckIndex: 0)],
        [const Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0), const Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0), const Card(suit: Suit.diamonds, rank: Rank.nine, deckIndex: 0)],
        [const Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0), const Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0), const Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0), const Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0)],
      ];

      final res = await service.declareGame(
        gameId: 'game_r2_invalid_test',
        myUid: 'user_p2',
        discardCard: discardCard,
        groups: invalidGroups,
      );

      expect(res['isValid'], isFalse);
      expect(res['status'], equals('COMPLETED'));
      expect(res['message'], contains('Penalized 80 pts'));

      final finalizedGame = service.getMockGame('game_r2_invalid_test')!;
      expect(finalizedGame.status, equals('COMPLETED'));
      expect(finalizedGame.winnerPlayerId, equals('user_p1'));
      expect(finalizedGame.roundHistory.length, equals(2));

      // Check Round 2 record in roundHistory
      final r2Record = finalizedGame.roundHistory[1];
      expect(r2Record['round'], equals(2));
      expect(r2Record['winnerUid'], equals('user_p1'));
      final r2Results = r2Record['results'] as List<dynamic>;
      final vamsiR2 = r2Results.firstWhere((r) => r['uid'] == 'user_p1');
      final jagadeeshR2 = r2Results.firstWhere((r) => r['uid'] == 'user_p2');
      expect(vamsiR2['roundScore'], equals(0));
      expect(vamsiR2['cumulativeScore'], equals(0));
      expect(jagadeeshR2['roundScore'], equals(80));
      expect(jagadeeshR2['cumulativeScore'], equals(104)); // 24 + 80 = 104!

      // Final results should show cumulative scores
      final vamsiFinal = finalizedGame.finalResults.firstWhere((r) => r.uid == 'user_p1');
      final jagadeeshFinal = finalizedGame.finalResults.firstWhere((r) => r.uid == 'user_p2');
      expect(vamsiFinal.score, equals(0));
      expect(vamsiFinal.isWinner, isTrue);
      expect(jagadeeshFinal.score, equals(104));
      expect(jagadeeshFinal.isWinner, isFalse);

      // Verify discarding is rejected after completion
      expect(
        service.discardCard(gameId: 'game_r2_invalid_test', myUid: 'user_p2', card: const Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0)),
        throwsA(isA<Exception>()),
      );
    });

    test('Universal clock synchronization updates offset and adjusts syncedServerNow', () {
      final service = MultiplayerService();
      final localBefore = DateTime.now();
      expect((service.syncedServerNow.difference(localBefore).inMilliseconds).abs(), lessThan(50));

      // Simulate server clock 5000ms ahead
      final serverTime = DateTime.now().add(const Duration(milliseconds: 5000));
      service.updateServerClockOffset(serverTime);

      expect(service.serverClockOffsetMs, greaterThanOrEqualTo(4900));
      expect(service.syncedServerNow.isAfter(DateTime.now().add(const Duration(milliseconds: 4500))), isTrue);
    });

    test('MultiplayerActionQueue serializes actions in FIFO order and rejects stale turn actions', () async {
      final queue = MultiplayerActionQueue();
      final executed = <String>[];
      int currentTurn = 3;

      // Enqueue action for turn 3
      final future1 = queue.enqueue<String>(
        actionType: 'DRAW_CLOSED',
        expectedTurnNumber: 3,
        currentTurnNumberGetter: () => currentTurn,
        task: () async {
          await Future.delayed(const Duration(milliseconds: 20));
          executed.add('action1');
          return 'ok1';
        },
      );

      // Enqueue action that expects turn 2 (already stale because currentTurn is 3)
      final futureStale = queue.enqueue<String>(
        actionType: 'DISCARD',
        expectedTurnNumber: 2,
        currentTurnNumberGetter: () => currentTurn,
        task: () async {
          executed.add('stale');
          return 'stale_result';
        },
      );

      // Enqueue action for turn 3
      final future2 = queue.enqueue<String>(
        actionType: 'DISCARD',
        expectedTurnNumber: 3,
        currentTurnNumberGetter: () => currentTurn,
        task: () async {
          executed.add('action2');
          return 'ok2';
        },
      );

      final r1 = await future1;
      expect(r1, equals('ok1'));
      expect(futureStale, throwsA(isA<StateError>()));
      final r2 = await future2;
      expect(r2, equals('ok2'));

      expect(executed, equals(['action1', 'action2']));
    });

    test('14-card invariant auto-reconciles hand to 13 cards when reconnecting in DRAW_PHASE', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_reconnecting',
        displayName: 'Reconnector',
        email: 'rec@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );

      // 14 cards (e.g. drew before disconnect, then opponent timed them out)
      final fourteenCards = List.generate(14, (i) => Card.fromInt(i));

      // Game state on server has moved back to DRAW_PHASE
      final serverGame = MultiplayerGameState(
        gameId: 'game_reconnect_14',
        tableId: 'table_rec',
        roomCode: 'REC123',
        status: 'IN_PROGRESS',
        playerCount: 2,
        currentTurnPlayerId: 'user_reconnecting',
        turnNumber: 2,
        phase: 'DRAW_PHASE',
        turnDeadline: DateTime.now().add(const Duration(seconds: 30)),
        jokerMode: 'OPEN',
        players: const [
          TablePlayer(uid: 'user_reconnecting', displayName: 'Reconnector', photoURL: '', seatIndex: 0, cardCount: 13),
          TablePlayer(uid: 'user_opp', displayName: 'Opponent', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        myHand: fourteenCards,
      );

      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        gameState: serverGame.copyWith(phase: 'DISCARD_PHASE'),
        cardGroups: [
          CardGroup(id: 'grp_0', type: CardGroupType.deadwood, cards: List.from(fourteenCards), isValid: false),
        ],
      );

      service.setMockPrivateHand('game_reconnect_14', 'user_reconnecting', fourteenCards);
      notifier.watchGame('game_reconnect_14');
      service.setMockGame(serverGame);

      await Future.delayed(const Duration(milliseconds: 50));

      // The notifier must have auto-trimmed the hand down to 13 cards
      final currentGroups = notifier.state.cardGroups;
      final totalCards = currentGroups.fold<int>(0, (sum, g) => sum + g.cards.length);
      expect(totalCards, equals(13));
      expect(notifier.state.gameState!.phase, equals('DRAW_PHASE'));
      expect(notifier.state.gameState!.isDrawPhase, isTrue);
    });
  });
}


