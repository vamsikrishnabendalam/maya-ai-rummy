import 'package:game_engine/game_engine.dart';

enum ThreatLevel { low, medium, high, critical }

/// Models opponent threat and calculates discard danger based solely on publicly observable actions.
/// Never peeks at opponent's hidden cards.
class OpponentThreatTracker {
  final List<Card> picksFromOpen = [];
  final List<Card> discards = [];

  void recordPickFromOpen(Card card) {
    picksFromOpen.add(card);
  }

  void recordDiscard(Card card) {
    discards.add(card);
  }

  /// Estimates the opponent's threat level based on public signals.
  ThreatLevel evaluateThreatLevel(int turnNumber) {
    if (picksFromOpen.length >= 3 || turnNumber >= 14) {
      return ThreatLevel.critical;
    }
    if (picksFromOpen.length >= 2 || turnNumber >= 9) {
      return ThreatLevel.high;
    }
    if (picksFromOpen.length >= 1 || turnNumber >= 5) {
      return ThreatLevel.medium;
    }
    return ThreatLevel.low;
  }

  /// Calculates a danger score (0.0 to 1.0) for discarding [candidate].
  /// Higher score means discarding this card is more likely to help the opponent.
  double getDiscardDanger(Card candidate, Card? openJoker, int turnNumber) {
    // 1. Jokers are universally dangerous to discard (opponent can use any joker)
    if (JokerUtils.isJoker(candidate, openJoker)) {
      return 1.0;
    }

    // 2. Safe discards: if opponent previously discarded this card, or rank has been seen discarded
    if (discards.any((d) => d.suit == candidate.suit && d.rank == candidate.rank)) {
      return 0.05; // Very safe card
    }

    // 3. Danger based on opponent open picks:
    if (picksFromOpen.isNotEmpty && candidate.suit != null && candidate.rank != null) {
      final candVal = SequenceValidator.rankToLowValue(candidate.rank!);

      for (final pick in picksFromOpen) {
        if (pick.suit == candidate.suit && pick.rank != null) {
          final pickVal = SequenceValidator.rankToLowValue(pick.rank!);
          final diff = (candVal - pickVal).abs();
          if (diff == 1) {
            return 0.90; // Immediate neighbor in suit! Extremely dangerous.
          } else if (diff == 2) {
            return 0.75; // Inside sequence neighbor. Very dangerous.
          }
        } else if (pick.rank == candidate.rank) {
          return 0.70; // Matching rank (potential set candidate).
        }
      }
    }

    // 4. Middle cards (5, 6, 7, 8, 9) have higher natural sequence flexibility than edges
    final candRankVal = candidate.rank != null ? SequenceValidator.rankToLowValue(candidate.rank!) : 5;
    if (candRankVal >= 5 && candRankVal <= 9) {
      return 0.25;
    }

    // Corners (A, 2, K, Q) with no opponent interest are generally safer to discard
    return 0.15;
  }
}
