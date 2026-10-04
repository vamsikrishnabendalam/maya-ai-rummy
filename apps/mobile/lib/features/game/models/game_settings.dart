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

  const GameSettings({
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.fullCountPenalty = 80,
    this.eliminationScore = 201,
  });

  GameSettings copyWith({
    int? firstDropPenalty,
    int? middleDropPenalty,
    int? fullCountPenalty,
    int? eliminationScore,
  }) {
    return GameSettings(
      firstDropPenalty: firstDropPenalty ?? this.firstDropPenalty,
      middleDropPenalty: middleDropPenalty ?? this.middleDropPenalty,
      fullCountPenalty: fullCountPenalty ?? this.fullCountPenalty,
      eliminationScore: eliminationScore ?? this.eliminationScore,
    );
  }
}
