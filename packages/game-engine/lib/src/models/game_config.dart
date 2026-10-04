enum GameMode { POINTS, POOL_101, POOL_201, DEALS }

class GameConfig {
  final String gameId;
  final GameMode mode;
  final int maxPlayers;
  final int turnTimeoutSeconds;
  final int deckCount;
  final int firstDropPenalty;
  final int middleDropPenalty;
  final int fullCountPenalty;
  final int eliminationScore;

  const GameConfig({
    required this.gameId,
    required this.mode,
    required this.maxPlayers,
    this.turnTimeoutSeconds = 30,
    this.deckCount = 2,
    this.firstDropPenalty = 20,
    this.middleDropPenalty = 40,
    this.fullCountPenalty = 80,
    this.eliminationScore = 201,
  });
}
