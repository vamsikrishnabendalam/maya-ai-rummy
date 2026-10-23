import 'package:game_engine/game_engine.dart';

class TablePlayer {
  final String uid;
  final String displayName;
  final String photoURL;
  final int seatIndex;
  final bool isHost;
  final bool connected;
  final int cardCount;
  final int score;
  final String status; // ACTIVE | DECLARED | WRONG_SHOW | DROPPED | ELIMINATED
  final int misses; // Number of missed turns / timeouts (up to 3 chances)
  final DateTime? disconnectedAt;
  final DateTime? lastHeartbeat;

  const TablePlayer({
    required this.uid,
    required this.displayName,
    this.photoURL = '',
    required this.seatIndex,
    this.isHost = false,
    this.connected = true,
    this.cardCount = 13,
    this.score = 0,
    this.status = 'ACTIVE',
    this.misses = 0,
    this.disconnectedAt,
    this.lastHeartbeat,
  });

  TablePlayer copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    int? seatIndex,
    bool? isHost,
    bool? connected,
    int? cardCount,
    int? score,
    String? status,
    int? misses,
    DateTime? disconnectedAt,
    bool clearDisconnectedAt = false,
    DateTime? lastHeartbeat,
  }) {
    return TablePlayer(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      seatIndex: seatIndex ?? this.seatIndex,
      isHost: isHost ?? this.isHost,
      connected: connected ?? this.connected,
      cardCount: cardCount ?? this.cardCount,
      score: score ?? this.score,
      status: status ?? this.status,
      misses: misses ?? this.misses,
      disconnectedAt: clearDisconnectedAt ? null : (disconnectedAt ?? this.disconnectedAt),
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
    );
  }

  factory TablePlayer.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        if ((d as dynamic).toDate != null) return (d as dynamic).toDate() as DateTime;
      } catch (_) {}
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return TablePlayer(
      uid: json['uid'] ?? '',
      displayName: json['displayName'] ?? 'Player',
      photoURL: json['photoURL'] ?? '',
      seatIndex: json['seatIndex'] ?? 0,
      isHost: json['isHost'] ?? false,
      connected: json['connected'] ?? true,
      cardCount: json['cardCount'] ?? 13,
      score: json['score'] ?? 0,
      status: json['status'] ?? 'ACTIVE',
      misses: (json['misses'] as num?)?.toInt() ?? 0,
      disconnectedAt: parseDate(json['disconnectedAt']),
      lastHeartbeat: parseDate(json['lastHeartbeat']),
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'photoURL': photoURL,
    'seatIndex': seatIndex,
    'isHost': isHost,
    'connected': connected,
    'cardCount': cardCount,
    'score': score,
    'status': status,
    'misses': misses,
    'disconnectedAt': disconnectedAt?.toIso8601String(),
    'lastHeartbeat': lastHeartbeat?.toIso8601String(),
  };
}

class TableLobby {
  final String tableId;
  final String roomCode;
  final String tableName;
  final String hostUid;
  final int maxPlayers;
  final int playerCount;
  final String status; // WAITING | STARTING | PLAYING | COMPLETED | ABANDONED
  final bool hasPassword;
  final String? activeGameId;
  final List<TablePlayer> players;
  final String gameMode; // 'Points Rummy' | 'Pool 101' | 'Pool 201' | 'Best of 2 Deals'
  final int turnTimerSeconds; // 30 | 45 | 60
  final int firstDropPenalty; // 20
  final int middleDropPenalty; // 40
  final int maxPenalty; // 80
  final String entryType; // 'FREE' | 'COIN'
  final int entryCoins; // min 100 for coin tables
  final int creationFee; // default 50 for coin tables
  final int prizePool;
  final List<String> kickedPlayerUids;

  const TableLobby({
    required this.tableId,
    required this.roomCode,
    required this.tableName,
    required this.hostUid,
    this.maxPlayers = 2,
    this.playerCount = 1,
    this.status = 'WAITING',
    this.hasPassword = false,
    this.activeGameId,
    this.players = const [],
    this.gameMode = 'Points Rummy',
    this.turnTimerSeconds = 30,
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.maxPenalty = 80,
    this.entryType = 'FREE',
    this.entryCoins = 0,
    this.creationFee = 0,
    this.prizePool = 0,
    this.kickedPlayerUids = const [],
  });

