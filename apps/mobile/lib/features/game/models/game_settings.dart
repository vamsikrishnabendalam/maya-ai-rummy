/// User-configurable gameplay and elimination rules.
class GameSettings {
  /// Category / mode of game:
  /// 'Points Rummy' | 'Pool 101' | 'Pool 201' | 'Pool 301' | 'Best of 2 Deals'
  final String gameMode;

  /// Penalty for dropping on the first turn (default: 20 pts).
  final int firstDropPenalty;

  /// Penalty for dropping in the middle of a hand (default: 40 pts).
  final int middleDropPenalty;

  /// Full count penalty applied for invalid declarations (default: 80 pts).
  final int fullCountPenalty;

  /// Score at which a player is eliminated from the game (default: 201 pts).
  final int eliminationScore;

  /// Joker mode: 'OPEN' (default) or 'CLOSED'.
  final String jokerMode;

  /// Turn timer duration in seconds: 30, 45, 60, or 0 (No Limit). Default: 30s.
  final int turnTimerSeconds;

  const GameSettings({
    this.gameMode = 'Pool 201',
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.fullCountPenalty = 80,
    this.eliminationScore = 201,
    this.jokerMode = 'OPEN',
    this.turnTimerSeconds = 30,
  });

  bool get isClosedJoker => jokerMode == 'CLOSED';
  bool get isPointsRummy => gameMode == 'Points Rummy';
  bool get isDealsRummy => gameMode == 'Best of 2 Deals';
  bool get isPool101 => gameMode == 'Pool 101';
  bool get isPool201 => gameMode == 'Pool 201';
  bool get isPool301 => gameMode == 'Pool 301';
  bool get isPoolRummy => gameMode.startsWith('Pool');

  GameSettings copyWith({
    String? gameMode,
    int? firstDropPenalty,
    int? middleDropPenalty,
    int? fullCountPenalty,
    int? eliminationScore,
    String? jokerMode,
    int? turnTimerSeconds,
  }) {
    final mode = gameMode ?? this.gameMode;
    int elim = eliminationScore ?? this.eliminationScore;
    if (gameMode != null) {
      if (mode == 'Pool 101') elim = 101;
      else if (mode == 'Pool 201') elim = 201;
      else if (mode == 'Pool 301') elim = 301;
      else if (mode == 'Points Rummy' || mode == 'Best of 2 Deals') elim = 9999;
    }

    return GameSettings(
      gameMode: mode,
      firstDropPenalty: firstDropPenalty ?? this.firstDropPenalty,
      middleDropPenalty: middleDropPenalty ?? this.middleDropPenalty,
      fullCountPenalty: fullCountPenalty ?? this.fullCountPenalty,
      eliminationScore: elim,
      jokerMode: jokerMode ?? this.jokerMode,
      turnTimerSeconds: turnTimerSeconds ?? this.turnTimerSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'gameMode': gameMode,
    'firstDropPenalty': firstDropPenalty,
    'middleDropPenalty': middleDropPenalty,
    'fullCountPenalty': fullCountPenalty,
    'eliminationScore': eliminationScore,
    'jokerMode': jokerMode,
    'turnTimerSeconds': turnTimerSeconds,
  };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      gameMode: json['gameMode'] ?? 'Pool 201',
      firstDropPenalty: json['firstDropPenalty'] ?? 20,
      middleDropPenalty: json['middleDropPenalty'] ?? 40,
      fullCountPenalty: json['fullCountPenalty'] ?? 80,
      eliminationScore: json['eliminationScore'] ?? 201,
      jokerMode: json['jokerMode'] ?? 'OPEN',
      turnTimerSeconds: json['turnTimerSeconds'] ?? 30,
    );
  }
}
