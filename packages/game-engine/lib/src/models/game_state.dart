import 'card.dart';
import 'player.dart';
import '../rules/joker_utils.dart';

enum GamePhase { WAITING, MATCHED, DEALING, PLAYER_TURN, DRAW_PHASE, DISCARD_PHASE, DECLARATION, VALIDATION, RESULT, SETTLEMENT, COMPLETE }

class GameState {
  final String gameId;
  final List<Player> players;
  final List<Card> openPile;
  final List<Card> closedDeck;
  final Card? wildJoker;
  final int currentPlayerIndex;
  final int turnNumber;
  final GamePhase phase;
  final DateTime lastActionTime;
  final Card? cardDrawnFromOpenThisTurn;

  GameState({
    required this.gameId,
    required this.players,
    this.openPile = const [],
    this.closedDeck = const [],
    this.wildJoker,
    this.currentPlayerIndex = 0,
    this.turnNumber = 0,
    this.phase = GamePhase.WAITING,
    DateTime? lastActionTime,
    this.cardDrawnFromOpenThisTurn,
  }) : lastActionTime = lastActionTime ?? DateTime.now();

  GameState copyWith({
    String? gameId,
    List<Player>? players,
    List<Card>? openPile,
    List<Card>? closedDeck,
    Card? wildJoker,
    int? currentPlayerIndex,
    int? turnNumber,
    GamePhase? phase,
    DateTime? lastActionTime,
    Card? cardDrawnFromOpenThisTurn,
    bool clearCardDrawnFromOpenThisTurn = false,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      players: players ?? List.from(this.players),
      openPile: openPile ?? List.from(this.openPile),
      closedDeck: closedDeck ?? List.from(this.closedDeck),
      wildJoker: wildJoker ?? this.wildJoker,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      turnNumber: turnNumber ?? this.turnNumber,
      phase: phase ?? this.phase,
      lastActionTime: lastActionTime ?? this.lastActionTime,
      cardDrawnFromOpenThisTurn: clearCardDrawnFromOpenThisTurn
          ? null
          : (cardDrawnFromOpenThisTurn ?? this.cardDrawnFromOpenThisTurn),
    );
  }

  String get currentPlayerId => players[currentPlayerIndex].id;
  Rank? get effectiveWildRank => JokerUtils.getEffectiveWildRank(wildJoker);
  bool isJoker(Card card) => JokerUtils.isJoker(card, wildJoker);
  bool isWildJoker(Card card) => JokerUtils.isWildJoker(card, wildJoker);

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'players': players.map((p) => p.toJson()).toList(),
        'openPile': openPile.map((c) => c.toInt()).toList(),
        'closedDeck': closedDeck.map((c) => c.toInt()).toList(),
        'wildJoker': wildJoker?.toInt(),
        'currentPlayerIndex': currentPlayerIndex,
        'turnNumber': turnNumber,
        'phase': phase.name,
        'lastActionTime': lastActionTime.toIso8601String(),
        'cardDrawnFromOpenThisTurn': cardDrawnFromOpenThisTurn?.toInt(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        gameId: json['gameId'],
        players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
        openPile: (json['openPile'] as List).map((val) => Card.fromInt(val)).toList(),
        closedDeck: (json['closedDeck'] as List).map((val) => Card.fromInt(val)).toList(),
        wildJoker: json['wildJoker'] != null ? Card.fromInt(json['wildJoker']) : null,
        currentPlayerIndex: json['currentPlayerIndex'],
        turnNumber: json['turnNumber'],
        phase: GamePhase.values.byName(json['phase']),
        lastActionTime: DateTime.parse(json['lastActionTime']),
        cardDrawnFromOpenThisTurn: json['cardDrawnFromOpenThisTurn'] != null
            ? Card.fromInt(json['cardDrawnFromOpenThisTurn'])
            : null,
      );
}