  bool get isWaiting => status == 'WAITING';
  bool get isPlaying => status == 'PLAYING';
  bool get isFull => players.length >= maxPlayers;
  bool get isCoinTable => entryType == 'COIN';

  TableLobby copyWith({
    String? tableId,
    String? roomCode,
    String? tableName,
    String? hostUid,
    int? maxPlayers,
    int? playerCount,
    String? status,
    bool? hasPassword,
    String? activeGameId,
    List<TablePlayer>? players,
    String? gameMode,
    int? turnTimerSeconds,
    int? firstDropPenalty,
    int? middleDropPenalty,
    int? maxPenalty,
    String? entryType,
    int? entryCoins,
    int? creationFee,
    int? prizePool,
    List<String>? kickedPlayerUids,
  }) {
    return TableLobby(
      tableId: tableId ?? this.tableId,
      roomCode: roomCode ?? this.roomCode,
      tableName: tableName ?? this.tableName,
      hostUid: hostUid ?? this.hostUid,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      playerCount: playerCount ?? this.playerCount,
      status: status ?? this.status,
      hasPassword: hasPassword ?? this.hasPassword,
      activeGameId: activeGameId ?? this.activeGameId,
      players: players ?? this.players,
      gameMode: gameMode ?? this.gameMode,
      turnTimerSeconds: turnTimerSeconds ?? this.turnTimerSeconds,
      firstDropPenalty: firstDropPenalty ?? this.firstDropPenalty,
      middleDropPenalty: middleDropPenalty ?? this.middleDropPenalty,
      maxPenalty: maxPenalty ?? this.maxPenalty,
      entryType: entryType ?? this.entryType,
      entryCoins: entryCoins ?? this.entryCoins,
      creationFee: creationFee ?? this.creationFee,
      prizePool: prizePool ?? this.prizePool,
      kickedPlayerUids: kickedPlayerUids ?? this.kickedPlayerUids,
    );
  }

