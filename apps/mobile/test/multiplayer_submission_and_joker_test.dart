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

class MockAuthNotifier extends StateNotifier<MultiplayerUser?> implements AuthNotifier {
  MockAuthNotifier(MultiplayerUser? user) : super(user);

  @override
  bool get isAuthenticated => state != null;

  @override
  Future<MultiplayerUser?> signInWithGoogle() async => state;

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
  });
}
