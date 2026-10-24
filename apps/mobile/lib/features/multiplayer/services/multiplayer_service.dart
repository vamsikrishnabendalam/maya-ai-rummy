import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_engine/game_engine.dart';
import '../models/table_models.dart';
import '../../auth/models/multiplayer_user.dart';
import '../../wallet/services/wallet_service.dart';
import '../../progression/services/progression_service.dart';
import '../../../../core/config/firebase_config.dart';

class MultiplayerService {
  static final MultiplayerService _instance = MultiplayerService._internal();
  factory MultiplayerService() => _instance;
  MultiplayerService._internal();

  final WalletService _walletService = WalletService();
  final ProgressionService _progressionService = ProgressionService();

  /// Helper: Generate collision-free, unambiguous alphanumeric room code (omits 0, O, 1, I)
  static String generateRoomCode([int length = 6]) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = math.Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  FirebaseFirestore? get _firestore => FirebaseConfig.isInitialized ? FirebaseFirestore.instance : null;
  FirebaseFunctions? get _functions => FirebaseConfig.isInitialized ? FirebaseFunctions.instance : null;

  // Local fallback mock state for offline / preview testing
  final Map<String, TableLobby> _mockTables = {};
  final Map<String, MultiplayerGameState> _mockGames = {};
  final Map<String, List<Card>> _mockPrivateHands = {}; // key: "gameId_uid"
  final Map<String, StreamController<TableLobby>> _tableControllers = {};
  final Map<String, StreamController<MultiplayerGameState>> _gameControllers = {};

  // --------------- Table Lobby Management ---------------