  factory TableLobby.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    return TableLobby(
      tableId: json['tableId'] ?? '',
      roomCode: json['roomCode'] ?? '',
      tableName: json['tableName'] ?? 'Maya Table',
      hostUid: json['hostUid'] ?? '',
      maxPlayers: json['maxPlayers'] ?? 2,
      playerCount: json['playerCount'] ?? rawPlayers.length,
      status: json['status'] ?? 'WAITING',
      hasPassword: json['hasPassword'] ?? false,
      activeGameId: json['activeGameId'],
      players: rawPlayers.map((p) => TablePlayer.fromJson(p as Map<String, dynamic>)).toList(),
      gameMode: json['gameMode'] ?? 'Points Rummy',
      turnTimerSeconds: json['turnTimerSeconds'] ?? 30,
      firstDropPenalty: json['firstDropPenalty'] ?? 20,
      middleDropPenalty: json['middleDropPenalty'] ?? 40,
      maxPenalty: json['maxPenalty'] ?? 80,
      entryType: json['entryType'] ?? 'FREE',
      entryCoins: json['entryCoins'] ?? 0,
      creationFee: json['creationFee'] ?? 0,
      prizePool: json['prizePool'] ?? 0,
      kickedPlayerUids: (json['kickedPlayerUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'tableId': tableId,
    'roomCode': roomCode,
    'tableName': tableName,
    'hostUid': hostUid,
    'maxPlayers': maxPlayers,
    'playerCount': playerCount,
    'status': status,
    'hasPassword': hasPassword,
    'activeGameId': activeGameId,
    'players': players.map((p) => p.toJson()).toList(),
    'gameMode': gameMode,
    'turnTimerSeconds': turnTimerSeconds,
    'firstDropPenalty': firstDropPenalty,
    'middleDropPenalty': middleDropPenalty,
    'maxPenalty': maxPenalty,
    'entryType': entryType,
    'entryCoins': entryCoins,
    'creationFee': creationFee,
    'prizePool': prizePool,
    'kickedPlayerUids': kickedPlayerUids,
  };
}

class MultiplayerFinalResult {
  final String uid;
  final String displayName;
  final String photoURL;
  final int seatIndex;
  final int score;
  final bool isWinner;

  const MultiplayerFinalResult({
    required this.uid,
    required this.displayName,
    this.photoURL = '',
    required this.seatIndex,
    required this.score,
    required this.isWinner,
  });

  factory MultiplayerFinalResult.fromJson(Map<String, dynamic> json) => MultiplayerFinalResult(
    uid: json['uid'] ?? '',
    displayName: json['displayName'] ?? 'Player',
    photoURL: json['photoURL'] ?? '',
    seatIndex: json['seatIndex'] ?? 0,
    score: json['score'] ?? 0,
    isWinner: json['isWinner'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'photoURL': photoURL,
    'seatIndex': seatIndex,
    'score': score,
    'isWinner': isWinner,
  };
}

class MultiplayerGameState {
  final String gameId;
  final String tableId;
  final String roomCode;
  final String tableName;
  final String gameMode;
  final String status; // IN_PROGRESS | DECLARING | COMPLETED
  final int playerCount;
  final String currentTurnPlayerId;
  final int turnNumber;
  final String phase; // DRAW_PHASE | DISCARD_PHASE
  final DateTime? turnDeadline;
  final int turnTimerSeconds; // 30 | 45 | 60 | 0 (No Limit)
  final int firstDropPenalty; // 20
  final int middleDropPenalty; // 40
  final int maxPenalty; // 80
  final String entryType; // 'FREE' | 'COIN'
  final int entryCoins;
  final int creationFee;
  final int prizePool;
  final Card? openJoker;
  final String effectiveWildRank;
  final List<Card> openPile;
  final List<int> closedDeck; // Authoritative shuffled remaining deck card ints
  final int closedDeckRemaining;
  final String dealerPlayerId;
  final Card? cardDrawnFromOpenThisTurn;
  final String? winnerPlayerId;
  final String? declaringPlayerId;
  final String? declaringPlayerName;
  final DateTime? declarationDeadline;
  final List<String> submittedPlayerUids;
  final List<MultiplayerFinalResult> finalResults;
  final List<TablePlayer> players;
  final List<Card> myHand;
  final List<Map<String, dynamic>> actionLog;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const MultiplayerGameState({
    required this.gameId,
    required this.tableId,
    this.roomCode = '',
    this.tableName = 'Maya Rummy Table',
    this.gameMode = 'Points Rummy',
    this.status = 'IN_PROGRESS',
    this.playerCount = 2,
    this.currentTurnPlayerId = '',
    this.turnNumber = 0,
    this.phase = 'DRAW_PHASE',
    this.turnDeadline,
    this.turnTimerSeconds = 30,
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.maxPenalty = 80,
    this.entryType = 'FREE',
    this.entryCoins = 0,
    this.creationFee = 0,
    this.prizePool = 0,
    this.openJoker,
    this.effectiveWildRank = 'two',
    this.openPile = const [],
    this.closedDeck = const [],
    this.closedDeckRemaining = 80,
    this.dealerPlayerId = '',
    this.cardDrawnFromOpenThisTurn,
    this.winnerPlayerId,
    this.declaringPlayerId,
    this.declaringPlayerName,
    this.declarationDeadline,
    this.submittedPlayerUids = const [],
    this.finalResults = const [],
    this.players = const [],
    this.myHand = const [],
    this.actionLog = const [],
    this.startedAt,
    this.endedAt,
  });

  bool get isDrawPhase => phase == 'DRAW_PHASE';
  bool get isDiscardPhase => phase == 'DISCARD_PHASE';
  bool get isDeclaring => status == 'DECLARING';
  bool get isGameOver => status == 'COMPLETED';
  bool get isCompleted => status == 'COMPLETED';

  bool isMyTurn(String myUid) => currentTurnPlayerId == myUid;

  MultiplayerGameState copyWith({
    String? gameId,
    String? tableId,
    String? roomCode,
    String? tableName,
    String? gameMode,
    String? status,
    int? playerCount,
    String? currentTurnPlayerId,
    int? turnNumber,
    String? phase,
    DateTime? turnDeadline,
    int? turnTimerSeconds,
    int? firstDropPenalty,
    int? middleDropPenalty,
    int? maxPenalty,
    String? entryType,
    int? entryCoins,
    int? creationFee,
    int? prizePool,
    Card? openJoker,
    String? effectiveWildRank,
    List<Card>? openPile,
    List<int>? closedDeck,
    int? closedDeckRemaining,
    String? dealerPlayerId,
    Card? cardDrawnFromOpenThisTurn,
    bool clearCardDrawnFromOpen = false,
    String? winnerPlayerId,
    bool clearWinner = false,
    String? declaringPlayerId,
    String? declaringPlayerName,
    bool clearDeclarer = false,
    DateTime? declarationDeadline,
    List<String>? submittedPlayerUids,
    List<MultiplayerFinalResult>? finalResults,
    List<TablePlayer>? players,
    List<Card>? myHand,
    List<Map<String, dynamic>>? actionLog,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return MultiplayerGameState(
      gameId: gameId ?? this.gameId,
      tableId: tableId ?? this.tableId,
      roomCode: roomCode ?? this.roomCode,
      tableName: tableName ?? this.tableName,
      gameMode: gameMode ?? this.gameMode,
      status: status ?? this.status,
      playerCount: playerCount ?? this.playerCount,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      turnNumber: turnNumber ?? this.turnNumber,
      phase: phase ?? this.phase,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      turnTimerSeconds: turnTimerSeconds ?? this.turnTimerSeconds,
      firstDropPenalty: firstDropPenalty ?? this.firstDropPenalty,
      middleDropPenalty: middleDropPenalty ?? this.middleDropPenalty,
      maxPenalty: maxPenalty ?? this.maxPenalty,
      entryType: entryType ?? this.entryType,
      entryCoins: entryCoins ?? this.entryCoins,
      creationFee: creationFee ?? this.creationFee,
      prizePool: prizePool ?? this.prizePool,
      openJoker: openJoker ?? this.openJoker,
      effectiveWildRank: effectiveWildRank ?? this.effectiveWildRank,
      openPile: openPile ?? this.openPile,
      closedDeck: closedDeck ?? this.closedDeck,
      closedDeckRemaining: closedDeckRemaining ?? this.closedDeckRemaining,
      dealerPlayerId: dealerPlayerId ?? this.dealerPlayerId,
      cardDrawnFromOpenThisTurn: clearCardDrawnFromOpen ? null : (cardDrawnFromOpenThisTurn ?? this.cardDrawnFromOpenThisTurn),
      winnerPlayerId: clearWinner ? null : (winnerPlayerId ?? this.winnerPlayerId),
      declaringPlayerId: clearDeclarer ? null : (declaringPlayerId ?? this.declaringPlayerId),
      declaringPlayerName: clearDeclarer ? null : (declaringPlayerName ?? this.declaringPlayerName),
      declarationDeadline: declarationDeadline ?? this.declarationDeadline,
      submittedPlayerUids: submittedPlayerUids ?? this.submittedPlayerUids,
      finalResults: finalResults ?? this.finalResults,
      players: players ?? this.players,
      myHand: myHand ?? this.myHand,
      actionLog: actionLog ?? this.actionLog,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  factory MultiplayerGameState.fromJson(Map<String, dynamic> json, {List<Card> myHand = const []}) {
    final rawPlayers = json['players'] as List<dynamic>? ?? [];
    final rawOpenPile = json['openPile'] as List<dynamic>? ?? [];
    final rawClosedDeck = (json['closedDeck'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
    final rawResults = json['finalResults'] as List<dynamic>? ?? [];
    final rawActionLog = (json['actionLog'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final rawSubmitted = (json['submittedPlayerUids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    Card? parsedJoker;
    if (json['openJoker'] != null) {
      final oj = json['openJoker'];
      if (oj is int) {
        parsedJoker = Card.fromInt(oj);
      } else if (oj is Map<String, dynamic>) {
        parsedJoker = Card.fromInt(oj['intVal'] ?? oj['val'] ?? 0);
      }
    }

    final parsedOpenPile = rawOpenPile.map((c) {
      if (c is int) return Card.fromInt(c);
      if (c is Map<String, dynamic>) return Card.fromInt(c['intVal'] ?? c['val'] ?? 0);
      return Card(suit: Suit.hearts, rank: Rank.ace, deckIndex: 0);
    }).toList();

    Card? openPickThisTurn;
    if (json['cardDrawnFromOpenThisTurn'] != null) {
      final c = json['cardDrawnFromOpenThisTurn'];
      if (c is int) openPickThisTurn = Card.fromInt(c);
      if (c is Map<String, dynamic>) openPickThisTurn = Card.fromInt(c['intVal'] ?? c['val'] ?? 0);
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        if ((d as dynamic).toDate != null) return (d as dynamic).toDate() as DateTime;
      } catch (_) {}
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return MultiplayerGameState(
      gameId: json['gameId'] ?? '',
      tableId: json['tableId'] ?? '',
      roomCode: json['roomCode'] ?? '',
      tableName: json['tableName'] ?? 'Maya Rummy Table',
      gameMode: json['gameMode'] ?? 'Points Rummy',
      status: json['status'] ?? 'IN_PROGRESS',
      playerCount: json['playerCount'] ?? rawPlayers.length,
      currentTurnPlayerId: json['currentTurnPlayerId'] ?? '',
      turnNumber: json['turnNumber'] ?? 0,
      phase: json['phase'] ?? 'DRAW_PHASE',
      turnDeadline: parseDate(json['turnDeadline']),
      turnTimerSeconds: json['turnTimerSeconds'] ?? 30,
      firstDropPenalty: json['firstDropPenalty'] ?? 20,
      middleDropPenalty: json['middleDropPenalty'] ?? 40,
      maxPenalty: json['maxPenalty'] ?? 80,
      entryType: json['entryType'] ?? 'FREE',
      entryCoins: json['entryCoins'] ?? 0,
      creationFee: json['creationFee'] ?? 0,
      prizePool: json['prizePool'] ?? 0,
      openJoker: parsedJoker,
      effectiveWildRank: json['effectiveWildRank'] ?? 'two',
      openPile: parsedOpenPile,
      closedDeck: rawClosedDeck,
      closedDeckRemaining: json['closedDeckRemaining'] ?? (rawClosedDeck.isNotEmpty ? rawClosedDeck.length : 80),
      dealerPlayerId: json['dealerPlayerId'] ?? '',
      cardDrawnFromOpenThisTurn: openPickThisTurn,
      winnerPlayerId: json['winnerPlayerId'],
      declaringPlayerId: json['declaringPlayerId'],
      declaringPlayerName: json['declaringPlayerName'],
      declarationDeadline: parseDate(json['declarationDeadline']),
      submittedPlayerUids: rawSubmitted,
      finalResults: rawResults.map((r) => MultiplayerFinalResult.fromJson(r as Map<String, dynamic>)).toList(),
      players: rawPlayers.map((p) => TablePlayer.fromJson(p as Map<String, dynamic>)).toList(),
      myHand: myHand,
      actionLog: rawActionLog,
      startedAt: parseDate(json['startedAt']),
      endedAt: parseDate(json['endedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'tableId': tableId,
    'roomCode': roomCode,
    'tableName': tableName,
    'gameMode': gameMode,
    'status': status,
    'playerCount': playerCount,
    'currentTurnPlayerId': currentTurnPlayerId,
    'turnNumber': turnNumber,
    'phase': phase,
    'turnDeadline': turnDeadline?.toIso8601String(),
    'turnTimerSeconds': turnTimerSeconds,
    'firstDropPenalty': firstDropPenalty,
    'middleDropPenalty': middleDropPenalty,
    'maxPenalty': maxPenalty,
    'entryType': entryType,
    'entryCoins': entryCoins,
    'creationFee': creationFee,
    'prizePool': prizePool,
    'openJoker': openJoker?.toInt(),
    'effectiveWildRank': effectiveWildRank,
    'openPile': openPile.map((c) => c.toInt()).toList(),
    'closedDeck': closedDeck,
    'closedDeckRemaining': closedDeckRemaining,
    'dealerPlayerId': dealerPlayerId,
    'cardDrawnFromOpenThisTurn': cardDrawnFromOpenThisTurn?.toInt(),
    'winnerPlayerId': winnerPlayerId,
    'declaringPlayerId': declaringPlayerId,
    'declaringPlayerName': declaringPlayerName,
    'declarationDeadline': declarationDeadline?.toIso8601String(),
    'submittedPlayerUids': submittedPlayerUids,
    'finalResults': finalResults.map((r) => r.toJson()).toList(),
    'players': players.map((p) => p.toJson()).toList(),
    'actionLog': actionLog,
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
  };
}
