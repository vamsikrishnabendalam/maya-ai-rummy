/// User-configurable gameplay and elimination rules.
class GameSettings {
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

  const GameSettings({
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.fullCountPenalty = 80,
    this.eliminationScore = 201,
    this.jokerMode = 'OPEN',
  });

  bool get isClosedJoker => jokerMode == 'CLOSED';

  GameSettings copyWith({
    int? firstDropPenalty,
    int? middleDropPenalty,
    int? fullCountPenalty,
    int? eliminationScore,
    String? jokerMode,
  }) {
    return GameSettings(
      firstDropPenalty: firstDropPenalty ?? this.firstDropPenalty,
      middleDropPenalty: middleDropPenalty ?? this.middleDropPenalty,
      fullCountPenalty: fullCountPenalty ?? this.fullCountPenalty,
      eliminationScore: eliminationScore ?? this.eliminationScore,
      jokerMode: jokerMode ?? this.jokerMode,
    );
  }
}
