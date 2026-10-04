/// Records score and outcome of an individual round/deal.
class RoundScore {
  final int roundNumber;
  final int humanScore;
  final int aiScore;
  final int cumulativeHumanScore;
  final int cumulativeAiScore;
  final String humanOutcome;
  final String aiOutcome;
  final DateTime timestamp;

  const RoundScore({
    required this.roundNumber,
    required this.humanScore,
    required this.aiScore,
    required this.cumulativeHumanScore,
    required this.cumulativeAiScore,
    required this.humanOutcome,
    required this.aiOutcome,
    required this.timestamp,
  });
}
