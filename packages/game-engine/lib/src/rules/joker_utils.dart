import '../models/card.dart';

/// Authoritative single source of truth for all Joker rules in Indian 13-Card Rummy.
class JokerUtils {
  /// Returns the effective Wild Joker Rank for a given open/wild joker card.
  ///
  /// RULE: If the card revealed as the Open Joker is a printed Joker,
  /// then ACE (A) MUST become the default Open Joker rank for all suits.
  static Rank? getEffectiveWildRank(Card? openJoker) {
    if (openJoker == null) return null;
    if (openJoker.isPrintedJoker || openJoker.rank == null) {
      return Rank.ace;
    }
    return openJoker.rank;
  }

  /// Authoritative check: whether a card functions as a Joker in this game.
  ///
  /// Returns true if:
  /// 1. The card is a Printed Joker, OR
  /// 2. The card is a wild joker whose rank matches the effective wild joker rank.
  static bool isJoker(Card card, Card? openJoker) {
    if (card.isPrintedJoker) return true;
    if (openJoker == null) return false;
    final wildRank = getEffectiveWildRank(openJoker);
    return wildRank != null && card.rank == wildRank;
  }

  /// Whether this specific card is a wild joker (not a printed joker, but its rank matches wild joker rank).
  static bool isWildJoker(Card card, Card? openJoker) {
    if (card.isPrintedJoker) return false;
    if (openJoker == null) return false;
    final wildRank = getEffectiveWildRank(openJoker);
    return wildRank != null && card.rank == wildRank;
  }

  /// Display string for the Open Joker.
  /// If the cut card is a printed joker, clearly indicates that ACE is the wild joker rank.
  static String getOpenJokerDescription(Card? openJoker) {
    if (openJoker == null) return 'None';
    if (openJoker.isPrintedJoker || openJoker.rank == null) {
      return 'ACE (Printed Joker cut — Ace is Wild)';
    }
    final rankStr = const [
      'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
    ][openJoker.rank!.index];
    final suitStr = openJoker.suit != null
        ? const ['♥', '♦', '♣', '♠'][openJoker.suit!.index]
        : '';
    return '$rankStr$suitStr';
  }
}
