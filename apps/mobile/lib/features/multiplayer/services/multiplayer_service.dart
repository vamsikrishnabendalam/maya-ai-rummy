import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

    // Direct Firestore lookup by roomCode
    TableLobby? found;

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        final querySnap = await _firestore!
            .collection('tables')
            .where('roomCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          found = TableLobby.fromJson(querySnap.docs.first.data());
        }
      } catch (e) {
        debugPrint('[MultiplayerService] joinTable Firestore lookup notice: $e');
      }
    }

    if (found == null) {
      for (final t in _mockTables.values) {
        if (t.roomCode == cleanCode) {
          found = t;
          break;
        }
      }
    }

    if (found == null) {
      throw Exception('Table $cleanCode not found. Please verify the room code.');
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

    // If game has already started and player was not in it
    if (found.status == 'PLAYING') {
      throw Exception('Game has already started in room $cleanCode. Spectating or joining mid-game is not permitted.');
    }

    // If room is already concluded or abandoned
    if (found.status == 'COMPLETED' || found.status == 'FINISHED' || found.status == 'ABANDONED') {
      throw Exception('Table $cleanCode has concluded or expired.');
    }

    if (found.players.length >= found.maxPlayers) {
      throw Exception('Table $cleanCode is full (${found.players.length}/${found.maxPlayers} players).');
    }

    // Coin table entry verification & atomic deduction
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

    // Assign next available seat
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

    if (FirebaseConfig.isInitialized && _firestore != null) {
      try {
        await _firestore!.collection('tables').doc(found.tableId).set(updatedLobby.toJson());
      } catch (e) {
        debugPrint('[MultiplayerService] joinTable Firestore update notice: $e');
      }
    }

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

    // Deck & Cards: 2 standard decks = 106 cards, cryptographically shuffled using Random.secure()
    final deck = Deck.initialize(2);
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

    if (allPhysicalCardsAccounted.length != 106) {
      debugPrint('[MultiplayerService] DEAL_VALIDATION_FAILED: Total cards accounted ${allPhysicalCardsAccounted.length} != 106');
      throw Exception('DEAL_VALIDATION_FAILED: Total accounted cards ${allPhysicalCardsAccounted.length} != 106.');
    }

    final distinctAccounted = allPhysicalCardsAccounted.toSet();
    if (distinctAccounted.length != 106) {
      debugPrint('[MultiplayerService] DEAL_VALIDATION_FAILED: Duplicate card detected across table: distinct=${distinctAccounted.length}');
      throw Exception('DEAL_VALIDATION_FAILED: Duplicate physical card ownership detected across table.');
    }

    final initialActionLog = [
      {
        'seq': 1,
        'timestamp': now.toIso8601String(),
        'type': 'GAME_STARTED',
        'playerId': lobby.hostUid,
        'description': 'Game started with ${lobby.players.length} players. Room: ${lobby.roomCode}',
      },
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
            final currentActIdx = remainingActive.indexWhere((p) => p.uid == myUid);
            final nextActIdx = (currentActIdx >= 0 && remainingActive.isNotEmpty)
                ? ((currentActIdx + 1) % remainingActive.length)
                : 0;
            final nextPlayer = remainingActive[nextActIdx];

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
      final currentActIdx = remainingActive.indexWhere((p) => p.uid == myUid);
      final nextActIdx = (currentActIdx >= 0 && remainingActive.isNotEmpty)
          ? ((currentActIdx + 1) % remainingActive.length)
          : 0;
      final nextPlayer = remainingActive[nextActIdx];

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

  /// Declare Game with pure GameEngine meld verification & point calculation
  Future<Map<String, dynamic>> declareGame({
    required String gameId,
    required String myUid,
    required Card discardCard,
    required List<List<Card>> groups,
  }) async {
    final game = _mockGames[gameId];
    if (game == null) throw Exception('Game not found');

    final valRes = DeclarationValidator().validate(groups, game.openJoker!);
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

      final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'DECLARE_VALID',
        'playerId': myUid,
        'card': discardCard.toInt(),
        'description': '${winner.displayName} declared a valid show with 0 points! 👑 Opponents have 30s to arrange their cards and submit final hand.',
      });

      // Authoritative 30s server deadline for other players to submit their hands
      final deadline = now.add(const Duration(seconds: 30));

      final updatedGame = game.copyWith(
        status: 'DECLARING',
        declaringPlayerId: myUid,
        declaringPlayerName: winner.displayName,
        declarationDeadline: deadline,
        submittedPlayerUids: [myUid],
        finalResults: [winnerResult],
        actionLog: actionLog,
      );

      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);

      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('games').doc(gameId).update(updatedGame.toJson());
        } catch (e) {
          debugPrint('[MultiplayerService] declareGame Firestore update notice: $e');
        }
      }

      return {
        'isValid': true,
        'status': 'DECLARING',
        'message': 'Valid Declaration! You won the game with 0 points! Waiting for other players to submit their hands...',
      };
    } else {
      // Wrong show: 80 points penalty
      final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
      final pName = game.players.firstWhere((p) => p.uid == myUid, orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0)).displayName;
      actionLog.add({
        'seq': actionLog.length + 1,
        'timestamp': now.toIso8601String(),
        'type': 'DECLARE_INVALID',
        'playerId': myUid,
        'card': discardCard.toInt(),
        'description': '$pName submitted an invalid declaration (${valRes.errorMessage}). Penalized 80 points.',
      });

      final updatedGame = game.copyWith(actionLog: actionLog);
      _mockGames[gameId] = updatedGame;
      _getOrCreateGameController(gameId).add(updatedGame);

      if (FirebaseConfig.isInitialized && _firestore != null) {
        try {
          await _firestore!.collection('games').doc(gameId).update({'actionLog': actionLog});
        } catch (_) {}
      }

      return {
        'isValid': false,
        'message': 'Invalid Declaration: ${valRes.errorMessage}. 80 points penalty.',
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

    final now = DateTime.now();
    final player = game.players.firstWhere((p) => p.uid == myUid,
        orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0));

    // Calculate deadwood score using GameEngine scoring rules
    final score = Scoring.calculateHandDeadwood(
      groups: groups,
      wildJoker: game.openJoker!,
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
    if (updatedSubmittedUids.length >= game.players.length) {
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
        final pHand = _mockPrivateHands['${game.gameId}_${p.uid}'] ?? [];
        int score = 80;
        if (pHand.isNotEmpty) {
          score = HandPartitioner.findBestPartition(pHand, game.openJoker).penaltyScore.clamp(0, 80);
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

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'ROUND_CONCLUDED',
      'description': 'Round concluded. Final scores tallied.',
    });

    final winnerId = game.declaringPlayerId;

    // 1. Award virtual coin prize pot if coin table
    if (winnerId != null && game.entryType == 'COIN' && game.prizePool > 0) {
      _walletService.creditCoins(
        uid: winnerId,
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
    for (final r in results) {
      _progressionService.recordCompletedMatch(
        uid: r.uid,
        won: r.uid == winnerId,
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
      winnerPlayerId: winnerId,
      finalResults: results,
      actionLog: actionLog,
      endedAt: now,
    );
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

          // If in DRAW_PHASE: Pick 1 card from closed deck and drop to open pile
          if (phase == 'DRAW_PHASE' && closedDeck.isNotEmpty) {
            final cardInt = closedDeck.removeLast();
            openPile.add(cardInt);
          } else if (phase == 'DISCARD_PHASE') {
            // Player already drew a card into private hand; drop the extra card to open pile
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
          }

          // Eliminate the timed-out player (1 miss = elimination with current score)
          final timedOutPlayer = players[pIdx];
          final elimScore = timedOutPlayer.score > 0 ? timedOutPlayer.score : 80;
          players[pIdx] = timedOutPlayer.copyWith(status: 'ELIMINATED', score: elimScore);

          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
              'description': '${timedOutPlayer.displayName} missed turn and was eliminated. Score: $elimScore.',
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
            return;
          }

          // Advance to next active player
          final nextPlayer = remainingActive.first;

          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'PLAYER_ELIMINATED',
            'playerId': currentTurnUid,
            'description': '${timedOutPlayer.displayName} missed turn and was eliminated. Turn advanced to ${nextPlayer.displayName}.',
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
    final elimScore = timedOutPlayer.score > 0 ? timedOutPlayer.score : 80;
    players[pIdx] = timedOutPlayer.copyWith(status: 'ELIMINATED', score: elimScore);

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
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
        'description': '${timedOutPlayer.displayName} missed turn and was eliminated. Score: $elimScore.',
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
        closedDeckRemaining: closedDeck.length,
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

    final nextPlayer = remainingActive.first;

    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'PLAYER_ELIMINATED',
      'playerId': game.currentTurnPlayerId,
      'description': '${timedOutPlayer.displayName} missed turn and was eliminated. Turn advanced to ${nextPlayer.displayName}.',
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

          // Determine current winner (lowest score among active players)
          final activePlayers = players.where((p) => p.status == 'ACTIVE' || p.status == 'DECLARED').toList();
          activePlayers.sort((a, b) => a.score.compareTo(b.score));
          final winner = activePlayers.isNotEmpty ? activePlayers.first : players.first;

          final finalResults = players.map((p) {
            final isWin = p.uid == winner.uid;
            return MultiplayerFinalResult(
              uid: p.uid,
              displayName: p.displayName,
              photoURL: p.photoURL,
              seatIndex: p.seatIndex,
              score: p.score,
              isWinner: isWin,
            );
          }).toList();

          final rawLog = (gameData['actionLog'] as List<dynamic>?) ?? [];
          final actionLog = rawLog.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          actionLog.add({
            'seq': actionLog.length + 1,
            'timestamp': now.toIso8601String(),
            'type': 'HOST_ENDED_GAME',
            'playerId': myUid,
            'description': 'The table owner ended the game/tournament.',
          });

          tx.update(gameRef, {
            'status': 'COMPLETED',
            'winnerPlayerId': winner.uid,
            'finalResults': finalResults.map((r) => r.toJson()).toList(),
            'endedAt': now.toIso8601String(),
            'actionLog': actionLog,
          });

          // Also update table status
          final tableId = gameData['tableId'] as String?;
          if (tableId != null) {
            final tableRef = _firestore!.collection('tables').doc(tableId);
            tx.update(tableRef, {'status': 'COMPLETED'});
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

    final activePlayers = game.players.where((p) => p.status == 'ACTIVE' || p.status == 'DECLARED').toList();
    activePlayers.sort((a, b) => a.score.compareTo(b.score));
    final winner = activePlayers.isNotEmpty ? activePlayers.first : game.players.first;

    final finalResults = game.players.map((p) {
      final isWin = p.uid == winner.uid;
      return MultiplayerFinalResult(
        uid: p.uid,
        displayName: p.displayName,
        photoURL: p.photoURL,
        seatIndex: p.seatIndex,
        score: p.score,
        isWinner: isWin,
      );
    }).toList();

    final actionLog = List<Map<String, dynamic>>.from(game.actionLog);
    actionLog.add({
      'seq': actionLog.length + 1,
      'timestamp': now.toIso8601String(),
      'type': 'HOST_ENDED_GAME',
      'playerId': myUid,
      'description': 'The table owner ended the game/tournament.',
    });

    final updatedGame = game.copyWith(
      status: 'COMPLETED',
      winnerPlayerId: winner.uid,
      finalResults: finalResults,
      endedAt: now,
      actionLog: actionLog,
    );

    _mockGames[gameId] = updatedGame;
    _getOrCreateGameController(gameId).add(updatedGame);
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
