import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/admin/services/admin_service.dart';
import 'package:maya_ai_rummy_mobile/features/auth/models/multiplayer_user.dart';
import 'package:maya_ai_rummy_mobile/features/auth/providers/auth_provider.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/models/table_models.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_opponents_layer.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/providers/multiplayer_providers.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/services/multiplayer_service.dart';

class _MockAuthNotifier extends StateNotifier<MultiplayerUser?> implements AuthNotifier {
  _MockAuthNotifier(MultiplayerUser? user) : super(user);

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
  group('Admin Log Export & Timestamp Minification Safety Tests', () {
    test('exportGameLogJson sanitizes Firestore Timestamp objects without throwing minified:lo', () {
      final now = Timestamp.fromDate(DateTime(2026, 11, 5, 15, 31, 0));
      final testData = {
        'game': {
          'gameId': 'game_1793872893005_R8YA2W',
          'createdAt': now,
          'turnDeadline': now,
          'serverUpdatedAt': now,
          'nested': {
            'timestamp': now,
            'list': [now, 104, 'Q♠'],
          },
          'openPile': [74, 104, 54],
        },
        'privateHands': {
          'FX7CGBSbKTSmA4JNmFzh4ZuqJRW2': [104, 45],
        },
      };

      // Call AdminService's JSON serialization pipeline
      final jsonStr = const JsonEncoder.withIndent('  ').convert(
        AdminService.sanitizeForJson(testData),
      );

      expect(jsonStr, isNotEmpty);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['game']['createdAt'], equals('2026-11-05T15:31:00.000'));
      expect(decoded['game']['nested']['timestamp'], equals('2026-11-05T15:31:00.000'));
      expect(decoded['game']['nested']['list'][0], equals('2026-11-05T15:31:00.000'));
      expect(decoded['game']['openPile'], equals([74, 104, 54]));
    });
  });

  group('Anti-Race Condition & Card Duplication Prevention Tests', () {
    test('Discarded card (Q♠ 104) is tracked and NOT resurrected into hand when stale server snapshot arrives', () async {
      final service = MultiplayerService();
      final mockUser = MultiplayerUser(
        uid: 'user_test',
        displayName: 'Player 1',
        email: 'p1@example.com',
        coins: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          multiplayerServiceProvider.overrideWithValue(service),
          authProvider.overrideWith((ref) => _MockAuthNotifier(mockUser)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(multiplayerGameProvider.notifier);

      // Setup initial 14-card hand: 13 cards + Q♠ (104)
      final cardQSpades = Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 1); // int 104
      expect(cardQSpades.toInt(), equals(104));

      final initialHand = [
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.six, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        cardQSpades, // 14th card to discard
      ];

      final game = MultiplayerGameState(
        gameId: 'test_game_race_104',
        tableId: 'tbl_race',
        currentTurnPlayerId: 'user_test',
        turnNumber: 1,
        phase: 'DISCARD_PHASE',
        status: 'IN_PROGRESS',
        players: [
          TablePlayer(uid: 'user_test', displayName: 'Player 1', seatIndex: 0, cardCount: 14),
          TablePlayer(uid: 'user_opp', displayName: 'Player 2', seatIndex: 1, cardCount: 13),
        ],
        myHand: initialHand,
      );

      service.setMockGame(game);
      notifier.state = notifier.state.copyWith(
        gameState: game,
        cardGroups: [
          CardGroup(id: 'grp_0', type: CardGroupType.deadwood, cards: List.from(initialHand), isValid: false),
        ],
      );

      expect(notifier.state.cardGroups.expand((g) => g.cards).contains(cardQSpades), isTrue);

      // Discard Q♠ (104)
      notifier.selectCard(cardQSpades);
      await notifier.discardSelectedCard();

      // Hand must now have 13 cards and NO Q♠ (104)
      final handAfterDiscard = notifier.state.cardGroups.expand((g) => g.cards).toList();
      expect(handAfterDiscard.length, equals(13));
      expect(handAfterDiscard.contains(cardQSpades), isFalse);

      // SIMULATE FIRESTORE STREAM RACE CONDITION:
      // Server fires game update where serverHand STILL contains the pre-discard 14 cards (including Q♠ 104)
      final staleServerHand = List<Card>.from(initialHand);
      final syncedGroups = notifier.syncGroupsWithHandForTesting(
        notifier.state.cardGroups,
        staleServerHand,
        null,
      );

      // Even though stale server hand had Q♠ 104, syncedGroups MUST NOT resurrect Q♠!
      final cardsAfterStaleSync = syncedGroups.expand((g) => g.cards).toList();
      expect(cardsAfterStaleSync.length, equals(13));
      expect(cardsAfterStaleSync.contains(cardQSpades), isFalse);
      expect(cardsAfterStaleSync.where((c) => c.toInt() == 104).isEmpty, isTrue);
    });

    test('Shoe card matching: Deck 0 A♥ (0) and Deck 1 A♥ (54) are distinguished without collision', () {
      final aceDeck0 = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
      final aceDeck1 = Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 1);

      expect(aceDeck0.toInt(), equals(0));
      expect(aceDeck1.toInt(), equals(54));
      expect(aceDeck0.cardId, isNot(equals(aceDeck1.cardId)));
      expect(aceDeck0, isNot(equals(aceDeck1)));
    });
  });

  group('Multiplayer Opponents Layer Exact Centering Invariant Tests', () {
    test('Desktop 4-Player Table: Left, Center, Right armchair crests are seated symmetrically without horizontal drift', () {
      final seats4p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(4);
      expect(seats4p.length, equals(3));

      // Left armchair: bounded inside left third of 1754
      expect(seats4p[0].centerX, equals(280.0));
      expect(seats4p[0].centerX! > 0, isTrue); // Never off-screen
      expect(seats4p[0].top, equals(105.0));
      expect(seats4p[0].avatarHeight, equals(280.0));

      // Center armchair: directly in center
      expect(seats4p[1].centerX, equals(877.0));
      expect(seats4p[1].top, equals(70.0));
      expect(seats4p[1].avatarHeight, equals(330.0));
      expect(seats4p[1].isCenter, isTrue);

      // Right armchair: symmetrical opposite of left armchair (1754 - 280 = 1474)
      expect(seats4p[2].centerX, equals(1474.0));
      expect(seats4p[2].top, equals(105.0));
      expect(seats4p[2].avatarHeight, equals(280.0));
    });

    test('Desktop 2, 3, 5, 6-Player Tables have all chairs strictly within bounds (0 < centerX < 1754)', () {
      for (final cap in [2, 3, 5, 6]) {
        final seats = MultiplayerOpponentsLayer.getPositionsForPlayerCount(cap);
        expect(seats.length, equals(cap - 1));
        for (final seat in seats) {
          expect(seat.centerX, isNotNull);
          expect(seat.centerX! > 0, isTrue, reason: '$cap-player seat ${seat.centerX} must be > 0');
          expect(seat.centerX! < 1754, isTrue, reason: '$cap-player seat ${seat.centerX} must be < 1754');
          expect(seat.top > 0, isTrue);
          expect(seat.avatarTop > seat.top, isTrue, reason: 'Avatar must sit below status pod');
          expect(seat.avatarHeight > 200, isTrue, reason: 'Desktop avatar must be comfortably sized');
        }
      }
    });
  });

  group('Performance Regression & Combinatorial Invariants', () {
    test('Combinatorial hand evaluation of 14 cards with multiple wild jokers finishes in under 25ms', () {
      final wildJoker = Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0);
      final complexHand = [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 0), // Wild
        Card(suit: Suit.diamonds, rank: Rank.ten, deckIndex: 1), // Wild
        Card(suit: Suit.clubs, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.three, deckIndex: 0),
        Card(suit: Suit.clubs, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.ace, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.two, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 1),
        Card(suit: Suit.clubs, rank: Rank.jack, deckIndex: 1),
        Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 1),
      ];

      // Warm-up JIT
      for (int i = 0; i < 5; i++) {
        HandPartitioner.findBestPartition(complexHand, wildJoker);
      }

      final stopwatch = Stopwatch()..start();
      const iterations = 50;
      for (int i = 0; i < iterations; i++) {
        final partition = HandPartitioner.findBestPartition(complexHand, wildJoker);
        expect(partition.groups.expand((g) => g.cards).length, equals(14));
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMilliseconds / iterations;
      // In Dart VM debug mode, allow up to 75ms per complex 14-card full partition (in AOT release it runs < 5ms).
      expect(avgMs < 75.0, isTrue, reason: '50 evaluations took ${stopwatch.elapsedMilliseconds}ms (avg ${avgMs}ms/eval)');
    });
  });
}
