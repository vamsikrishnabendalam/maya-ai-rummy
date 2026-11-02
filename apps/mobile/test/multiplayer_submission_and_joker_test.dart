import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/auth/models/multiplayer_user.dart';
import 'package:maya_ai_rummy_mobile/features/auth/providers/auth_provider.dart';
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
  });
}
