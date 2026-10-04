import '../models/card.dart';
import 'joker_utils.dart';

enum SequenceType {
  pure,
  impure,
  invalid,
}

class SequenceValidationResult {
  final bool isValid;
  final SequenceType type;
  final List<Card> missingCards;
  final List<Card> jokerCards;
  final String reason;

  const SequenceValidationResult({
    required this.isValid,
    required this.type,
    this.missingCards = const [],
    this.jokerCards = const [],
    this.reason = '',
  });

  const SequenceValidationResult.validPure()
      : isValid = true,
        type = SequenceType.pure,
        missingCards = const [],
        jokerCards = const [],
        reason = 'Valid Pure Sequence';

  const SequenceValidationResult.validImpure({
    this.missingCards = const [],
    this.jokerCards = const [],
  })  : isValid = true,
        type = SequenceType.impure,
        reason = 'Valid Impure Sequence';

  const SequenceValidationResult.invalid(this.reason)
      : isValid = false,
        type = SequenceType.invalid,
        missingCards = const [],
        jokerCards = const [];
}

/// Authoritative Sequence Validator for 13-Card Indian Rummy.
class SequenceValidator {
  /// Checks if a given card is considered a joker (printed or matching open joker rank).
  static bool isJoker(Card card, Card? openJoker) {
    return JokerUtils.isJoker(card, openJoker);
  }

  /// Convert Card Rank to Ace-low integer: Ace=1, Two=2, ..., King=13
  static int rankToLowValue(Rank rank) {
    switch (rank) {
      case Rank.ace:
        return 1;
      case Rank.two:
        return 2;
      case Rank.three:
        return 3;
      case Rank.four:
        return 4;
      case Rank.five:
        return 5;
      case Rank.six:
        return 6;
      case Rank.seven:
        return 7;
      case Rank.eight:
        return 8;
      case Rank.nine:
        return 9;
      case Rank.ten:
        return 10;
      case Rank.jack:
        return 11;
      case Rank.queen:
        return 12;
      case Rank.king:
        return 13;
    }
  }

  /// Convert integer (1..14) back to Rank
  static Rank intToRank(int value) {
    if (value == 1 || value == 14) return Rank.ace;
    return Rank.values[value - 1];
  }

  /// Full validation of a card sequence.
  static SequenceValidationResult validate(List<Card> cards, Card? openJoker) {
    if (cards.length < 3) {
      return const SequenceValidationResult.invalid('A sequence must contain at least 3 cards.');
    }

    // 1. Check for pure sequence first
    if (_isPureSequence(cards, openJoker)) {
      return const SequenceValidationResult.validPure();
    }

    // 2. Check for impure sequence
    return _validateImpureSequence(cards, openJoker);
  }

  /// Pure sequence requires:
  /// - No printed jokers
  /// - All cards same suit
  /// - Natural consecutive ranks (Ace low 1..13 or Ace high 10..14)
  /// - No card substituted as a wildcard.
  static bool _isPureSequence(List<Card> cards, Card? openJoker) {
    if (cards.any((c) => c.isPrintedJoker)) return false;
    final firstSuit = cards.first.suit;
    if (firstSuit == null || cards.any((c) => c.suit != firstSuit)) return false;

    final lowRanks = cards.map((c) => rankToLowValue(c.rank!)).toList()..sort();
    if (_isConsecutive(lowRanks)) return true;

    // Check Ace-high if Ace is present
    if (lowRanks.contains(1)) {
      final highRanks = lowRanks.map((r) => r == 1 ? 14 : r).toList()..sort();
      if (_isConsecutive(highRanks)) return true;
    }

    return false;
  }

  static bool _isConsecutive(List<int> sortedRanks) {
    for (int i = 0; i < sortedRanks.length - 1; i++) {
      if (sortedRanks[i + 1] - sortedRanks[i] != 1) return false;
    }
    return true;
  }

  /// Impure sequence validation:
  /// Allows Jokers (Printed and Open Joker) to substitute for missing cards.
  /// Solves Q-K-A + Joker correctly.
  static SequenceValidationResult _validateImpureSequence(List<Card> cards, Card? openJoker) {
    final jokers = <Card>[];
    final naturals = <Card>[];

    for (final c in cards) {
      if (isJoker(c, openJoker)) {
        jokers.add(c);
      } else {
        naturals.add(c);
      }
    }

    // If all cards are jokers, 3+ jokers can represent an impure sequence
    if (naturals.isEmpty) {
      return SequenceValidationResult.validImpure(jokerCards: jokers);
    }

    // All natural cards must share the same suit
    final suit = naturals.first.suit;
    if (suit == null || naturals.any((c) => c.suit != suit)) {
      return const SequenceValidationResult.invalid('Cards in a sequence must all have the same suit.');
    }

    final n = cards.length;

    // Check both Ace interpretations:
    // Option A: Ace as 1 (Ace-low)
    // Option B: Ace as 14 (Ace-high)
    final hasAce = naturals.any((c) => c.rank == Rank.ace);

    final interpretations = <List<int>>[];
    // Low interpretation (Ace = 1)
    interpretations.add(naturals.map((c) => rankToLowValue(c.rank!)).toList());

    // High interpretation (Ace = 14)
    if (hasAce) {
      interpretations.add(naturals.map((c) {
        final val = rankToLowValue(c.rank!);
        return val == 1 ? 14 : val;
      }).toList());
    } else {
      // Even if natural cards don't have Ace, jokers could complete Ace-high (e.g. Q-K + Joker where Joker = A=14)
      interpretations.add(naturals.map((c) => rankToLowValue(c.rank!)).toList());
    }

    for (final natRanks in interpretations) {
      // Check for duplicate ranks among natural cards
      final rankSet = natRanks.toSet();
      if (rankSet.length != natRanks.length) {
        continue; // Duplicates cannot form a sequence
      }

      // Check all possible valid windows of length n
      // Valid window ranges:
      // 1. Ace-low windows: S in [1 .. 14 - n] where S+n-1 <= 13
      // 2. Ace-high windows: S in [15 - n .. 12] where S+n-1 == 14 (ends at Ace=14)
      for (int s = 1; s <= 15 - n; s++) {
        final end = s + n - 1;
        // Strictly no wraparound: if end == 14, S must be at least 2 and cannot wrap to 2
        // e.g. Q-K-A is s=12, end=14. 10-J-Q-K-A is s=10, end=14.
        if (end > 14) continue;
        if (end == 14 && s < 2) continue; // 1 to 14 is 14 cards, valid; but prevents wrapping

        // Check if all natural cards fall within [s, end]
        final allFit = natRanks.every((r) => r >= s && r <= end);
        if (allFit) {
          // Identify missing ranks that jokers fill
          final windowRanks = List.generate(n, (i) => s + i);
          final missingRanks = windowRanks.where((r) => !natRanks.contains(r)).toList();

          if (missingRanks.length == jokers.length) {
            final missingCards = missingRanks.map((r) {
              return Card(
                suit: suit,
                rank: intToRank(r),
                deckIndex: 0,
              );
            }).toList();

            return SequenceValidationResult.validImpure(
              missingCards: missingCards,
              jokerCards: jokers,
            );
          }
        }
      }
    }

    return const SequenceValidationResult.invalid('Cards cannot form a valid sequence with available jokers.');
  }
}