  /// Create Table
  Future<Map<String, String>> createTable({
    required MultiplayerUser user,
    required String tableName,
    required int maxPlayers,
    String? password,
    String gameMode = 'Points Rummy',
    int turnTimerSeconds = 30,
    int firstDropPenalty = 20,
    int middleDropPenalty = 40,
    int maxPenalty = 80,
    String entryType = 'FREE',
    int entryCoins = 0,
    String jokerMode = 'OPEN',
  }) async {
    final isCoin = entryType == 'COIN';
    const creationFee = 50;
    if (isCoin) {
      if (user.isGuest) {
        throw Exception('Guest players cannot create coin tables. Please sign in with Google.');
      }
      if (entryCoins < 100) {
        throw Exception('Minimum entry fee for coin tables is 100 virtual coins.');
      }
      if (user.coins < (entryCoins + creationFee)) {
        throw Exception('Insufficient virtual coins (${user.coins} available, ${entryCoins + creationFee} required for creation and entry).');
      }
    }

    final roomCode = generateRoomCode(6);
    final tableId = 'tbl_${DateTime.now().millisecondsSinceEpoch}_$roomCode';

    // Atomically deduct creation fee and entry fee for coin tables
    if (isCoin) {
      await _walletService.deductCoins(
        uid: user.uid,
        amount: creationFee,
        type: 'TABLE_CREATION_FEE',
        reason: 'Creation fee for table #$roomCode',
        referenceId: tableId,
      );
      await _walletService.deductCoins(
        uid: user.uid,
        amount: entryCoins,
        type: 'TABLE_ENTRY_FEE',
        reason: 'Host entry fee for table #$roomCode',
        referenceId: tableId,
      );
    }

    final hostPlayer = TablePlayer(
      uid: user.uid,
      displayName: user.displayName,
      photoURL: user.photoURL,
      seatIndex: 0,
      isHost: true,
      connected: true,
    );

    final lobby = TableLobby(
      tableId: tableId,
      roomCode: roomCode,
      tableName: tableName.isEmpty ? "${user.displayName}'s Table" : tableName,
      hostUid: user.uid,
      maxPlayers: maxPlayers,
      playerCount: 1,
      status: 'WAITING',
      hasPassword: password != null && password.isNotEmpty,
      players: [hostPlayer],
      gameMode: gameMode,
      turnTimerSeconds: turnTimerSeconds,
      firstDropPenalty: firstDropPenalty,
      middleDropPenalty: middleDropPenalty,
      maxPenalty: maxPenalty,
      entryType: entryType,
      entryCoins: isCoin ? entryCoins : 0,
      creationFee: isCoin ? creationFee : 0,
      prizePool: isCoin ? entryCoins : 0,
      jokerMode: jokerMode,
    );

    _mockTables[tableId] = lobby;
    _getOrCreateTableController(tableId).add(lobby);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('tables').doc(tableId).set(lobby.toJson());
      } catch (e) {
        debugPrint('[MultiplayerService] Direct Firestore write notice: $e');
      }
    }

    return {'tableId': tableId, 'roomCode': roomCode};
  }

  /// Join Table by Room Code
  Future<Map<String, dynamic>> joinTable({
    required MultiplayerUser user,
    required String roomCode,
    String? password,
  }) async {
    final cleanCode = roomCode.toUpperCase().trim();

    if (FirebaseConfig.isInitialized && _functions != null) {
      try {
        final callable = _functions!.httpsCallable('joinTable');
        final result = await callable.call<Map<String, dynamic>>({
          'roomCode': cleanCode,
          'password': password,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        });
        return {
          'tableId': result.data['tableId'].toString(),
          'roomCode': result.data['roomCode'].toString(),
          'seatIndex': result.data['seatIndex'] as int,
        };
      } catch (e) {
        debugPrint('[MultiplayerService] joinTable Cloud Function notice: $e');
      }
    }

    // Direct Firestore transactional join by roomCode
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final querySnap = await _firestore!
            .collection('tables')
            .where('roomCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          final docRef = querySnap.docs.first.reference;
          final result = await _firestore!.runTransaction((tx) async {
            final snap = await tx.get(docRef);
            if (!snap.exists || snap.data() == null) {
              throw Exception('Table $cleanCode not found.');
            }
            final found = TableLobby.fromJson(snap.data()!);

            // If player was previously kicked by host from this table, deny re-entry
            if (found.kickedPlayerUids.contains(user.uid)) {
              throw Exception('You were removed from this table by the host.');
            }

            // Check if player is ALREADY seated in this table
            final existingPlayerIndex = found.players.indexWhere((p) => p.uid == user.uid);
            if (existingPlayerIndex >= 0) {
              // Update displayName if changed
              if (found.players[existingPlayerIndex].displayName != user.displayName) {
                final updatedPlayers = [...found.players];
                updatedPlayers[existingPlayerIndex] = updatedPlayers[existingPlayerIndex].copyWith(
                  displayName: user.displayName,
                );
                tx.update(docRef, {
                  'players': updatedPlayers.map((p) => p.toJson()).toList(),
                });
              }
              return {
                'tableId': found.tableId,
                'roomCode': found.roomCode,
                'seatIndex': found.players[existingPlayerIndex].seatIndex,
                'activeGameId': found.activeGameId,
                'status': found.status,
                'isCoinTable': false,
                'entryCoins': 0,
              };
            }

            if (found.status == 'PLAYING') {
              throw Exception('Game has already started in room $cleanCode. Spectating or joining mid-game is not permitted.');
            }
            if (found.status == 'COMPLETED' || found.status == 'FINISHED' || found.status == 'ABANDONED') {
              throw Exception('Table $cleanCode has concluded or expired.');
            }
            if (found.players.length >= found.maxPlayers) {
              throw Exception('Table $cleanCode is full (${found.players.length}/${found.maxPlayers} players).');
            }

            if (found.isCoinTable) {
              if (user.isGuest) {
                throw Exception('Guest players cannot join coin tables. Please sign in with Google.');
              }
              if (user.coins < found.entryCoins) {
                throw Exception('Insufficient virtual coins (${user.coins} available, ${found.entryCoins} required).');
              }
            }

            // Assign lowest available seat strictly within 0..found.maxPlayers - 1
            final takenSeats = found.players.map((p) => p.seatIndex).toSet();
            int seatIndex = 0;
            while (takenSeats.contains(seatIndex) && seatIndex < found.maxPlayers) {
              seatIndex++;
            }
            if (seatIndex >= found.maxPlayers) {
              seatIndex = found.players.length;
            }

            final newPlayer = TablePlayer(
              uid: user.uid,
              displayName: user.displayName,
              photoURL: user.photoURL,
              seatIndex: seatIndex,
              isHost: false,
              connected: true,
            );

            final updatedPlayers = [...found.players, newPlayer];
            tx.update(docRef, {
              'players': updatedPlayers.map((p) => p.toJson()).toList(),
              'playerCount': updatedPlayers.length,
              'prizePool': found.prizePool + (found.isCoinTable ? found.entryCoins : 0),
            });

            return {
              'tableId': found.tableId,
              'roomCode': found.roomCode,
              'seatIndex': seatIndex,
              'activeGameId': found.activeGameId,
              'status': found.status,
              'isCoinTable': found.isCoinTable,
              'entryCoins': found.entryCoins,
            };
          });

          if (result['isCoinTable'] == true && (result['entryCoins'] as int? ?? 0) > 0) {
            await _walletService.deductCoins(
              uid: user.uid,
              amount: result['entryCoins'] as int,
              type: 'TABLE_ENTRY_FEE',
              reason: 'Entry fee for table #$cleanCode',
              referenceId: result['tableId'] as String,
            );
          }

          return {
            'tableId': result['tableId'],
            'roomCode': result['roomCode'],
            'seatIndex': result['seatIndex'],
            'activeGameId': result['activeGameId'],
            'status': result['status'],
          };
        }
      } catch (e) {
        debugPrint('[MultiplayerService] joinTable Firestore transaction error: $e');
        if (e.toString().contains('full') || e.toString().contains('started') || e.toString().contains('not found')) {
          rethrow;
        }
      }
    }

    // Local / Offline fallback lookup
    TableLobby? found;
    for (final t in _mockTables.values) {
      if (t.roomCode == cleanCode) {
        found = t;
        break;
      }
    }

    if (found == null) {
      throw Exception('Table $cleanCode not found. Please verify the room code.');
    }

    // If player was previously kicked by host from this table, deny re-entry
    if (found.kickedPlayerUids.contains(user.uid)) {
      throw Exception('You were removed from this table by the host.');
    }

    // Check if player is ALREADY seated in this table
    final existingPlayerIndex = found.players.indexWhere((p) => p.uid == user.uid);
    if (existingPlayerIndex >= 0) {
      return {
        'tableId': found.tableId,
        'roomCode': found.roomCode,
        'seatIndex': found.players[existingPlayerIndex].seatIndex,
        'activeGameId': found.activeGameId,
        'status': found.status,
      };
    }

    if (found.status == 'PLAYING') {
      throw Exception('Game has already started in room $cleanCode. Spectating or joining mid-game is not permitted.');
    }

    if (found.status == 'COMPLETED' || found.status == 'FINISHED' || found.status == 'ABANDONED') {
      throw Exception('Table $cleanCode has concluded or expired.');
    }

    if (found.players.length >= found.maxPlayers) {
      throw Exception('Table $cleanCode is full (${found.players.length}/${found.maxPlayers} players).');
    }

    if (found.isCoinTable) {
      if (user.isGuest) {
        throw Exception('Guest players cannot join coin tables. Please sign in with Google.');
      }
      if (user.coins < found.entryCoins) {
        throw Exception('Insufficient virtual coins (${user.coins} available, ${found.entryCoins} required).');
      }
      await _walletService.deductCoins(
        uid: user.uid,
        amount: found.entryCoins,
        type: 'TABLE_ENTRY_FEE',
        reason: 'Entry fee for table #$cleanCode',
        referenceId: found.tableId,
      );
    }

    final takenSeats = found.players.map((p) => p.seatIndex).toSet();
    int seatIndex = 0;
    while (takenSeats.contains(seatIndex)) {
      seatIndex++;
    }

    final newPlayer = TablePlayer(
      uid: user.uid,
      displayName: user.displayName,
      photoURL: user.photoURL,
      seatIndex: seatIndex,
      isHost: false,
      connected: true,
    );

    final updatedPlayers = [...found.players, newPlayer];
    final updatedLobby = found.copyWith(
      players: updatedPlayers,
      playerCount: updatedPlayers.length,
      prizePool: found.prizePool + (found.isCoinTable ? found.entryCoins : 0),
    );

    _mockTables[found.tableId] = updatedLobby;
    _getOrCreateTableController(found.tableId).add(updatedLobby);

    return {
      'tableId': found.tableId,
      'roomCode': found.roomCode,
      'seatIndex': seatIndex,
      'activeGameId': found.activeGameId,
      'status': found.status,
    };
  }

  /// Leave Table
  Future<void> leaveTable(String tableId, String uid) async {
    if (FirebaseConfig.isInitialized && _functions != null) {
      try {
        final callable = _functions!.httpsCallable('leaveTable');
        await callable.call({'tableId': tableId});
        return;
      } catch (e) {
        debugPrint('[MultiplayerService] leaveTable Cloud Function notice: $e');
      }
    }

    final lobby = _mockTables[tableId];
    if (lobby != null) {
      if (lobby.isCoinTable && lobby.status == 'WAITING') {
        // Refund leaving player's entry fee
        try {
          await _walletService.creditCoins(
            uid: uid,
            amount: lobby.entryCoins,
            type: 'GAME_REFUND',
            reason: 'Refunded entry fee for leaving table #${lobby.roomCode}',
            referenceId: tableId,
          );
        } catch (e) {
          debugPrint('[MultiplayerService] leaveTable refund notice: $e');
        }
      }

      final rem = lobby.players.where((p) => p.uid != uid).toList();
      TableLobby updated;
      if (rem.isEmpty) {
        if (lobby.isCoinTable && lobby.status == 'WAITING' && lobby.hostUid == uid) {
          // Refund table creation fee to host as table was cancelled before start
          try {
            await _walletService.creditCoins(
              uid: uid,
              amount: lobby.creationFee,
              type: 'GAME_REFUND',
              reason: 'Refunded table creation fee for cancelled table #${lobby.roomCode}',
              referenceId: tableId,
            );
          } catch (_) {}
        }
        updated = lobby.copyWith(status: 'ABANDONED', players: [], prizePool: 0);
      } else {
        if (lobby.hostUid == uid) {
          rem[0] = rem[0].copyWith(isHost: true);
        }
        updated = lobby.copyWith(
          players: rem,
          playerCount: rem.length,
          hostUid: rem[0].uid,
          prizePool: lobby.prizePool - (lobby.isCoinTable ? lobby.entryCoins : 0),
        );
      }
      _mockTables[tableId] = updated;
      _getOrCreateTableController(tableId).add(updated);

      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('tables').doc(tableId).set(updated.toJson());
        } catch (_) {}
      }
    }
  }

  /// Host Remove / Kick Player from Lobby (Before Game Starts)
  Future<void> kickPlayerFromTable({
    required String tableId,
    required String hostUid,
    required String targetUid,
  }) async {
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final tableRef = _firestore!.collection('tables').doc(tableId);
        await _firestore!.runTransaction((tx) async {
          final snap = await tx.get(tableRef);
          if (!snap.exists || snap.data() == null) throw Exception('Table not found');
          final data = snap.data()!;
          if (data['hostUid'] != hostUid) throw Exception('Only the table host can remove players.');
          if (data['status'] != 'WAITING') throw Exception('Cannot remove player: Game is already in progress.');

          final rawPlayers = (data['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => Map<String, dynamic>.from(p as Map)).toList();
          final targetIdx = players.indexWhere((p) => p['uid'] == targetUid);
          if (targetIdx < 0) return;

          final isCoinTable = (data['isCoinTable'] as bool?) ?? false;
          final entryCoins = (data['entryCoins'] as int?) ?? 0;
          final currentPrizePool = (data['prizePool'] as int?) ?? 0;

          players.removeAt(targetIdx);

          final rawKicked = (data['kickedPlayerUids'] as List<dynamic>?) ?? [];
          final kickedUids = rawKicked.map((e) => e.toString()).toSet();
          kickedUids.add(targetUid);

          tx.update(tableRef, {
            'players': players,
            'playerCount': players.length,
            'prizePool': isCoinTable ? math.max(0, currentPrizePool - entryCoins) : 0,
            'kickedPlayerUids': kickedUids.toList(),
          });
        });
      } catch (e) {
        debugPrint('[MultiplayerService] kickPlayerFromTable error: $e');
        rethrow;
      }
      return;
    }

    // Local / Offline Simulation
    final lobby = _mockTables[tableId];
    if (lobby != null && lobby.hostUid == hostUid && lobby.status == 'WAITING') {
      final rem = lobby.players.where((p) => p.uid != targetUid).toList();
      final updatedKicked = {...lobby.kickedPlayerUids, targetUid}.toList();
      final updated = lobby.copyWith(
        players: rem,
        playerCount: rem.length,
        prizePool: lobby.prizePool - (lobby.isCoinTable ? lobby.entryCoins : 0),
        kickedPlayerUids: updatedKicked,
      );
      _mockTables[tableId] = updated;
      _getOrCreateTableController(tableId).add(updated);
    }
  }

  /// Start Game (Host only) - Authoritative deal of 13 cards per player with full invariants
  Future<String> startGame(String tableId) async {
    if (FirebaseConfig.isInitialized && _functions != null) {
      try {
        final callable = _functions!.httpsCallable('startGame');
        final result = await callable.call<Map<String, dynamic>>({'tableId': tableId});
        return result.data['gameId'].toString();
      } catch (e) {
        debugPrint('[MultiplayerService] startGame Cloud Function notice: $e');
      }
    }

    // Retrieve authoritative Table Lobby from Firestore or local cache
    TableLobby? lobby;
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final doc = await _firestore!.collection('tables').doc(tableId).get();
        if (doc.exists && doc.data() != null) {
          lobby = TableLobby.fromJson(doc.data()!);
        }
      } catch (_) {}
    }
    lobby ??= _mockTables[tableId];

    if (lobby == null) {
      throw Exception('Table $tableId not found.');
    }

    // Section 6: Deal Idempotency Check
    if (lobby.status == 'PLAYING' && lobby.activeGameId != null) {
      debugPrint('[MultiplayerService] startGame idempotent recall: already PLAYING, returning activeGameId=${lobby.activeGameId}');
      return lobby.activeGameId!;
    }

    if (lobby.players.length < 2) {
      throw Exception('At least 2 players required to start a game.');
    }

    // Deduplicate players if any duplicate joins slipped through
    final dedupedPlayers = <TablePlayer>[];
    final seenUids = <String>{};
    for (final p in lobby.players) {
      if (!seenUids.contains(p.uid)) {
        seenUids.add(p.uid);
        dedupedPlayers.add(p);
      }
    }
    if (dedupedPlayers.length != lobby.players.length) {
      lobby = lobby.copyWith(players: dedupedPlayers, playerCount: dedupedPlayers.length);
    }

    final gameId = 'game_${DateTime.now().millisecondsSinceEpoch}_${generateRoomCode(6)}';

    // Deck & Cards: 2 players = 1 deck (54 cards), 3+ players = 2 decks (108 cards)
    final numDecks = lobby.players.length <= 2 ? 1 : 2;
    final expectedTotalCards = numDecks * 54;
    final deck = Deck.initialize(numDecks);
    final allCards = List<Card>.from(deck.cards);

    // 1. Cut Open Wild Joker
    final openJoker = allCards.removeLast();
    final effectiveWildRank = JokerUtils.getEffectiveWildRank(openJoker)?.name ?? 'ace';

    // 2. Deal EXACTLY 13 cards to each player (2 to 6 players)
    final playerHands = <String, List<Card>>{};
    for (final p in lobby.players) {
      final hand = <Card>[];
      for (int i = 0; i < 13; i++) {
        hand.add(allCards.removeLast());
      }
      playerHands[p.uid] = hand;
      _mockPrivateHands['${gameId}_${p.uid}'] = hand;
    }

    // 3. Flip first card for Open Discard Pile
    final firstOpenCard = allCards.removeLast();

    // 4. Remaining cards form Authoritative Closed Deck
    final closedDeckInts = allCards.map((c) => c.toInt()).toList();

    final now = DateTime.now();

    // Section 8: Strict Post-Deal Assertion (Every player must have EXACTLY 13 cards)
    for (final p in lobby.players) {
      final pHand = playerHands[p.uid];
      if (pHand == null || pHand.length != 13) {
        final actual = pHand?.length ?? 0;
        debugPrint('[MultiplayerService] DEAL_VALIDATION_FAILED: gameId=$gameId, playerId=${p.uid}, expectedCardCount=13, actualCardCount=$actual, timestamp=${now.toIso8601String()}');
        throw Exception('DEAL_VALIDATION_FAILED: Player ${p.displayName} (${p.uid}) received $actual cards instead of 13.');
      }
    }

    // Section 9: First-Round Physical Invariant & Uniqueness Validation
    final allPhysicalCardsAccounted = <int>[
      openJoker.toInt(),
      firstOpenCard.toInt(),
      ...closedDeckInts,
    ];
    for (final p in lobby.players) {
      allPhysicalCardsAccounted.addAll(playerHands[p.uid]!.map((c) => c.toInt()));
    }

    if (allPhysicalCardsAccounted.length != expectedTotalCards) {
      debugPrint('[MultiplayerService] DEAL_VALIDATION_FAILED: Total cards accounted ${allPhysicalCardsAccounted.length} != $expectedTotalCards');
      throw Exception('DEAL_VALIDATION_FAILED: Total accounted cards ${allPhysicalCardsAccounted.length} != $expectedTotalCards.');
    }

    final distinctAccounted = allPhysicalCardsAccounted.toSet();
    if (distinctAccounted.length != expectedTotalCards) {
      debugPrint('[MultiplayerService] DEAL_VALIDATION_FAILED: Duplicate card detected across table: distinct=${distinctAccounted.length}');
      throw Exception('DEAL_VALIDATION_FAILED: Duplicate physical card ownership detected across table.');
    }

    final isClosedJoker = lobby.jokerMode == 'CLOSED';
    final initialActionLog = [
      {
        'seq': 1,
        'timestamp': now.toIso8601String(),
        'type': 'GAME_STARTED',
        'playerId': lobby.hostUid,
        'description': 'Game started with ${lobby.players.length} players. Room: ${lobby.roomCode}',
      },
      if (isClosedJoker)
        {
          'seq': 2,
          'timestamp': now.toIso8601String(),
          'type': 'CLOSED_JOKER_DRAWN',
          'playerId': lobby.hostUid,
          'description': 'Closed Joker placed face-down. Pure Sequence (Life) required to view.',
        }
      else
        {
          'seq': 2,
          'timestamp': now.toIso8601String(),
          'type': 'OPEN_JOKER_REVEALED',
          'playerId': lobby.hostUid,
          'card': openJoker.toInt(),
          'description': 'Open Joker cut: ${openJoker.label} (${effectiveWildRank.toUpperCase()} is Wild)',
        },
      {
        'seq': 3,
        'timestamp': now.toIso8601String(),
        'type': 'CARDS_DEALT',
        'playerId': lobby.hostUid,
        'card': firstOpenCard.toInt(),
        'description': '13 cards dealt to each player. First discard flipped: ${firstOpenCard.label}',
      },
    ];

    final updatedPlayers = lobby.players.map((p) => p.copyWith(cardCount: 13, status: 'ACTIVE')).toList();

    final mGameState = MultiplayerGameState(
      gameId: gameId,
      tableId: tableId,
      roomCode: lobby.roomCode,
      tableName: lobby.tableName,
      gameMode: lobby.gameMode,
      status: 'IN_PROGRESS',
      playerCount: lobby.players.length,
      currentTurnPlayerId: lobby.players[0].uid,
      turnNumber: 0,
      phase: 'DRAW_PHASE',
      turnTimerSeconds: lobby.turnTimerSeconds,
      firstDropPenalty: lobby.firstDropPenalty,
      middleDropPenalty: lobby.middleDropPenalty,
      maxPenalty: lobby.maxPenalty,
      entryType: lobby.entryType,
      entryCoins: lobby.entryCoins,
      creationFee: lobby.creationFee,
      prizePool: lobby.prizePool > 0 ? lobby.prizePool : (lobby.isCoinTable ? lobby.players.length * lobby.entryCoins : 0),
      turnDeadline: lobby.turnTimerSeconds <= 0 ? null : now.add(Duration(seconds: lobby.turnTimerSeconds + 5)),
      jokerMode: lobby.jokerMode,
      openedJokerPlayerUids: const [],
      openJoker: openJoker,
      effectiveWildRank: effectiveWildRank,
      openPile: [firstOpenCard],
      closedDeck: closedDeckInts,
      closedDeckRemaining: closedDeckInts.length,
      dealerPlayerId: lobby.players.last.uid,
      players: updatedPlayers,
      actionLog: initialActionLog,
      startedAt: now,
    );

    _mockGames[gameId] = mGameState;
    final updatedLobby = lobby.copyWith(status: 'PLAYING', activeGameId: gameId);
    _mockTables[tableId] = updatedLobby;

    _getOrCreateTableController(tableId).add(updatedLobby);
    _getOrCreateGameController(gameId).add(mGameState);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final batch = _firestore!.batch();
        batch.set(_firestore!.collection('tables').doc(tableId), updatedLobby.toJson());
        batch.set(_firestore!.collection('games').doc(gameId), mGameState.toJson());

        for (final p in lobby.players) {
          final hand = playerHands[p.uid] ?? [];
          batch.set(
            _firestore!.collection('games').doc(gameId).collection('privateHands').doc(p.uid),
            {'cards': hand.map((c) => c.toInt()).toList()},
          );
        }
        await batch.commit();
      } catch (e) {
        debugPrint('[MultiplayerService] startGame Firestore write notice: $e');
      }
    }

    return gameId;
  }

  // --------------- In-Game Server Actions ---------------

  /// Draw from closed deck (Popped from authoritative remaining closed deck)
  Future<Card> drawFromClosed({required String gameId, required String myUid}) async {
    // 1. Transactional Firestore Draw
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        final handRef = gameRef.collection('privateHands').doc(myUid);

        return await _firestore!.runTransaction((tx) async {
          final gameSnap = await tx.get(gameRef);
          if (!gameSnap.exists) throw Exception('Game $gameId not found');

          final gameData = gameSnap.data()!;
          final currentTurnUid = gameData['currentTurnPlayerId'] as String?;
          final phase = gameData['phase'] as String?;
          if (currentTurnUid != myUid) throw Exception('Not your turn to draw');
          if (phase != 'DRAW_PHASE') throw Exception('Invalid phase for draw: $phase');

          final rawClosedDeck = (gameData['closedDeck'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          final rawOpenPile = (gameData['openPile'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];

          List<int> closedDeck = List<int>.from(rawClosedDeck);
          List<int> openPile = List<int>.from(rawOpenPile);

          // If closed deck is empty, reshuffle open pile (keeping top card) into closed deck
          if (closedDeck.isEmpty) {
            if (openPile.length <= 1) {
              throw Exception('No cards remaining in closed deck or discard pile to draw.');
            }
            final topOpenCard = openPile.removeLast();
            closedDeck = List<int>.from(openPile)..shuffle();
            openPile = [topOpenCard];
          }

          final drawnCardInt = closedDeck.removeLast();
          final drawnCard = Card.fromInt(drawnCardInt);

          // Read hand
          final handSnap = await tx.get(handRef);
          List<dynamic> existingCards = [];
          if (handSnap.exists && handSnap.data() != null) {
            existingCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
          }
          if (existingCards.length >= 14) {
            throw Exception('Cannot draw: hand already contains 14 cards.');
          }
          existingCards.add(drawnCardInt);

          // Update player card counts
          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final updatedPlayers = rawPlayers.map((pMap) {
            final p = Map<String, dynamic>.from(pMap as Map);
            if (p['uid'] == myUid) {
              p['cardCount'] = existingCards.length;
            }
            return p;
          }).toList();

          // Action log
          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final playerDisplayName = (updatedPlayers.firstWhere((p) => p['uid'] == myUid, orElse: () => {'displayName': 'Player'}))['displayName'];

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'DRAW_CLOSED',
            'playerId': myUid,
            'description': '$playerDisplayName drew a card from Closed Deck',
          });

          tx.update(gameRef, {
            'closedDeck': closedDeck,
            'closedDeckRemaining': closedDeck.length,
            'openPile': openPile,
            'phase': 'DISCARD_PHASE',
            'cardDrawnFromOpenThisTurn': null,
            'players': updatedPlayers,
            'actionLog': actionLog,
          });

          tx.set(handRef, {'cards': existingCards});

          return drawnCard;
        });
      } catch (e) {
        debugPrint('[MultiplayerService] drawFromClosed Firestore Transaction notice: $e');
      }
    }

    // 2. Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');
    if (game.currentTurnPlayerId != myUid) throw Exception('Not your turn to draw');
    if (!game.isDrawPhase) throw Exception('Not in draw phase');

    List<int> closedDeck = List<int>.from(game.closedDeck);
    List<Card> openPile = List<Card>.from(game.openPile);

    if (closedDeck.isEmpty) {
      if (openPile.length <= 1) {
        throw Exception('No cards remaining to draw.');
      }
      final top = openPile.removeLast();
      closedDeck = openPile.map((c) => c.toInt()).toList()..shuffle();
      openPile = [top];
    }

    final drawnCardInt = closedDeck.removeLast();
    final drawnCard = Card.fromInt(drawnCardInt);

    final hand = _mockPrivateHands['${gameId}_$myUid'] ?? [];
    if (hand.length >= 14) {
      throw Exception('Cannot draw: hand already contains 14 cards.');
    }
    hand.add(drawnCard);

    final updatedPlayers = game.players.map((p) {
      if (p.uid == myUid) return p.copyWith(cardCount: hand.length);
      return p;
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    final pName = updatedPlayers.firstWhere((p) => p.uid == myUid, orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0)).displayName;
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'DRAW_CLOSED',
      'playerId': myUid,
      'description': '$pName drew a card from Closed Deck',
    });

    final updatedGame = game.copyWith(
      phase: 'DISCARD_PHASE',
      closedDeck: closedDeck,
      closedDeckRemaining: closedDeck.length,
      openPile: openPile,
      clearCardDrawnFromOpen: true,
      players: updatedPlayers,
      myHand: hand,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    return drawnCard;
  }

  /// Draw from open pile
  Future<Card> drawFromOpen({required String gameId, required String myUid}) async {
    // 1. Transactional Firestore Draw
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        final handRef = gameRef.collection('privateHands').doc(myUid);

        return await _firestore!.runTransaction((tx) async {
          final gameSnap = await tx.get(gameRef);
          if (!gameSnap.exists) throw Exception('Game not found');

          final gameData = gameSnap.data()!;
          if (gameData['currentTurnPlayerId'] != myUid) throw Exception('Not your turn to draw');
          if (gameData['phase'] != 'DRAW_PHASE') throw Exception('Not in draw phase');

          final rawOpenPile = (gameData['openPile'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          if (rawOpenPile.isEmpty) throw Exception('Discard pile is empty');

          final openPile = List<int>.from(rawOpenPile);
          final drawnCardInt = openPile.removeLast();
          final drawnCard = Card.fromInt(drawnCardInt);

          // Read hand
          final handSnap = await tx.get(handRef);
          List<dynamic> existingCards = [];
          if (handSnap.exists && handSnap.data() != null) {
            existingCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
          }
          if (existingCards.length >= 14) {
            throw Exception('Cannot draw: hand already contains 14 cards.');
          }
          existingCards.add(drawnCardInt);

          // Update player card counts
          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final updatedPlayers = rawPlayers.map((pMap) {
            final p = Map<String, dynamic>.from(pMap as Map);
            if (p['uid'] == myUid) {
              p['cardCount'] = existingCards.length;
            }
            return p;
          }).toList();

          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final playerDisplayName = (updatedPlayers.firstWhere((p) => p['uid'] == myUid, orElse: () => {'displayName': 'Player'}))['displayName'];

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'DRAW_OPEN',
            'playerId': myUid,
            'card': drawnCardInt,
            'description': '$playerDisplayName drew ${drawnCard.label} from Open Pile',
          });

          tx.update(gameRef, {
            'openPile': openPile,
            'phase': 'DISCARD_PHASE',
            'cardDrawnFromOpenThisTurn': drawnCardInt,
            'players': updatedPlayers,
            'actionLog': actionLog,
          });

          tx.set(handRef, {'cards': existingCards});

          return drawnCard;
        });
      } catch (e) {
        debugPrint('[MultiplayerService] drawFromOpen Firestore Transaction notice: $e');
      }
    }

    // 2. Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null || game.openPile.isEmpty) throw Exception('Open pile is empty');
    if (game.currentTurnPlayerId != myUid) throw Exception('Not your turn');

    final hand = _mockPrivateHands['${gameId}_$myUid'] ?? [];
    if (hand.length >= 14) {
      throw Exception('Cannot draw: hand already contains 14 cards.');
    }
    final openPile = List<Card>.from(game.openPile);
    final drawnCard = openPile.removeLast();
    hand.add(drawnCard);

    final updatedPlayers = game.players.map((p) {
      if (p.uid == myUid) return p.copyWith(cardCount: hand.length);
      return p;
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    final pName = updatedPlayers.firstWhere((p) => p.uid == myUid, orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0)).displayName;
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'DRAW_OPEN',
      'playerId': myUid,
      'card': drawnCard.toInt(),
      'description': '$pName drew ${drawnCard.label} from Open Pile',
    });

    final updatedGame = game.copyWith(
      openPile: openPile,
      phase: 'DISCARD_PHASE',
      cardDrawnFromOpenThisTurn: drawnCard,
      players: updatedPlayers,
      myHand: hand,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    return drawnCard;
  }

  /// Discard card with atomic turn rotation and Indian Rummy rules
  Future<void> discardCard({
    required String gameId,
    required String myUid,
    required Card card,
  }) async {
    // 1. Transactional Firestore Discard
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        final handRef = gameRef.collection('privateHands').doc(myUid);

        await _firestore!.runTransaction((tx) async {
          final gameSnap = await tx.get(gameRef);
          if (!gameSnap.exists) throw Exception('Game not found');

          final gameData = gameSnap.data()!;
          if (gameData['currentTurnPlayerId'] != myUid) throw Exception('Not your turn to discard');
          if (gameData['phase'] != 'DISCARD_PHASE') throw Exception('Not in discard phase');

          // Indian Rummy open draw rule: Cannot discard same card drawn from open pile in this turn
          final openDrawnInt = gameData['cardDrawnFromOpenThisTurn'] as int?;
          if (openDrawnInt != null && openDrawnInt == card.toInt()) {
            throw Exception('Cannot discard the card drawn from the open pile in the same turn');
          }

          // Check card in hand
          final handSnap = await tx.get(handRef);
          List<dynamic> existingCards = [];
          if (handSnap.exists && handSnap.data() != null) {
            existingCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
          }

          final cardInt = card.toInt();
          final removeIndex = existingCards.indexWhere((c) {
            if (c is int) return c == cardInt;
            if (c is Map) return (c['intVal'] ?? c['val']) == cardInt;
            return false;
          });

          if (removeIndex >= 0) {
            existingCards.removeAt(removeIndex);
          } else {
            if (existingCards.isNotEmpty) existingCards.removeLast();
          }

          // Append to open pile
          final openPile = (gameData['openPile'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          openPile.add(cardInt);

          // Advance turn to next active player
          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final activePlayers = rawPlayers.where((p) => (p as Map)['status'] == 'ACTIVE').toList();
          final currentIdx = activePlayers.indexWhere((p) => (p as Map)['uid'] == myUid);
          final nextIdx = (currentIdx >= 0 && activePlayers.isNotEmpty) ? ((currentIdx + 1) % activePlayers.length) : 0;
          final nextPlayerId = activePlayers.isNotEmpty ? (activePlayers[nextIdx] as Map)['uid'] as String : myUid;

          final updatedPlayers = rawPlayers.map((pMap) {
            final p = Map<String, dynamic>.from(pMap as Map);
            if (p['uid'] == myUid) {
              p['cardCount'] = existingCards.length;
            }
            return p;
          }).toList();

          final currentTurnNum = (gameData['turnNumber'] as int?) ?? 0;
          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final playerDisplayName = (updatedPlayers.firstWhere((p) => p['uid'] == myUid, orElse: () => {'displayName': 'Player'}))['displayName'];

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': DateTime.now().toIso8601String(),
            'type': 'DISCARD',
            'playerId': myUid,
            'card': cardInt,
            'description': '$playerDisplayName discarded ${card.label}',
          });

          final turnTimerSec = (gameData['turnTimerSeconds'] as int?) ?? 30;
          final nextDeadline = turnTimerSec > 0
              ? DateTime.now().add(Duration(seconds: turnTimerSec + 5)).toIso8601String()
              : null;
          tx.update(gameRef, {
            'openPile': openPile,
            'currentTurnPlayerId': nextPlayerId,
            'turnNumber': currentTurnNum + 1,
            'phase': 'DRAW_PHASE',
            'turnDeadline': nextDeadline,
            'cardDrawnFromOpenThisTurn': null,
            'players': updatedPlayers,
            'actionLog': actionLog,
          });

          tx.set(handRef, {'cards': existingCards});
        });
        return;
      } catch (e) {
        debugPrint('[MultiplayerService] discardCard Firestore Transaction notice: $e');
      }
    }

    // 2. Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');

    if (game.cardDrawnFromOpenThisTurn != null && game.cardDrawnFromOpenThisTurn == card) {
      throw Exception('Cannot discard the card drawn from the open pile in the same turn');
    }

    final hand = _mockPrivateHands['${gameId}_$myUid'] ?? [];
    hand.remove(card);

    final openPile = List<Card>.from(game.openPile)..add(card);

    final active = game.players.where((p) => p.status == 'ACTIVE').toList();
    final cIdx = active.indexWhere((p) => p.uid == myUid);
    final nIdx = (cIdx >= 0 && active.isNotEmpty) ? ((cIdx + 1) % active.length) : 0;
    final nextPlayerId = active.isNotEmpty ? active[nIdx].uid : myUid;

    final updatedPlayers = game.players.map((p) {
      if (p.uid == myUid) return p.copyWith(cardCount: hand.length);
      return p;
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    final pName = updatedPlayers.firstWhere((p) => p.uid == myUid, orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0)).displayName;
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'DISCARD',
      'playerId': myUid,
      'card': card.toInt(),
      'description': '$pName discarded ${card.label}',
    });

    final turnTimerSec = game.turnTimerSeconds;
    final nextDeadline = turnTimerSec > 0 ? DateTime.now().add(Duration(seconds: turnTimerSec + 5)) : null;
    final updatedGame = game.copyWith(
      openPile: openPile,
      currentTurnPlayerId: nextPlayerId,
      turnNumber: game.turnNumber + 1,
      phase: 'DRAW_PHASE',
      turnDeadline: nextDeadline,
      clearCardDrawnFromOpen: true,
      players: updatedPlayers,
      myHand: hand,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);
  }

  /// Drop Game during DRAW_PHASE (First Drop or Middle Drop)
  Future<void> dropGame({
    required String gameId,
    required String myUid,
  }) async {
    // 1. Transactional Firestore Drop
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);

        await _firestore!.runTransaction((tx) async {
          final gameSnap = await tx.get(gameRef);
          if (!gameSnap.exists) throw Exception('Game not found');

          final gameData = gameSnap.data()!;
          if (gameData['currentTurnPlayerId'] != myUid) throw Exception('Not your turn to drop');
          if (gameData['phase'] != 'DRAW_PHASE') throw Exception('Cannot drop after drawing a card. You must discard.');

          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => TablePlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList();
          final pIdx = players.indexWhere((p) => p.uid == myUid);
          if (pIdx < 0) throw Exception('Player not found in game');

          final turnNum = (gameData['turnNumber'] as int?) ?? 0;
          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();

          final hasDrawnOrDiscarded = actionLog.any((a) =>
              a['playerId'] == myUid &&
              (a['type'] == 'DRAW_CLOSED' || a['type'] == 'DRAW_OPEN' || a['type'] == 'DISCARD'));
          final isFirstDrop = turnNum == 0 || !hasDrawnOrDiscarded;
          final firstDropPenalty = (gameData['firstDropPenalty'] as int?) ?? 20;
          final middleDropPenalty = (gameData['middleDropPenalty'] as int?) ?? 40;
          final penalty = isFirstDrop ? firstDropPenalty : middleDropPenalty;

          final droppedPlayer = players[pIdx].copyWith(status: 'DROPPED', score: penalty);
          players[pIdx] = droppedPlayer;

          final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();
          final now = DateTime.now();

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'DROP',
            'playerId': myUid,
            'description': '${droppedPlayer.displayName} dropped from the round ($penalty pts, ${isFirstDrop ? "First Drop" : "Middle Drop"}).',
          });

          if (remainingActive.length <= 1) {
            final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
            final finalResults = players.map((p) {
              final isWin = p.uid == winner.uid;
              return MultiplayerFinalResult(
                uid: p.uid,
                displayName: p.displayName,
                photoURL: p.photoURL,
                seatIndex: p.seatIndex,
                score: isWin ? 0 : p.score,
                isWinner: isWin,
              );
            }).toList();

            tx.update(gameRef, {
              'status': 'COMPLETED',
              'winnerPlayerId': winner.uid,
              'finalResults': finalResults.map((r) => r.toJson()).toList(),
              'players': players.map((p) => p.toJson()).toList(),
              'actionLog': actionLog,
              'endedAt': now.toIso8601String(),
            });

            final tableId = gameData['tableId'] as String? ?? '';
            if (tableId.isNotEmpty) {
              tx.update(_firestore!.collection('tables').doc(tableId), {
                'status': 'WAITING',
                'activeGameId': null,
              });
            }
          } else {
            // Advance turn to the next active player in sequential circular seat order
            TablePlayer? nextPlayer;
            for (int i = 1; i < players.length; i++) {
              final candidate = players[(pIdx + i) % players.length];
              if (candidate.status == 'ACTIVE') {
                nextPlayer = candidate;
                break;
              }
            }
            nextPlayer ??= remainingActive.isNotEmpty ? remainingActive.first : players.first;

            final turnTimerSec = (gameData['turnTimerSeconds'] as int?) ?? 30;
            final nextDeadline = turnTimerSec > 0
                ? now.add(Duration(seconds: turnTimerSec + 5)).toIso8601String()
                : null;

            tx.update(gameRef, {
              'players': players.map((p) => p.toJson()).toList(),
              'currentTurnPlayerId': nextPlayer.uid,
              'turnNumber': turnNum + 1,
              'phase': 'DRAW_PHASE',
              'turnDeadline': nextDeadline,
              'cardDrawnFromOpenThisTurn': null,
              'actionLog': actionLog,
            });
          }
        });
        return;
      } catch (e) {
        debugPrint('[MultiplayerService] dropGame Firestore notice: $e');
      }
    }

    // 2. Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');
    if (game.currentTurnPlayerId != myUid) throw Exception('Not your turn to drop');
    if (game.phase != 'DRAW_PHASE') throw Exception('Cannot drop after drawing a card. You must discard.');

    final players = List<TablePlayer>.from(game.players);
    final pIdx = players.indexWhere((p) => p.uid == myUid);
    if (pIdx < 0) throw Exception('Player not found in game');

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    final hasDrawnOrDiscarded = actionLog.any((a) =>
        a['playerId'] == myUid &&
        (a['type'] == 'DRAW_CLOSED' || a['type'] == 'DRAW_OPEN' || a['type'] == 'DISCARD'));
    final isFirstDrop = game.turnNumber == 0 || !hasDrawnOrDiscarded;
    final penalty = isFirstDrop ? game.firstDropPenalty : game.middleDropPenalty;

    final droppedPlayer = players[pIdx].copyWith(status: 'DROPPED', score: penalty);
    players[pIdx] = droppedPlayer;

    final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();
    final now = DateTime.now();

    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'DROP',
      'playerId': myUid,
      'description': '${droppedPlayer.displayName} dropped from the round ($penalty pts, ${isFirstDrop ? "First Drop" : "Middle Drop"}).',
    });

    if (remainingActive.length <= 1) {
      final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
      final finalResults = players.map((p) {
        final isWin = p.uid == winner.uid;
        return MultiplayerFinalResult(
          uid: p.uid,
          displayName: p.displayName,
          photoURL: p.photoURL,
          seatIndex: p.seatIndex,
          score: isWin ? 0 : p.score,
          isWinner: isWin,
        );
      }).toList();

      final updatedGame = game.copyWith(
        status: 'COMPLETED',
        winnerPlayerId: winner.uid,
        finalResults: finalResults,
        players: players,
        actionLog: actionLog,
        endedAt: now,
      );

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    } else {
      // Advance turn to the next active player in sequential circular seat order
      TablePlayer? nextPlayer;
      for (int i = 1; i < players.length; i++) {
        final candidate = players[(pIdx + i) % players.length];
        if (candidate.status == 'ACTIVE') {
          nextPlayer = candidate;
          break;
        }
      }
      nextPlayer ??= remainingActive.isNotEmpty ? remainingActive.first : players.first;

      final turnTimerSec = game.turnTimerSeconds;
      final nextDeadline = turnTimerSec > 0 ? now.add(Duration(seconds: turnTimerSec + 5)) : null;

      final updatedGame = game.copyWith(
        players: players,
        currentTurnPlayerId: nextPlayer.uid,
        turnNumber: game.turnNumber + 1,
        phase: 'DRAW_PHASE',
        turnDeadline: nextDeadline,
        clearCardDrawnFromOpen: true,
        actionLog: actionLog,
      );

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    }
  }

  /// Reveals the closed joker to a player who has formed Life (Pure Sequence)
  Future<void> openClosedJoker({
    required String gameId,
    required String myUid,
  }) async {
    final game = _mockGames[gameId];
    if (game == null) return;
    if (game.jokerMode != 'CLOSED') return;
    if (game.openedJokerPlayerUids.contains(myUid)) return;

    final player = game.players.firstWhere(
      (p) => p.uid == myUid,
      orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0),
    );
    final now = DateTime.now();
    final updatedOpened = [...game.openedJokerPlayerUids, myUid];
    final jokerLabel = game.openJoker?.label ?? 'Wild Joker';

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'CLOSED_JOKER_OPENED',
      'playerId': myUid,
      'description': '${player.displayName} unlocked and revealed the Closed Joker ($jokerLabel) with Life! 🃏',
    });

    final updatedGame = game.copyWith(
      openedJokerPlayerUids: updatedOpened,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('games').doc(gameId).update({
          'openedJokerPlayerUids': updatedOpened,
          'actionLog': actionLog,
        });
      } catch (e) {
        debugPrint('[MultiplayerService] openClosedJoker Firestore error: $e');
      }
    }
  }

  /// Declare Game with pure GameEngine meld verification & point calculation
  Future<Map<String, dynamic>> declareGame({
    required String gameId,
    required String myUid,
    required Card discardCard,
    required List<List<Card>> groups,
  }) async {
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');

    final hasSeenJoker = game.hasPlayerOpenedJoker(myUid);
    final effectiveJoker = hasSeenJoker ? game.openJoker! : null;
    final valRes = DeclarationValidator().validate(groups, effectiveJoker);
    final now = DateTime.now();

    if (valRes.isValid) {
      final winner = game.players.firstWhere((p) => p.uid == myUid,
          orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0));
      final winnerResult = MultiplayerFinalResult(
        uid: myUid,
        displayName: winner.displayName,
        photoURL: winner.photoURL,
        seatIndex: winner.seatIndex,
        score: 0,
        isWinner: true,
      );

      final updatedOpened = (!game.openedJokerPlayerUids.contains(myUid))
          ? [...game.openedJokerPlayerUids, myUid]
          : game.openedJokerPlayerUids;

      final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'DECLARE_VALID',
        'playerId': myUid,
        'card': discardCard.toInt(),
        'description': '${winner.displayName} declared a valid show with 0 points! 👑 Opponents have 30s to arrange their cards and submit final hand.',
      });

      // Authoritative 30s server deadline for active players to submit their hands
      final deadline = now.add(const Duration(seconds: 30));

      final initialResults = <MultiplayerFinalResult>[winnerResult];
      final initialSubmittedUids = <String>[myUid];

      // Auto-resolve any players who have already DROPPED or been ELIMINATED!
      // They do NOT get 30s to sort cards; their dropped/elimination score is fixed!
      for (final p in game.players) {
        if (p.uid == myUid) continue;
        if (p.status == 'DROPPED') {
          initialResults.add(MultiplayerFinalResult(
            uid: p.uid,
            displayName: p.displayName,
            photoURL: p.photoURL,
            seatIndex: p.seatIndex,
            score: p.score, // Keeps the exact drop penalty (e.g. 20 or 40)
            isWinner: false,
          ));
          initialSubmittedUids.add(p.uid);
        } else if (p.status == 'ELIMINATED') {
          initialResults.add(MultiplayerFinalResult(
            uid: p.uid,
            displayName: p.displayName,
            photoURL: p.photoURL,
            seatIndex: p.seatIndex,
            score: p.score > 0 ? p.score : 80,
            isWinner: false,
          ));
          initialSubmittedUids.add(p.uid);
        }
      }

      MultiplayerGameState updatedGame = game.copyWith(
        status: 'DECLARING',
        declaringPlayerId: myUid,
        declaringPlayerName: winner.displayName,
        declarationDeadline: deadline,
        submittedPlayerUids: initialSubmittedUids,
        finalResults: initialResults,
        openedJokerPlayerUids: updatedOpened,
        actionLog: actionLog,
      );

      // If all opponents were already dropped/eliminated or submitted, finalize immediately!
      if (initialSubmittedUids.length >= game.players.length) {
        updatedGame = _finalizeGameResults(updatedGame);
      }

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);

      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
          if (updatedGame.status == 'COMPLETED') {
            await _firestore!.collection('tables').doc(game.tableId).update({'status': 'FINISHED'});
          }
        } catch (e) {
          debugPrint('[MultiplayerService] declareGame Firestore update notice: $e');
        }
      }

      return {
        'isValid': true,
        'status': updatedGame.status,
        'message': 'Valid Declaration! You won the game with 0 points!',
      };
    } else {
      // Wrong show: 80 points penalty and eliminate the player from active play
      final pIdx = game.players.indexWhere((p) => p.uid == myUid);
      final declaringPlayer = pIdx >= 0
          ? game.players[pIdx]
          : TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0);

      final players = List<TablePlayer>.from(game.players);
      final elimScore = declaringPlayer.score > 0 ? declaringPlayer.score : 80;
      if (pIdx >= 0) {
        players[pIdx] = declaringPlayer.copyWith(
          status: 'ELIMINATED',
          score: elimScore,
        );
      }

      // Discard card is placed on open pile
      final openPile = List<Card>.from(game.openPile);
      openPile.add(discardCard);

      // Remove discardCard from player's hand in memory
      final mockHand = _mockPrivateHands['${gameId}_$myUid'];
      if (mockHand != null) {
        mockHand.removeWhere((c) => c.toInt() == discardCard.toInt());
      }

      final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'DECLARE_INVALID',
        'playerId': myUid,
        'card': discardCard.toInt(),
        'description': '${declaringPlayer.displayName} submitted an invalid declaration (${valRes.errorMessage}). Penalized $elimScore points and eliminated.',
      });

      final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();

      if (remainingActive.length <= 1) {
        // Lone remaining active player wins immediately!
        final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
        final finalResults = players.map((p) {
          final isWin = p.uid == winner.uid;
          return MultiplayerFinalResult(
            uid: p.uid,
            displayName: p.displayName,
            photoURL: p.photoURL,
            seatIndex: p.seatIndex,
            score: isWin ? 0 : (p.score > 0 ? p.score : 80),
            isWinner: isWin,
          );
        }).toList();

        actionLog.add({
          'seq': actionLog.length + 1,
          'timestamp': now.toIso8601String(),
          'type': 'GAME_COMPLETED',
          'playerId': winner.uid,
          'description': '${winner.displayName} wins the match as the lone remaining active player! 👑',
        });

        final updatedGame = game.copyWith(
          players: players,
          openPile: openPile,
          status: 'COMPLETED',
          winnerPlayerId: winner.uid,
          finalResults: finalResults,
          endedAt: now,
          actionLog: actionLog,
        );

        _mockGames[gameId] = updatedGame;
        _getOrCreateGameController(gameId).add(updatedGame);

        if (FirebaseConfig.isInitialized && _firestore != null) {
          try {
            await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
            await _firestore!.collection('tables').doc(game.tableId).update({'status': 'FINISHED'});
            final handRef = _firestore!.collection('games').doc(gameId).collection('privateHands').doc(myUid);
            final handSnap = await handRef.get();
            if (handSnap.exists && handSnap.data() != null) {
              final rawCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
              rawCards.removeWhere((c) => (c is int ? c : (c as Map)['intVal']) == discardCard.toInt());
              await handRef.update({'cards': rawCards});
            }
          } catch (e) {
            debugPrint('[MultiplayerService] declareGame invalid show firestore notice: $e');
          }
        }

        return {
          'isValid': false,
          'finalResults': finalResults.map((r) => r.toJson()).toList(),
          'message': 'Wrong Show! Invalid declaration: ${valRes.errorMessage}. Penalized $elimScore pts and eliminated. Game completed: ${winner.displayName} wins!',
        };
      }

      // More than 1 active player remains: advance turn to next active player in sequential circular seat order!
      TablePlayer? nextPlayer;
      for (int i = 1; i < players.length; i++) {
        final candidate = players[(pIdx + i) % players.length];
        if (candidate.status == 'ACTIVE') {
          nextPlayer = candidate;
          break;
        }
      }
      nextPlayer ??= remainingActive.first;

      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'TURN_ADVANCED',
        'playerId': nextPlayer.uid,
        'description': 'Turn passed to ${nextPlayer.displayName}.',
      });

      final turnTimerSec = game.turnTimerSeconds;
      final nextDeadline = turnTimerSec > 0 ? now.add(Duration(seconds: turnTimerSec + 5)) : null;

      final updatedGame = game.copyWith(
        players: players,
        openPile: openPile,
        currentTurnPlayerId: nextPlayer.uid,
        turnNumber: game.turnNumber + 1,
        phase: 'DRAW_PHASE',
        turnDeadline: nextDeadline,
        clearCardDrawnFromOpen: true,
        actionLog: actionLog,
      );

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);

      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('games').doc(gameId).update({
            'players': players.map((p) => p.toJson()).toList(),
            'openPile': openPile.map((c) => c.toInt()).toList(),
            'currentTurnPlayerId': nextPlayer.uid,
            'turnNumber': game.turnNumber + 1,
            'phase': 'DRAW_PHASE',
            'turnDeadline': nextDeadline?.toIso8601String(),
            'cardDrawnFromOpenThisTurn': null,
            'actionLog': actionLog,
          });
          final handRef = _firestore!.collection('games').doc(gameId).collection('privateHands').doc(myUid);
          final handSnap = await handRef.get();
          if (handSnap.exists && handSnap.data() != null) {
            final rawCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
            rawCards.removeWhere((c) => (c is int ? c : (c as Map)['intVal']) == discardCard.toInt());
            await handRef.update({'cards': rawCards});
          }
        } catch (e) {
          debugPrint('[MultiplayerService] declareGame invalid show firestore update notice: $e');
        }
      }

      return {
        'isValid': false,
        'message': 'Wrong Show! Invalid declaration: ${valRes.errorMessage}. Penalized $elimScore points and eliminated. Game continues with remaining players.',
      };
    }
  }

  /// Opponent submits final hand during DECLARING phase to reduce penalty score
  Future<Map<String, dynamic>> submitFinalHand({
    required String gameId,
    required String myUid,
    required List<List<Card>> groups,
  }) async {
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');
    if (game.status != 'DECLARING') throw Exception('Game is not in declaration phase');

    final player = game.players.firstWhere((p) => p.uid == myUid,
        orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0));

    // Dropped or eliminated players cannot submit cards; their penalties are already locked in
    if (player.status == 'DROPPED' || player.status == 'ELIMINATED') {
      throw Exception('Dropped or eliminated players do not submit cards.');
    }

    final now = DateTime.now();

    // Calculate deadwood score using GameEngine scoring rules
    final hasSeenJoker = game.hasPlayerOpenedJoker(myUid);
    final score = Scoring.calculateHandDeadwood(
      groups: groups,
      wildJoker: hasSeenJoker ? game.openJoker : null,
      maxPenalty: 80,
    );

    final playerResult = MultiplayerFinalResult(
      uid: myUid,
      displayName: player.displayName,
      photoURL: player.photoURL,
      seatIndex: player.seatIndex,
      score: score,
      isWinner: false,
    );

    final updatedSubmittedUids = List<String>.from(game.submittedPlayerUids);
    if (!updatedSubmittedUids.contains(myUid)) {
      updatedSubmittedUids.add(myUid);
    }

    final updatedResults = List<MultiplayerFinalResult>.from(game.finalResults.where((r) => r.uid != myUid));
    updatedResults.add(playerResult);

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'FINAL_HAND_SUBMITTED',
      'playerId': myUid,
      'description': '${player.displayName} submitted final hand with $score points.',
    });

    MultiplayerGameState updatedGame = game.copyWith(
      submittedPlayerUids: updatedSubmittedUids,
      finalResults: updatedResults,
      actionLog: actionLog,
    );

    // If all active players have submitted their hands, finalize game results immediately!
    final activePlayers = game.players.where((p) => p.status == 'ACTIVE').toList();
    if (activePlayers.every((p) => updatedSubmittedUids.contains(p.uid))) {
      updatedGame = _finalizeGameResults(updatedGame);
    }

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
        if (updatedGame.status == 'COMPLETED') {
          await _firestore!.collection('tables').doc(game.tableId).update({'status': 'FINISHED'});
        }
      } catch (e) {
        debugPrint('[MultiplayerService] submitFinalHand Firestore update notice: $e');
      }
    }

    return {
      'score': score,
      'isGameOver': updatedGame.status == 'COMPLETED',
    };
  }

  /// Authoritative server timeout check: if 30s declaration deadline expired, finalize game
  Future<void> checkDeclarationTimeout(String gameId) async {
    final game = _mockGames[gameId];
    if (game == null || game.status != 'DECLARING') return;
    if (game.declarationDeadline == null || DateTime.now().isBefore(game.declarationDeadline!)) return;

    final updatedGame = _finalizeGameResults(game);
    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
        await _firestore!.collection('tables').doc(game.tableId).update({'status': 'FINISHED'});
      } catch (e) {
        debugPrint('[MultiplayerService] checkDeclarationTimeout Firestore update notice: $e');
      }
    }
  }

  MultiplayerGameState _finalizeGameResults(MultiplayerGameState game) {
    final now = DateTime.now();
    final results = List<MultiplayerFinalResult>.from(game.finalResults);
    final submittedUids = results.map((r) => r.uid).toSet();

    for (final p in game.players) {
      if (!submittedUids.contains(p.uid)) {
        int score = 80;
        if (p.status == 'DROPPED') {
          score = p.score; // Preserve exact drop penalty
        } else if (p.status == 'ELIMINATED') {
          score = p.score > 0 ? p.score : 80;
        } else {
          final pHand = _mockPrivateHands['${game.gameId}_${p.uid}'] ?? [];
          if (pHand.isNotEmpty) {
            final hasSeenJoker = game.hasPlayerOpenedJoker(p.uid);
            final effectiveJoker = hasSeenJoker ? game.openJoker : null;
            score = HandPartitioner.findBestPartition(pHand, effectiveJoker).penaltyScore.clamp(0, 80);
          }
        }
        results.add(MultiplayerFinalResult(
          uid: p.uid,
          displayName: p.displayName,
          photoURL: p.photoURL,
          seatIndex: p.seatIndex,
          score: score,
          isWinner: false,
        ));
      }
    }

    final winnerId = game.declaringPlayerId;

    // Multi-round progression rules for Pool 101, Pool 201, and Best of 2 Deals
    final isPool101 = game.gameMode == 'Pool 101';
    final isPool201 = game.gameMode == 'Pool 201';
    final isPoolGame = isPool101 || isPool201;
    final isDealsGame = game.gameMode == 'Best of 2 Deals';
    final int elimLimit = isPool101 ? 101 : (isPool201 ? 201 : 9999);

    final roundScoresMap = <String, int>{};
    final cumulativeScoresMap = <String, int>{};

    for (final p in game.players) {
      int thisRoundScore = 80;
      if (p.uid == winnerId) {
        thisRoundScore = 0;
      } else {
        final existingRes = results.where((r) => r.uid == p.uid).toList();
        if (existingRes.isNotEmpty) {
          thisRoundScore = existingRes.first.score;
        } else if (p.status == 'DROPPED') {
          thisRoundScore = p.score > 0 ? p.score : 20;
        } else if (p.status == 'ELIMINATED') {
          thisRoundScore = p.score > 0 ? p.score : 80;
        }
      }
      roundScoresMap[p.uid] = thisRoundScore;

      // Cumulative score across rounds
      int prevCumulative = 0;
      if (game.roundHistory.isNotEmpty) {
        final lastRoundResults = (game.roundHistory.last['results'] as List<dynamic>?) ?? [];
        for (final lr in lastRoundResults) {
          if (lr is Map && lr['uid'] == p.uid) {
            prevCumulative = (lr['cumulativeScore'] as int?) ?? 0;
            break;
          }
        }
      }
      final newCumulative = prevCumulative + thisRoundScore;
      cumulativeScoresMap[p.uid] = newCumulative;
    }

    // Build this round's record for roundHistory
    final thisRoundSummary = {
      'round': game.currentRound,
      'winnerUid': winnerId,
      'winnerName': game.declaringPlayerName ??
          (game.players.firstWhere((p) => p.uid == winnerId, orElse: () => game.players.first).displayName),
      'results': game.players.map((p) {
        final rScore = roundScoresMap[p.uid] ?? 0;
        final cScore = cumulativeScoresMap[p.uid] ?? rScore;
        final isElim = isPoolGame && cScore >= elimLimit;
        return {
          'uid': p.uid,
          'displayName': p.displayName,
          'roundScore': rScore,
          'cumulativeScore': cScore,
          'isEliminated': isElim,
        };
      }).toList(),
    };

    final updatedRoundHistory = List<Map<String, dynamic>>.from(game.roundHistory);
    updatedRoundHistory.add(thisRoundSummary);

    // Check whether the entire tournament/match is finished
    bool isMatchComplete = false;
    String? tournamentWinnerId;

    if (!isPoolGame && !isDealsGame) {
      // Points Rummy: Single-round game completes immediately
      isMatchComplete = true;
      tournamentWinnerId = winnerId;
    } else if (isDealsGame) {
      // Deals Rummy: 2 deals total; player with lowest cumulative score wins
      if (game.currentRound >= 2) {
        isMatchComplete = true;
        TablePlayer? bestPlayer;
        int lowestScore = 999999;
        for (final p in game.players) {
          final c = cumulativeScoresMap[p.uid] ?? 999999;
          if (c < lowestScore) {
            lowestScore = c;
            bestPlayer = p;
          }
        }
        tournamentWinnerId = bestPlayer?.uid ?? winnerId;
      }
    } else if (isPoolGame) {
      // Pool Rummy: Non-eliminated players (where cumulative < elimLimit)
      final nonEliminated = game.players.where((p) => (cumulativeScoresMap[p.uid] ?? 0) < elimLimit).toList();
      if (nonEliminated.length <= 1) {
        isMatchComplete = true;
        tournamentWinnerId = nonEliminated.isNotEmpty ? nonEliminated.first.uid : winnerId;
      }
    }

    final updatedPlayers = game.players.map((p) {
      final cScore = cumulativeScoresMap[p.uid] ?? p.score;
      final isElim = isPoolGame && cScore >= elimLimit;
      return p.copyWith(
        score: isPoolGame || isDealsGame ? cScore : (roundScoresMap[p.uid] ?? p.score),
        status: isElim ? 'ELIMINATED' : 'ACTIVE',
      );
    }).toList();

    final updatedFinalResults = game.players.map((p) {
      final roundScore = roundScoresMap[p.uid] ?? 0;
      final cumScore = cumulativeScoresMap[p.uid] ?? roundScore;
      final isRoundWinner = p.uid == (isMatchComplete ? tournamentWinnerId : winnerId);
      return MultiplayerFinalResult(
        uid: p.uid,
        displayName: p.displayName,
        photoURL: p.photoURL,
        seatIndex: p.seatIndex,
        score: isPoolGame || isDealsGame ? cumScore : roundScore,
        isWinner: isRoundWinner,
      );
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);

    if (!isMatchComplete) {
      // Advance to ROUND_OVER, show deal scores, and automatically queue next round
      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'ROUND_CONCLUDED',
        'description': 'Round ${game.currentRound} finished. Cumulative scores updated. Next round dealing automatically in 6s.',
      });

      final nextRoundStart = now.add(const Duration(seconds: 6));
      final roundOverGame = game.copyWith(
        status: 'ROUND_OVER',
        players: updatedPlayers,
        finalResults: updatedFinalResults,
        roundHistory: updatedRoundHistory,
        actionLog: actionLog,
        nextRoundStartTime: nextRoundStart,
      );

      // Automatic server timer to deal the next round
      Timer(const Duration(seconds: 6), () {
        startNextRound(game.gameId);
      });

      return roundOverGame;
    }

    // Match Complete (Tournament Finished)
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'GAME_COMPLETED',
      'playerId': tournamentWinnerId,
      'description': 'Tournament completed! Overall winner: ${updatedPlayers.firstWhere((p) => p.uid == tournamentWinnerId, orElse: () => updatedPlayers.first).displayName} 👑',
    });

    // 1. Award virtual coin prize pot if coin table
    if (tournamentWinnerId != null && game.entryType == 'COIN' && game.prizePool > 0) {
      _walletService.creditCoins(
        uid: tournamentWinnerId,
        amount: game.prizePool,
        type: 'GAME_WIN_PRIZE',
        reason: 'Victory Pot: Won Match #${game.roomCode} (${game.prizePool} coins)',
        referenceId: game.gameId,
      ).catchError((e) {
        debugPrint('[MultiplayerService] Error crediting winner pot: $e');
        return 0;
      });
    }

    // 2. Authoritatively record match statistics and progression for all players
    final durationSeconds = (now.difference(game.startedAt ?? now)).inSeconds;
    for (final r in updatedFinalResults) {
      _progressionService.recordCompletedMatch(
        uid: r.uid,
        won: r.uid == tournamentWinnerId,
        score: r.score,
        madeDeclaration: r.uid == game.declaringPlayerId,
        matchDurationSeconds: durationSeconds,
        playerCount: game.playerCount,
      ).catchError((e) {
        debugPrint('[MultiplayerService] Error recording progression: $e');
      });
    }

    return game.copyWith(
      status: 'COMPLETED',
      winnerPlayerId: tournamentWinnerId,
      players: updatedPlayers,
      finalResults: updatedFinalResults,
      roundHistory: updatedRoundHistory,
      actionLog: actionLog,
      endedAt: now,
    );
  }

  /// Deals the next round in a multi-round game (Pool 101, Pool 201, Best of 2 Deals)
  Future<void> startNextRound(String gameId) async {
    final game = _mockGames[gameId];
    if (game == null || game.status != 'ROUND_OVER') return;

    final now = DateTime.now();

    // Determine surviving non-eliminated players
    final survivingPlayers = game.players.where((p) => p.status != 'ELIMINATED').toList();
    if (survivingPlayers.length <= 1) {
      final updatedGame = game.copyWith(
        status: 'COMPLETED',
        winnerPlayerId: survivingPlayers.isNotEmpty ? survivingPlayers.first.uid : game.winnerPlayerId,
        endedAt: now,
      );
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
          await _firestore!.collection('tables').doc(game.tableId).update({'status': 'FINISHED'});
        } catch (_) {}
      }
      return;
    }

    // Rotate dealer among surviving players
    final currentDealerIdx = game.players.indexWhere((p) => p.uid == game.dealerPlayerId);
    int nextDealerIdx = (currentDealerIdx >= 0 ? currentDealerIdx + 1 : 0) % game.players.length;
    while (game.players[nextDealerIdx].status == 'ELIMINATED') {
      nextDealerIdx = (nextDealerIdx + 1) % game.players.length;
    }
    final nextDealer = game.players[nextDealerIdx];

    // First turn goes to player immediately after dealer
    int firstTurnIdx = (nextDealerIdx + 1) % game.players.length;
    while (game.players[firstTurnIdx].status == 'ELIMINATED') {
      firstTurnIdx = (firstTurnIdx + 1) % game.players.length;
    }
    final firstTurnPlayer = game.players[firstTurnIdx];

    // Deal cards: 2 players = 1 deck (54 cards), 3+ players = 2 decks (108 cards)
    final numDecks = game.players.length <= 2 ? 1 : 2;
    final deck = Deck.initialize(numDecks);
    final allCards = List<Card>.from(deck.cards);

    final openJoker = allCards.removeLast();
    final effectiveWildRank = JokerUtils.getEffectiveWildRank(openJoker)?.name ?? 'ace';

    final playerHands = <String, List<Card>>{};
    for (final p in game.players) {
      if (p.status != 'ELIMINATED') {
        final hand = <Card>[];
        for (int i = 0; i < 13; i++) {
          hand.add(allCards.removeLast());
        }
        playerHands[p.uid] = hand;
        _mockPrivateHands['${gameId}_${p.uid}'] = hand;
      } else {
        _mockPrivateHands['${gameId}_${p.uid}'] = [];
      }
    }

    final firstOpenCard = allCards.removeLast();
    final closedDeckInts = allCards.map((c) => c.toInt()).toList();

    // Restore dropped players back to ACTIVE for the new round
    final updatedPlayers = game.players.map((p) {
      if (p.status == 'ELIMINATED') {
        return p.copyWith(cardCount: 0);
      }
      return p.copyWith(
        status: 'ACTIVE',
        cardCount: 13,
      );
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    final nextRoundNum = game.currentRound + 1;
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'ROUND_STARTED',
      'playerId': nextDealer.uid,
      'description': 'Round $nextRoundNum started. Dealer: ${nextDealer.displayName}. First turn: ${firstTurnPlayer.displayName}.',
    });

    final updatedGame = game.copyWith(
      status: 'IN_PROGRESS',
      phase: 'DRAW_PHASE',
      currentRound: nextRoundNum,
      currentTurnPlayerId: firstTurnPlayer.uid,
      turnNumber: 0,
      turnDeadline: game.turnTimerSeconds > 0 ? now.add(Duration(seconds: game.turnTimerSeconds + 5)) : null,
      dealerPlayerId: nextDealer.uid,
      openJoker: openJoker,
      effectiveWildRank: effectiveWildRank,
      openPile: [firstOpenCard],
      closedDeck: closedDeckInts,
      closedDeckRemaining: closedDeckInts.length,
      clearCardDrawnFromOpen: true,
      openedJokerPlayerUids: [],
      clearDeclarer: true,
      declarationDeadline: null,
      submittedPlayerUids: [],
      finalResults: [],
      clearWinner: true,
      clearNextRoundStartTime: true,
      players: updatedPlayers,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
        for (final entry in playerHands.entries) {
          await _firestore!
              .collection('games')
              .doc(gameId)
              .collection('privateHands')
              .doc(entry.key)
              .set({
            'cards': entry.value.map((c) => c.toInt()).toList(),
            'updatedAt': now.toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('[MultiplayerService] startNextRound Firestore update notice: $e');
      }
    }
  }

  // --------------- Connection & Turn Timeout Management ---------------

  /// Updates player heartbeat timestamp and marks them connected
  Future<void> recordPlayerHeartbeat({required String gameId, required String uid}) async {
    final now = DateTime.now();
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        final snap = await gameRef.get();
        if (snap.exists && snap.data() != null) {
          final rawPlayers = (snap.data()!['players'] as List<dynamic>?) ?? [];
          bool needsUpdate = false;
          final updated = rawPlayers.map((pMap) {
            final p = Map<String, dynamic>.from(pMap as Map);
            if (p['uid'] == uid) {
              if (p['connected'] != true || p['disconnectedAt'] != null) {
                p['connected'] = true;
                p['disconnectedAt'] = null;
                needsUpdate = true;
              }
              p['lastHeartbeat'] = now.toIso8601String();
            }
            return p;
          }).toList();
          if (needsUpdate) {
            await gameRef.update({'players': updated});
          }
        }
      } catch (e) {
        debugPrint('[MultiplayerService] recordPlayerHeartbeat Firestore notice: $e');
      }
    }

    final mock = _mockGames[gameId];
    if (mock != null) {
      final updated = mock.players.map((p) {
        if (p.uid == uid) {
          return p.copyWith(connected: true, clearDisconnectedAt: true, lastHeartbeat: now);
        }
        return p;
      }).toList();
      final updatedGame = mock.copyWith(players: updated);
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    }
  }

  /// Explicitly marks a player as disconnected and sets their disconnectedAt timer
  Future<void> markPlayerDisconnected({required String gameId, required String uid}) async {
    final now = DateTime.now();
    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        final snap = await gameRef.get();
        if (snap.exists && snap.data() != null) {
          final rawPlayers = (snap.data()!['players'] as List<dynamic>?) ?? [];
          final updated = rawPlayers.map((pMap) {
            final p = Map<String, dynamic>.from(pMap as Map);
            if (p['uid'] == uid) {
              p['connected'] = false;
              p['disconnectedAt'] = p['disconnectedAt'] ?? now.toIso8601String();
            }
            return p;
          }).toList();
          await gameRef.update({'players': updated});
        }
      } catch (e) {
        debugPrint('[MultiplayerService] markPlayerDisconnected Firestore notice: $e');
      }
    }

    final mock = _mockGames[gameId];
    if (mock != null) {
      final updated = mock.players.map((p) {
        if (p.uid == uid) {
          return p.copyWith(connected: false, disconnectedAt: p.disconnectedAt ?? now);
        }
        return p;
      }).toList();
      final updatedGame = mock.copyWith(players: updated);
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    }
  }

  /// Checks for any player disconnected >= 180 seconds (3 minutes) and eliminates them
  Future<void> checkDisconnections(String gameId) async {
    final now = DateTime.now();

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        await _firestore!.runTransaction((tx) async {
          final snap = await tx.get(gameRef);
          if (!snap.exists || snap.data() == null) return;
          final gameData = snap.data()!;
          if (gameData['status'] == 'COMPLETED') return;

          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => TablePlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList();
          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();

          bool changed = false;
          String currentTurnUid = gameData['currentTurnPlayerId'] as String? ?? '';
          bool advanceTurn = false;

          for (int i = 0; i < players.length; i++) {
            final p = players[i];
            if (p.status == 'ACTIVE') {
              if (!p.connected && p.disconnectedAt != null) {
                final diff = now.difference(p.disconnectedAt!).inSeconds;
                if (diff >= 180) { // 3 minutes timeout
                  players[i] = p.copyWith(status: 'ELIMINATED', score: 80);
                  changed = true;
                  actionLog.add({
                    'seq': actionLog.length + 1,
                    'timestamp': now.toIso8601String(),
                    'type': 'PLAYER_ELIMINATED',
                    'playerId': p.uid,
                    'description': '${p.displayName} eliminated (disconnected > 3 mins). Score: 80.',
                  });

                  if (currentTurnUid == p.uid) {
                    advanceTurn = true;
                  }
                }
              }
            }
          }

          if (!changed) return;

          final activePlayers = players.where((p) => p.status == 'ACTIVE' || p.status == 'DECLARED').toList();

          // If only 1 player remains, conclude game immediately
          if (activePlayers.length == 1) {
            final winner = activePlayers.first;
            final finalResults = players.map((p) {
              final isWin = p.uid == winner.uid;
              return MultiplayerFinalResult(
                uid: p.uid,
                displayName: p.displayName,
                photoURL: p.photoURL,
                seatIndex: p.seatIndex,
                score: isWin ? 0 : 80,
                isWinner: isWin,
              );
            }).toList();

            actionLog.add({
              'seq': actionLog.length + 1,
              'timestamp': now.toIso8601String(),
              'type': 'ROUND_CONCLUDED',
              'description': '${winner.displayName} wins by default as all opponents were eliminated.',
            });

            tx.update(gameRef, {
              'status': 'COMPLETED',
              'winnerPlayerId': winner.uid,
              'players': players.map((p) => p.toJson()).toList(),
              'finalResults': finalResults.map((r) => r.toJson()).toList(),
              'actionLog': actionLog,
              'endedAt': now.toIso8601String(),
            });
            return;
          }

          final updates = <String, dynamic>{
            'players': players.map((p) => p.toJson()).toList(),
            'actionLog': actionLog,
          };

          if (advanceTurn && activePlayers.isNotEmpty) {
            final nextPlayer = activePlayers.first;
            updates['currentTurnPlayerId'] = nextPlayer.uid;
            updates['turnNumber'] = (gameData['turnNumber'] as int? ?? 0) + 1;
            updates['phase'] = 'DRAW_PHASE';
            updates['turnDeadline'] = now.add(const Duration(seconds: 35)).toIso8601String();
            updates['cardDrawnFromOpenThisTurn'] = null;
          }

          tx.update(gameRef, updates);
        });
      } catch (e) {
        debugPrint('[MultiplayerService] checkDisconnections Firestore notice: $e');
      }
      return;
    }

    // Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null || game.isCompleted) return;

    bool changed = false;
    final players = List<TablePlayer>.from(game.players);
    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    bool advanceTurn = false;

    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (p.status == 'ACTIVE') {
        if (!p.connected && p.disconnectedAt != null) {
          final diff = now.difference(p.disconnectedAt!).inSeconds;
          if (diff >= 180) {
            players[i] = p.copyWith(status: 'ELIMINATED', score: 80);
            changed = true;
            actionLog.add({
              'seq': actionLog.length + 1,
              'timestamp': now.toIso8601String(),
              'type': 'PLAYER_ELIMINATED',
              'playerId': p.uid,
              'description': '${p.displayName} eliminated (disconnected > 3 mins). Score: 80.',
            });

            if (game.currentTurnPlayerId == p.uid) {
              advanceTurn = true;
            }
          }
        }
      }
    }

    if (!changed) return;

    final activePlayers = players.where((p) => p.status == 'ACTIVE' || p.status == 'DECLARED').toList();
    if (activePlayers.length == 1) {
      final winner = activePlayers.first;
      final finalResults = players.map((p) {
        final isWin = p.uid == winner.uid;
        return MultiplayerFinalResult(
          uid: p.uid,
          displayName: p.displayName,
          photoURL: p.photoURL,
          seatIndex: p.seatIndex,
          score: isWin ? 0 : 80,
          isWinner: isWin,
        );
      }).toList();

      final updatedGame = game.copyWith(
        status: 'COMPLETED',
        winnerPlayerId: winner.uid,
        players: players,
        finalResults: finalResults,
        actionLog: actionLog,
        endedAt: now,
      );
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
      return;
    }

    String nextPlayerId = game.currentTurnPlayerId;
    int nextTurnNumber = game.turnNumber;
    DateTime? nextDeadline = game.turnDeadline;

    if (advanceTurn && activePlayers.isNotEmpty) {
      nextPlayerId = activePlayers.first.uid;
      nextTurnNumber = game.turnNumber + 1;
      nextDeadline = now.add(const Duration(seconds: 35));
    }

    final updatedGame = game.copyWith(
      players: players,
      actionLog: actionLog,
      currentTurnPlayerId: nextPlayerId,
      turnNumber: nextTurnNumber,
      phase: advanceTurn ? 'DRAW_PHASE' : game.phase,
      turnDeadline: nextDeadline,
      clearCardDrawnFromOpen: advanceTurn,
    );
    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);
  }

  /// Forces turn advancement when a player exceeds their turn deadline.
  /// After 1 miss (timeout), the player is eliminated with their current score.
  /// A card is picked from the closed deck and dropped into the open pile (or the drawn card is discarded).
  Future<void> forceAdvanceTurnOnTimeout(String gameId) async {
    final now = DateTime.now();

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        await _firestore!.runTransaction((tx) async {
          final snap = await tx.get(gameRef);
          if (!snap.exists || snap.data() == null) return;
          final gameData = snap.data()!;
          if (gameData['status'] != 'IN_PROGRESS') return;

          DateTime? parseDate(dynamic d) {
            if (d == null) return null;
            if (d is DateTime) return d;
            try {
              if ((d as dynamic).toDate != null) return (d as dynamic).toDate() as DateTime;
            } catch (_) {}
            if (d is String) return DateTime.tryParse(d);
            return null;
          }

          final deadline = parseDate(gameData['turnDeadline']);
          if (deadline == null || now.isBefore(deadline.add(const Duration(seconds: 1)))) {
            return; // Not timed out yet
          }

          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => TablePlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList();
          final currentTurnUid = gameData['currentTurnPlayerId'] as String? ?? '';
          final pIdx = players.indexWhere((p) => p.uid == currentTurnUid);
          if (pIdx < 0) return;

          final rawClosedDeck = (gameData['closedDeck'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          final rawOpenPile = (gameData['openPile'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
          List<int> closedDeck = List<int>.from(rawClosedDeck);
          List<int> openPile = List<int>.from(rawOpenPile);

          final phase = gameData['phase'] as String? ?? 'DRAW_PHASE';

          final authUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwnerOfHand = authUid != null && authUid == currentTurnUid;

          // If in DRAW_PHASE: Pick 1 card from closed deck and drop to open pile
          if (phase == 'DRAW_PHASE' && closedDeck.isNotEmpty) {
            final cardInt = closedDeck.removeLast();
            openPile.add(cardInt);
          } else if (phase == 'DISCARD_PHASE' && isOwnerOfHand) {
            // Player already drew a card into private hand; drop the extra card to open pile (only if owner)
            try {
              final handRef = gameRef.collection('privateHands').doc(currentTurnUid);
              final handSnap = await tx.get(handRef);
              if (handSnap.exists && handSnap.data() != null) {
                final existingCards = List<dynamic>.from(handSnap.data()!['cards'] ?? []);
                if (existingCards.length > 13) {
                  final droppedCardInt = existingCards.removeLast();
                  if (droppedCardInt is int) {
                    openPile.add(droppedCardInt);
                  } else if (droppedCardInt is Map) {
                    openPile.add((droppedCardInt['val'] ?? droppedCardInt['intVal'] ?? 0) as int);
                  }
                  tx.update(handRef, {'cards': existingCards});
                }
              }
            } catch (e) {
              debugPrint('[MultiplayerService] privateHand discard update note: $e');
            }
          }

          final timedOutPlayer = players[pIdx];
          final currentMisses = timedOutPlayer.misses;
          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();

          if (currentMisses < 2) {
            // Player used 1 of their 3 chances: auto-discard and pass turn
            final newMisses = currentMisses + 1;
            players[pIdx] = timedOutPlayer.copyWith(misses: newMisses);

            // Advance to next active player in sequential circular seat order
            TablePlayer? nextPlayer;
            for (int i = 1; i < players.length; i++) {
              final candidate = players[(pIdx + i) % players.length];
              if (candidate.status == 'ACTIVE') {
                nextPlayer = candidate;
                break;
              }
            }
            final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();
            nextPlayer ??= remainingActive.first;

            actionLog.add({
              'seq': actionLog.length + 1,
              'timestamp': now.toIso8601String(),
              'type': 'TURN_TIMEOUT',
              'playerId': currentTurnUid,
              'description': '${timedOutPlayer.displayName} missed turn ($newMisses/3 chances used). Card auto-discarded. Turn passed to ${nextPlayer.displayName}.',
            });

            final turnTimerSec = (gameData['turnTimerSeconds'] as int?) ?? 30;
            final nextDeadline = turnTimerSec > 0
                ? now.add(Duration(seconds: turnTimerSec + 5)).toIso8601String()
                : null;

            tx.update(gameRef, {
              'players': players.map((p) => p.toJson()).toList(),
              'closedDeck': closedDeck,
              'closedDeckRemaining': closedDeck.length,
              'openPile': openPile,
              'currentTurnPlayerId': nextPlayer.uid,
              'turnNumber': (gameData['turnNumber'] as int? ?? 0) + 1,
              'phase': 'DRAW_PHASE',
              'turnDeadline': nextDeadline,
              'cardDrawnFromOpenThisTurn': null,
              'actionLog': actionLog,
            });
            return;
          }

          // Player reached 3/3 missed chances: this 3rd timeout eliminates them immediately!
          final elimScore = timedOutPlayer.score > 0 ? timedOutPlayer.score : 80;
          players[pIdx] = timedOutPlayer.copyWith(
            status: 'ELIMINATED',
            score: elimScore,
            misses: currentMisses + 1,
          );

          final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();

          if (remainingActive.length <= 1) {
            // Only 1 player left: conclude game immediately, remaining player wins!
            final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
            final finalResults = players.map((p) {
              final isWin = p.uid == winner.uid;
              return MultiplayerFinalResult(
                uid: p.uid,
                displayName: p.displayName,
                photoURL: p.photoURL,
                seatIndex: p.seatIndex,
                score: isWin ? 0 : (p.score > 0 ? p.score : 80),
                isWinner: isWin,
              );
            }).toList();

            actionLog.add({
              'seq': actionLog.length + 1,
              'timestamp': now.toIso8601String(),
              'type': 'PLAYER_ELIMINATED',
              'playerId': currentTurnUid,
              'description': '${timedOutPlayer.displayName} missed turn (exceeded 3 chances) and was eliminated. Score: $elimScore.',
            });

            actionLog.add({
              'seq': actionLog.length + 2,
              'timestamp': now.toIso8601String(),
              'type': 'GAME_COMPLETED',
              'description': '${winner.displayName} won the game as the last active player!',
            });

            tx.update(gameRef, {
              'players': players.map((p) => p.toJson()).toList(),
              'closedDeck': closedDeck,
              'closedDeckRemaining': closedDeck.length,
              'openPile': openPile,
              'status': 'COMPLETED',
              'winnerPlayerId': winner.uid,
              'finalResults': finalResults.map((r) => r.toJson()).toList(),
              'endedAt': now.toIso8601String(),
              'actionLog': actionLog,
            });

            final tableId = gameData['tableId'] as String? ?? '';
            if (tableId.isNotEmpty) {
              tx.update(_firestore!.collection('tables').doc(tableId), {
                'status': 'WAITING',
                'activeGameId': null,
              });
            }
            return;
          }

          // Advance to next active player in sequential circular seat order
          TablePlayer? nextPlayer;
          for (int i = 1; i < players.length; i++) {
            final candidate = players[(pIdx + i) % players.length];
            if (candidate.status == 'ACTIVE') {
              nextPlayer = candidate;
              break;
            }
          }
          nextPlayer ??= remainingActive.first;

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'PLAYER_ELIMINATED',
            'playerId': currentTurnUid,
            'description': '${timedOutPlayer.displayName} missed turn (exceeded 3 chances) and was eliminated. Turn advanced to ${nextPlayer.displayName}.',
          });

          final turnTimerSec = (gameData['turnTimerSeconds'] as int?) ?? 30;
          final nextDeadline = turnTimerSec > 0
              ? now.add(Duration(seconds: turnTimerSec + 5)).toIso8601String()
              : null;

          tx.update(gameRef, {
            'players': players.map((p) => p.toJson()).toList(),
            'closedDeck': closedDeck,
            'closedDeckRemaining': closedDeck.length,
            'openPile': openPile,
            'currentTurnPlayerId': nextPlayer.uid,
            'turnNumber': (gameData['turnNumber'] as int? ?? 0) + 1,
            'phase': 'DRAW_PHASE',
            'turnDeadline': nextDeadline,
            'cardDrawnFromOpenThisTurn': null,
            'actionLog': actionLog,
          });
        });
      } catch (e) {
        debugPrint('[MultiplayerService] forceAdvanceTurnOnTimeout Firestore notice: $e');
      }
      return;
    }

    // Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null || game.status != 'IN_PROGRESS') return;
    if (game.turnDeadline == null || now.isBefore(game.turnDeadline!.add(const Duration(seconds: 1)))) {
      return;
    }

    final players = List<TablePlayer>.from(game.players);
    final pIdx = players.indexWhere((p) => p.uid == game.currentTurnPlayerId);
    if (pIdx < 0) return;

    List<int> closedDeck = List<int>.from(game.closedDeck);
    List<Card> openPile = List<Card>.from(game.openPile);

    if (game.phase == 'DRAW_PHASE' && closedDeck.isNotEmpty) {
      final cardInt = closedDeck.removeLast();
      openPile.add(Card.fromInt(cardInt));
    } else if (game.phase == 'DISCARD_PHASE') {
      final hand = _mockPrivateHands['${gameId}_${game.currentTurnPlayerId}'] ?? [];
      if (hand.length > 13) {
        final dropped = hand.removeLast();
        openPile.add(dropped);
      }
    }

    final timedOutPlayer = players[pIdx];
    final currentMisses = timedOutPlayer.misses;
    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);

    if (currentMisses < 2) {
      final newMisses = currentMisses + 1;
      players[pIdx] = timedOutPlayer.copyWith(misses: newMisses);

      TablePlayer? nextPlayer;
      for (int i = 1; i < players.length; i++) {
        final candidate = players[(pIdx + i) % players.length];
        if (candidate.status == 'ACTIVE') {
          nextPlayer = candidate;
          break;
        }
      }
      final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();
      nextPlayer ??= remainingActive.first;

      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'TURN_TIMEOUT',
        'playerId': game.currentTurnPlayerId,
        'description': '${timedOutPlayer.displayName} missed turn ($newMisses/3 chances used). Card auto-discarded. Turn passed to ${nextPlayer.displayName}.',
      });

      final turnTimerSec = game.turnTimerSeconds;
      final nextDeadline = turnTimerSec > 0 ? now.add(Duration(seconds: turnTimerSec + 5)) : null;

      final updatedGame = game.copyWith(
        players: players,
        closedDeck: closedDeck,
        openPile: openPile,
        currentTurnPlayerId: nextPlayer.uid,
        turnNumber: game.turnNumber + 1,
        phase: 'DRAW_PHASE',
        turnDeadline: nextDeadline,
        clearCardDrawnFromOpen: true,
        actionLog: actionLog,
      );

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
      return;
    }

    final elimScore = timedOutPlayer.score > 0 ? timedOutPlayer.score : 80;
    players[pIdx] = timedOutPlayer.copyWith(status: 'ELIMINATED', score: elimScore, misses: currentMisses + 1);
    final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();

    if (remainingActive.length <= 1) {
      final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
      final finalResults = players.map((p) {
        final isWin = p.uid == winner.uid;
        return MultiplayerFinalResult(
          uid: p.uid,
          displayName: p.displayName,
          photoURL: p.photoURL,
          seatIndex: p.seatIndex,
          score: isWin ? 0 : (p.score > 0 ? p.score : 80),
          isWinner: isWin,
        );
      }).toList();

      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'PLAYER_ELIMINATED',
        'playerId': game.currentTurnPlayerId,
        'description': '${timedOutPlayer.displayName} missed turn (exceeded 3 chances) and was eliminated. Score: $elimScore.',
      });

      actionLog.add({
        'seq': actionLog.length + 2,
        'timestamp': now.toIso8601String(),
        'type': 'GAME_COMPLETED',
        'description': '${winner.displayName} won the game as the last active player!',
      });

      final updatedGame = game.copyWith(
        players: players,
        closedDeck: closedDeck,
        openPile: openPile,
        status: 'COMPLETED',
        winnerPlayerId: winner.uid,
        finalResults: finalResults,
        endedAt: now,
        actionLog: actionLog,
      );
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
      return;
    }

    TablePlayer? nextPlayer;
    for (int i = 1; i < players.length; i++) {
      final candidate = players[(pIdx + i) % players.length];
      if (candidate.status == 'ACTIVE') {
        nextPlayer = candidate;
        break;
      }
    }
    nextPlayer ??= remainingActive.first;

    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'PLAYER_ELIMINATED',
      'playerId': game.currentTurnPlayerId,
      'description': '${timedOutPlayer.displayName} missed turn (exceeded 3 chances) and was eliminated. Turn advanced to ${nextPlayer.displayName}.',
    });

    final updatedGame = game.copyWith(
      players: players,
      closedDeck: closedDeck,
      closedDeckRemaining: closedDeck.length,
      openPile: openPile,
      currentTurnPlayerId: nextPlayer.uid,
      turnNumber: game.turnNumber + 1,
      phase: 'DRAW_PHASE',
      turnDeadline: game.turnTimerSeconds > 0 ? now.add(Duration(seconds: game.turnTimerSeconds + 5)) : null,
      clearCardDrawnFromOpen: true,
      actionLog: actionLog,
    );
    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);
  }

  /// Allows the table owner/host to conclude the game/tournament at any moment
  Future<void> endGameByHost({required String gameId, required String myUid}) async {
    final now = DateTime.now();

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        await _firestore!.runTransaction((tx) async {
          final snap = await tx.get(gameRef);
          if (!snap.exists || snap.data() == null) return;
          final gameData = snap.data()!;
          if (gameData['status'] == 'COMPLETED') return;

          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => TablePlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList();

          final isHost = players.any((p) => p.uid == myUid && p.isHost);
          if (!isHost) throw Exception('Only the table host can end the game.');

          // Host ended game before completion: reset all players' scores to 0 and declare no winner
          final updatedPlayers = players.map((p) => p.copyWith(score: 0)).toList();
          final finalResults = players.map((p) {
            return MultiplayerFinalResult(
              uid: p.uid,
              displayName: p.displayName,
              photoURL: p.photoURL,
              seatIndex: p.seatIndex,
              score: 0,
              isWinner: false,
            );
          }).toList();

          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'HOST_ENDED_GAME',
            'playerId': myUid,
            'description': 'The table owner ended the game before completion. Match cancelled with 0 points for everyone.',
          });

          tx.update(gameRef, {
            'status': 'COMPLETED',
            'winnerPlayerId': null,
            'declaringPlayerId': null,
            'declaringPlayerName': null,
            'players': updatedPlayers.map((p) => p.toJson()).toList(),
            'finalResults': finalResults.map((r) => r.toJson()).toList(),
            'endedAt': now.toIso8601String(),
            'actionLog': actionLog,
          });

          // Also update table status
          final tableId = gameData['tableId'] as String?;
          if (tableId != null) {
            final tableRef = _firestore!.collection('tables').doc(tableId);
            tx.update(tableRef, {'status': 'WAITING', 'activeGameId': null});
          }
        });
      } catch (e) {
        debugPrint('[MultiplayerService] endGameByHost error: $e');
        rethrow;
      }
      return;
    }

    // Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null || game.status == 'COMPLETED') return;

    final isHost = game.players.any((p) => p.uid == myUid && p.isHost);
    if (!isHost) throw Exception('Only the table host can end the game.');

    final updatedPlayers = game.players.map((p) => p.copyWith(score: 0)).toList();
    final finalResults = game.players.map((p) {
      return MultiplayerFinalResult(
        uid: p.uid,
        displayName: p.displayName,
        photoURL: p.photoURL,
        seatIndex: p.seatIndex,
        score: 0,
        isWinner: false,
      );
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'HOST_ENDED_GAME',
      'playerId': myUid,
      'description': 'The table owner ended the game before completion. Match cancelled with 0 points for everyone.',
    });

    final updatedGame = game.copyWith(
      status: 'COMPLETED',
      clearWinner: true,
      clearDeclarer: true,
      players: updatedPlayers,
      finalResults: finalResults,
      endedAt: now,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);
  }

  /// Host Remove / Kick Player from In-Progress Game
  Future<void> removePlayerByHost({
    required String gameId,
    required String hostUid,
    required String targetUid,
  }) async {
    final now = DateTime.now();

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final gameRef = _firestore!.collection('games').doc(gameId);
        await _firestore!.runTransaction((tx) async {
          final snap = await tx.get(gameRef);
          if (!snap.exists || snap.data() == null) return;
          final gameData = snap.data()!;
          if (gameData['status'] == 'COMPLETED') return;

          final rawPlayers = (gameData['players'] as List<dynamic>?) ?? [];
          final players = rawPlayers.map((p) => TablePlayer.fromJson(Map<String, dynamic>.from(p as Map))).toList();

          final isHost = players.any((p) => p.uid == hostUid && p.isHost);
          if (!isHost) throw Exception('Only the table host can remove players.');

          final targetIdx = players.indexWhere((p) => p.uid == targetUid);
          if (targetIdx < 0) throw Exception('Player not found in game.');
          final targetPlayer = players[targetIdx];
          if (targetPlayer.status == 'ELIMINATED' || targetPlayer.status == 'DROPPED') {
            throw Exception('Player is already not active.');
          }

          // Mark player eliminated with 80 penalty points
          players[targetIdx] = targetPlayer.copyWith(status: 'ELIMINATED', score: 80);
          final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();

          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'HOST_REMOVED_PLAYER',
            'playerId': hostUid,
            'description': 'The table host removed ${targetPlayer.displayName} from the game (80 pts penalty).',
          });

          if (remainingActive.length <= 1) {
            final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
            final finalResults = players.map((p) {
              final isWin = p.uid == winner.uid;
              return MultiplayerFinalResult(
                uid: p.uid,
                displayName: p.displayName,
                photoURL: p.photoURL,
                seatIndex: p.seatIndex,
                score: isWin ? 0 : p.score,
                isWinner: isWin,
              );
            }).toList();

            tx.update(gameRef, {
              'status': 'COMPLETED',
              'winnerPlayerId': winner.uid,
              'finalResults': finalResults.map((r) => r.toJson()).toList(),
              'players': players.map((p) => p.toJson()).toList(),
              'actionLog': actionLog,
              'endedAt': now.toIso8601String(),
            });

            final tableId = gameData['tableId'] as String?;
            if (tableId != null) {
              tx.update(_firestore!.collection('tables').doc(tableId), {
                'status': 'WAITING',
                'activeGameId': null,
              });
            }
          } else {
            final currentTurnUid = gameData['currentTurnPlayerId'] as String?;
            final wasTurn = currentTurnUid == targetUid;

            final updates = <String, dynamic>{
              'players': players.map((p) => p.toJson()).toList(),
              'actionLog': actionLog,
            };

            if (wasTurn) {
              TablePlayer? nextPlayer;
              for (int i = 1; i < players.length; i++) {
                final candidate = players[(targetIdx + i) % players.length];
                if (candidate.status == 'ACTIVE') {
                  nextPlayer = candidate;
                  break;
                }
              }
              nextPlayer ??= remainingActive.first;

              final turnNum = (gameData['turnNumber'] as int?) ?? 0;
              final turnTimerSec = (gameData['turnTimerSeconds'] as int?) ?? 30;
              final nextDeadline = turnTimerSec > 0
                  ? now.add(Duration(seconds: turnTimerSec + 5)).toIso8601String()
                  : null;

              updates['currentTurnPlayerId'] = nextPlayer.uid;
              updates['turnNumber'] = turnNum + 1;
              updates['phase'] = 'DRAW_PHASE';
              updates['turnDeadline'] = nextDeadline;
              updates['cardDrawnFromOpenThisTurn'] = null;
            }

            tx.update(gameRef, updates);
          }
        });
      } catch (e) {
        debugPrint('[MultiplayerService] removePlayerByHost error: $e');
        rethrow;
      }
      return;
    }

    // Local / Offline Simulation
    final game = _mockGames[gameId];
    if (game == null || game.status == 'COMPLETED') return;

    final isHost = game.players.any((p) => p.uid == hostUid && p.isHost);
    if (!isHost) throw Exception('Only the table host can remove players.');

    final targetIdx = game.players.indexWhere((p) => p.uid == targetUid);
    if (targetIdx < 0) return;
    final players = List<TablePlayer>.from(game.players);
    players[targetIdx] = players[targetIdx].copyWith(status: 'ELIMINATED', score: 80);
    final remainingActive = players.where((p) => p.status == 'ACTIVE').toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'HOST_REMOVED_PLAYER',
      'playerId': hostUid,
      'description': 'The table host removed ${players[targetIdx].displayName} from the game (80 pts penalty).',
    });

    if (remainingActive.length <= 1) {
      final winner = remainingActive.isNotEmpty ? remainingActive.first : players.first;
      final finalResults = players.map((p) {
        final isWin = p.uid == winner.uid;
        return MultiplayerFinalResult(
          uid: p.uid,
          displayName: p.displayName,
          photoURL: p.photoURL,
          seatIndex: p.seatIndex,
          score: isWin ? 0 : p.score,
          isWinner: isWin,
        );
      }).toList();

      final updatedGame = game.copyWith(
        status: 'COMPLETED',
        winnerPlayerId: winner.uid,
        finalResults: finalResults,
        players: players,
        endedAt: now,
        actionLog: actionLog,
      );
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    } else {
      final wasTurn = game.currentTurnPlayerId == targetUid;
      TablePlayer? nextPlayer;
      if (wasTurn) {
        for (int i = 1; i < players.length; i++) {
          final candidate = players[(targetIdx + i) % players.length];
          if (candidate.status == 'ACTIVE') {
            nextPlayer = candidate;
            break;
          }
        }
        nextPlayer ??= remainingActive.first;
      }

      final turnTimerSec = game.turnTimerSeconds;
      final nextDeadline = turnTimerSec > 0 ? now.add(Duration(seconds: turnTimerSec + 5)) : null;

      final updatedGame = game.copyWith(
        players: players,
        currentTurnPlayerId: wasTurn ? nextPlayer!.uid : game.currentTurnPlayerId,
        turnNumber: wasTurn ? game.turnNumber + 1 : game.turnNumber,
        phase: wasTurn ? 'DRAW_PHASE' : game.phase,
        turnDeadline: wasTurn ? nextDeadline : game.turnDeadline,
        clearCardDrawnFromOpen: wasTurn ? true : false,
        actionLog: actionLog,
      );
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);
    }
  }

  // --------------- Real-time Streams ---------------

  Stream<TableLobby> watchTable(String tableId) {
    if (FirebaseConfig.isInitialized && _firestore != null) {
      return _firestore!.collection('tables').doc(tableId).snapshots().map((snap) {
        if (snap.exists && snap.data() != null) {
          final lobby = TableLobby.fromJson(snap.data()!);
          _mockTables[tableId] = lobby;
          return lobby;
        }
        final mock = _mockTables[tableId];
        if (mock != null) return mock;
        throw Exception('Table no longer exists');
      });
    }
    return _getOrCreateTableController(tableId).stream;
  }

  Stream<MultiplayerGameState> watchGame(String gameId, String myUid) {
    if (FirebaseConfig.isInitialized && _firestore != null) {
      final gameRef = _firestore!.collection('games').doc(gameId);
      final privateHandRef = gameRef.collection('privateHands').doc(myUid);

      final controller = StreamController<MultiplayerGameState>.broadcast();
      DocumentSnapshot<Map<String, dynamic>>? latestGameSnap;
      DocumentSnapshot<Map<String, dynamic>>? latestHandSnap;

      void emitCombined() {
        if (latestGameSnap == null || !latestGameSnap!.exists || latestGameSnap!.data() == null) {
          final mock = _mockGames[gameId];
          if (mock != null) {
            final hand = _mockPrivateHands['${gameId}_$myUid'] ?? [];
            controller.add(mock.copyWith(myHand: hand));
          }
          return;
        }

        final rawCards = (latestHandSnap?.data()?['cards'] as List<dynamic>?) ?? [];
        final parsedHand = rawCards.map((c) {
          if (c is int) return Card.fromInt(c);
          if (c is Map<String, dynamic>) {
            if (c['val'] != null) return Card.fromInt(c['val'] as int);
            if (c['intVal'] != null) return Card.fromInt(c['intVal'] as int);
            return Card.fromJson(c);
          }
          return Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
        }).toList();

        List<Card> finalHand = parsedHand;
        if (finalHand.isEmpty && _mockPrivateHands.containsKey('${gameId}_$myUid')) {
          finalHand = _mockPrivateHands['${gameId}_$myUid']!;
        }

        final parsedGame = MultiplayerGameState.fromJson(latestGameSnap!.data()!, myHand: finalHand);
        _mockGames[gameId] = parsedGame;
        controller.add(parsedGame);
      }

      final gameSub = gameRef.snapshots().listen((gSnap) {
        latestGameSnap = gSnap;
        emitCombined();
      }, onError: (e) {
        debugPrint('[MultiplayerService] gameRef snapshot error: $e');
      });

      final handSub = privateHandRef.snapshots().listen((hSnap) {
        latestHandSnap = hSnap;
        emitCombined();
      }, onError: (e) {
        debugPrint('[MultiplayerService] privateHandRef snapshot error: $e');
      });

      controller.onCancel = () {
        gameSub.cancel();
        handSub.cancel();
      };

      return controller.stream;
    }

    return _getOrCreateGameController(gameId).stream.map((g) {
      final hand = _mockPrivateHands['${gameId}_$myUid'] ?? [];
      return g.copyWith(myHand: hand);
    });
  }

  StreamController<TableLobby> _getOrCreateTableController(String tableId) {
    return _tableControllers.putIfAbsent(tableId, () => StreamController<TableLobby>.broadcast());
  }

  StreamController<MultiplayerGameState> _getOrCreateGameController(String gameId) {
    return _gameControllers.putIfAbsent(gameId, () => StreamController<MultiplayerGameState>.broadcast());
  }
}
