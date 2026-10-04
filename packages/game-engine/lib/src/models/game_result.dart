class GameResult {
  final String? winnerId;
  final Map<String, int> playerScores;
  final Map<String, double> playerPayouts;

  GameResult({
    this.winnerId,
    required this.playerScores,
    this.playerPayouts = const {},
  });
}
