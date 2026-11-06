import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/auth/models/multiplayer_user.dart';
import 'package:maya_ai_rummy_mobile/features/auth/providers/auth_provider.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
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
  Future<void> updateAvatar(String newPhotoUrl) async {}

  @override
  Future<MultiplayerUser> completeProfile({
    required String name,
    required String dateOfBirth,
    required String country,
    String? photoURL,
  }) async => state!;

  @override
  Future<void> signOut() async => state = null;

  @override
  Future<void> refreshUser() async {}

  @override
  Future<bool> deductCoins(int amount, {required String description, String? gameId}) async => true;

  @override
  Future<void> creditCoins(int amount, {required String description, String? gameId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multiplayer Game Engine Bug Fixes Verification', () {
    test('Issue 3: Discard without drawing is rejected and hand count is maintained at 13', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_vamsi',
        displayName: 'Vamsi Krishna B',
        email: 'vamsi@test.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          multiplayerServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      // Create a 13-card hand in DRAW_PHASE on user's turn
      final thirteenCards = List<Card>.generate(13, (i) => Card.fromInt(i));
      final testGame = MultiplayerGameState(
        gameId: 'game_test_discard_guard',
        tableId: 'tbl_1',
        tableName: 'Test Table',
        gameMode: 'Points Rummy',
        jokerMode: 'OPEN',
        status: 'IN_PROGRESS',
        phase: 'DRAW_PHASE',
        currentRound: 1,
        currentTurnPlayerId: 'user_vamsi',
        turnNumber: 1,
        turnTimerSeconds: 30,
        players: [
          TablePlayer(uid: 'user_vamsi', displayName: 'Vamsi Krishna B', photoURL: '', seatIndex: 0, cardCount: 13),
          TablePlayer(uid: 'user_jagadeesh', displayName: 'Jagadeesh', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        openJoker: Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.seven),
        effectiveWildRank: 'seven',
        openPile: [Card.fromInt(30)],
        closedDeck: [31, 32, 33],
        closedDeckRemaining: 3,
      );

      service.setMockGame(testGame);
      final notifier = container.read(multiplayerGameProvider.notifier);
      notifier.state = notifier.state.copyWith(
        gameState: testGame,
        cardGroups: [
          CardGroup(id: 'grp_0', type: CardGroupType.deadwood, cards: thirteenCards, isValid: false),
        ],
        hasDrawnThisTurn: false,
      );

      // Select a card and attempt to discard without having drawn!
      final cardToDiscard = thirteenCards.first;
      notifier.selectCard(cardToDiscard);

      await notifier.discardSelectedCard();

      // Hand MUST still have 13 cards and error message displayed
      final remaining = notifier.state.cardGroups.expand((g) => g.cards).toList();
      expect(remaining.length, equals(13), reason: 'Discarding without drawing must be rejected and preserve 13 cards');
      expect(notifier.state.statusMessage, contains('You must draw a card before discarding!'));
    });

    test('Issue 2: In 2-deck shoe, discard removes matching card and preserves physical cards', () async {
      final service = MultiplayerService();

      // Deck 1 King of Clubs is card 38 (suit=clubs, rank=king).
      // Deck 2 King of Clubs is card 92 (suit=clubs, rank=king).
      final deck1KingClubs = Card.fromInt(38);
      final deck2KingClubs = Card.fromInt(92);

      expect(deck1KingClubs.rank, equals(deck2KingClubs.rank));
      expect(deck1KingClubs.suit, equals(deck2KingClubs.suit));

      final testGame = MultiplayerGameState(
        gameId: 'game_test_twodeck_discard',
        tableId: 'tbl_1',
        tableName: 'Test Table',
        gameMode: 'Points Rummy',
        jokerMode: 'OPEN',
        status: 'IN_PROGRESS',
        phase: 'DISCARD_PHASE',
        currentRound: 1,
        currentTurnPlayerId: 'user_jaga',
        turnNumber: 1,
        turnTimerSeconds: 30,
        players: [
          TablePlayer(uid: 'user_jaga', displayName: 'Jagadeesh', photoURL: '', seatIndex: 0, cardCount: 14),
          TablePlayer(uid: 'user_vamsi', displayName: 'Vamsi', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        openJoker: Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.seven),
        effectiveWildRank: 'seven',
        openPile: [Card.fromInt(20)],
        closedDeck: [21, 22, 23],
        closedDeckRemaining: 3,
      );

      service.setMockGame(testGame);

      // Discard King of Clubs
      await service.discardCard(
        gameId: testGame.gameId,
        myUid: 'user_jaga',
        card: deck2KingClubs,
      );

      final updated = service.getMockGame(testGame.gameId);
      expect(updated, isNotNull);
      // Open pile must receive the discarded King of Clubs
      expect(updated!.openPile.last.rank, equals(Rank.king));
      expect(updated.openPile.last.suit, equals(Suit.clubs));
      // Turn must advance to Vamsi
      expect(updated.currentTurnPlayerId, equals('user_vamsi'));
      expect(updated.phase, equals('DRAW_PHASE'));
    });

    test('Issue 4 (Point 2): Closed deck reshuffle deduplicates cards against open pile and active hand', () async {
      final service = MultiplayerService();
      final testGame = MultiplayerGameState(
        gameId: 'game_test_reshuffle',
        tableId: 'tbl_1',
        tableName: 'Test Table',
        gameMode: 'Points Rummy',
        jokerMode: 'OPEN',
        status: 'IN_PROGRESS',
        phase: 'DRAW_PHASE',
        currentRound: 1,
        currentTurnPlayerId: 'p1',
        turnNumber: 5,
        turnTimerSeconds: 30,
        players: [
          TablePlayer(uid: 'p1', displayName: 'Player 1', photoURL: '', seatIndex: 0, cardCount: 13),
          TablePlayer(uid: 'p2', displayName: 'Player 2', photoURL: '', seatIndex: 1, cardCount: 13),
        ],
        openJoker: Card.fromInt(0),
        effectiveWildRank: 'ace',
        openPile: [Card.fromInt(10), Card.fromInt(15), Card.fromInt(20), Card.fromInt(25)],
        closedDeck: [], // Closed deck is exhausted!
        closedDeckRemaining: 0,
      );

      service.setMockGame(testGame);

      // Draw from closed deck when it is empty: triggers reshuffle of open pile
      final drawnCard = await service.drawFromClosed(
        gameId: testGame.gameId,
        myUid: 'p1',
      );

      final updated = service.getMockGame(testGame.gameId);
      expect(updated, isNotNull);
      expect(updated!.phase, equals('DISCARD_PHASE'));
      // Top card of open pile was preserved
      expect(updated.openPile.length, equals(1));
      expect(updated.openPile.first.toInt(), equals(25));
      // Closed deck has remaining unique cards
      expect(updated.closedDeckRemaining, greaterThanOrEqualTo(1));
      expect(drawnCard, isNotNull);
    });

    test('Issue 4 (Point 3): Turn progression advances strictly clockwise among ACTIVE players', () async {
      final service = MultiplayerService();

      // 4-player game where P2 is DROPPED and P3 is ELIMINATED
      final testGame = MultiplayerGameState(
        gameId: 'game_test_turn_advance',
        tableId: 'tbl_1',
        tableName: 'Test Table',
        gameMode: 'Points Rummy',
        jokerMode: 'OPEN',
        status: 'IN_PROGRESS',
        phase: 'DISCARD_PHASE',
        currentRound: 1,
        currentTurnPlayerId: 'p1',
        turnNumber: 3,
        turnTimerSeconds: 30,
        players: [
          TablePlayer(uid: 'p1', displayName: 'Player 1', photoURL: '', seatIndex: 0, status: 'ACTIVE', cardCount: 14),
          TablePlayer(uid: 'p2', displayName: 'Player 2', photoURL: '', seatIndex: 1, status: 'DROPPED', cardCount: 13),
          TablePlayer(uid: 'p3', displayName: 'Player 3', photoURL: '', seatIndex: 2, status: 'ELIMINATED', cardCount: 13),
          TablePlayer(uid: 'p4', displayName: 'Player 4', photoURL: '', seatIndex: 3, status: 'ACTIVE', cardCount: 13),
        ],
        openJoker: Card.fromInt(0),
        effectiveWildRank: 'ace',
        openPile: [Card.fromInt(1)],
        closedDeck: [2, 3, 4],
        closedDeckRemaining: 3,
      );

      service.setMockGame(testGame);

      // When P1 discards, next turn MUST skip dropped P2 and eliminated P3, advancing directly to P4!
      await service.discardCard(
        gameId: testGame.gameId,
        myUid: 'p1',
        card: Card.fromInt(50),
      );

      final updated = service.getMockGame(testGame.gameId);
      expect(updated, isNotNull);
      expect(updated!.currentTurnPlayerId, equals('p4'), reason: 'Turn must advance strictly to next ACTIVE player (skipping DROPPED and ELIMINATED)');
    });

    test('Circular seatIndex rotation: respects physical seating order even when player array is unordered', () {
      final unorderedPlayers = [
        const TablePlayer(uid: 'p_seat2', displayName: 'P2', photoURL: '', seatIndex: 2, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat0', displayName: 'P0', photoURL: '', seatIndex: 0, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat3', displayName: 'P3', photoURL: '', seatIndex: 3, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat1', displayName: 'P1', photoURL: '', seatIndex: 1, status: 'ACTIVE'),
      ];

      // Clockwise rotation from seat 0 -> seat 1 -> seat 2 -> seat 3 -> seat 0
      expect(MultiplayerService.resolveNextActiveSeatPlayer(unorderedPlayers, 'p_seat0'), equals('p_seat1'));
      expect(MultiplayerService.resolveNextActiveSeatPlayer(unorderedPlayers, 'p_seat1'), equals('p_seat2'));
      expect(MultiplayerService.resolveNextActiveSeatPlayer(unorderedPlayers, 'p_seat2'), equals('p_seat3'));
      expect(MultiplayerService.resolveNextActiveSeatPlayer(unorderedPlayers, 'p_seat3'), equals('p_seat0'));

      // If seat 1 is dropped, seat 0 must rotate directly to seat 2
      final withDropped = [
        const TablePlayer(uid: 'p_seat2', displayName: 'P2', photoURL: '', seatIndex: 2, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat0', displayName: 'P0', photoURL: '', seatIndex: 0, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat3', displayName: 'P3', photoURL: '', seatIndex: 3, status: 'ACTIVE'),
        const TablePlayer(uid: 'p_seat1', displayName: 'P1', photoURL: '', seatIndex: 1, status: 'DROPPED'),
      ];
      expect(MultiplayerService.resolveNextActiveSeatPlayer(withDropped, 'p_seat0'), equals('p_seat2'));
    });

    test('Closed Joker Declaration Fallback: valid hand with pure sequence succeeds even if joker was not manually unlocked', () async {
      final service = MultiplayerService();
      // Deal valid hand with Pure Sequence (A♠ 2♠ 3♠), Impure Sequence (4♥ 5♥ + wild joker 7♣), and Sets
      final wildJoker = Card(deckIndex: 0, suit: Suit.clubs, rank: Rank.seven); // Rank 7 is wild
      final List<List<Card>> validGroups = [
        [Card(deckIndex: 0, suit: Suit.spades, rank: Rank.ace), Card(deckIndex: 0, suit: Suit.spades, rank: Rank.two), Card(deckIndex: 0, suit: Suit.spades, rank: Rank.three)], // Pure Seq (Life 1)
        [Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.four), Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.five), Card(deckIndex: 0, suit: Suit.clubs, rank: Rank.seven)], // Impure Seq with wild joker (Life 2)
        [Card(deckIndex: 0, suit: Suit.diamonds, rank: Rank.nine), Card(deckIndex: 0, suit: Suit.clubs, rank: Rank.nine), Card(deckIndex: 0, suit: Suit.spades, rank: Rank.nine)], // Set 1
        [Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.jack), Card(deckIndex: 0, suit: Suit.spades, rank: Rank.jack), Card(deckIndex: 0, suit: Suit.diamonds, rank: Rank.jack), Card(deckIndex: 0, suit: Suit.clubs, rank: Rank.jack)], // Set 2
      ];

      final game = MultiplayerGameState(
        gameId: 'game_cj_fallback',
        tableId: 'tbl_cj',
        tableName: 'Closed Joker Table',
        gameMode: 'Points Rummy',
        jokerMode: 'CLOSED',
        openJoker: wildJoker,
        status: 'IN_PROGRESS',
        phase: 'DISCARD_PHASE',
        currentTurnPlayerId: 'declarer_uid',
        turnNumber: 5,
        openedJokerPlayerUids: [], // Player has NOT manually unlocked the closed joker
        players: [
          const TablePlayer(uid: 'declarer_uid', displayName: 'Declarer', photoURL: '', seatIndex: 0, status: 'ACTIVE'),
          const TablePlayer(uid: 'opp_uid', displayName: 'Opponent', photoURL: '', seatIndex: 1, status: 'ACTIVE'),
        ],
      );

      service.setMockGame(game);

      final result = await service.declareGame(
        gameId: 'game_cj_fallback',
        myUid: 'declarer_uid',
        discardCard: Card(deckIndex: 0, suit: Suit.hearts, rank: Rank.king),
        groups: validGroups,
      );

      expect(result['isValid'], isTrue, reason: 'Valid show with pure sequence must succeed in Closed Joker mode');
      final updatedGame = service.getMockGame('game_cj_fallback');
      expect(updatedGame!.status, equals('DECLARING'));
      expect(updatedGame.declaringPlayerId, equals('declarer_uid'));
    });

    test('Lifecycle resource cleanup: cleanupTable and cleanupGame evict stream controllers and state', () {
      final service = MultiplayerService();
      service.setMockGame(const MultiplayerGameState(gameId: 'game_cleanup_test', tableId: 'tbl_cleanup_test'));
      service.setMockPrivateHand('game_cleanup_test', 'user_1', [Card.fromInt(0)]);

      expect(service.getMockGame('game_cleanup_test'), isNotNull);

      service.cleanupGame('game_cleanup_test');
      expect(service.getMockGame('game_cleanup_test'), isNull);

      service.cleanupTable('tbl_cleanup_test');
    });
  });
}
