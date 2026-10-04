import '../models/card.dart';
import 'sequence_validator.dart';

class SetValidationResult {
  final bool isValid;
  final bool isImpure;
  final Rank? targetRank;
  final List<Suit> missingSuits;
  final List<Card> jokerCards;
  final String reason;

  const SetValidationResult({
    required this.isValid,
    this.isImpure = false,
    this.targetRank,
    this.missingSuits = const [],
    this.jokerCards = const [],
    this.reason = '',
  });

  const SetValidationResult.validPure({required this.targetRank})
      : isValid = true,
        isImpure = false,
        missingSuits = const [],
        jokerCards = const [],
        reason = 'Valid Natural Set';

  const SetValidationResult.validImpure({
    required this.targetRank,
    this.missingSuits = const [],
    this.jokerCards = const [],
  })  : isValid = true,
        isImpure = true,
        reason = 'Valid Set with Joker';

  const SetValidationResult.invalid(this.reason)
      : isValid = false,
        isImpure = false,
        targetRank = null,
        missingSuits = const [],
        jokerCards = const [];
}

/// Authoritative Set Validator for 13-Card Indian Rummy.
class SetValidator {
  static SetValidationResult validate(List<Card> cards, Card? openJoker) {
    if (cards.length < 3) {
      return const SetValidationResult.invalid('A set must have at least 3 cards.');
    }
    if (cards.length > 5) {
      return const SetValidationResult.invalid('A set cannot contain more than 5 cards.');
    }

    final naturals = <Card>[];
    final jokers = <Card>[];

    for (final c in cards) {
      if (SequenceValidator.isJoker(c, openJoker)) {
        jokers.add(c);
      } else {
        naturals.add(c);
      }
    }

    if (naturals.isEmpty) {
      // 3, 4, or 5 jokers can form a set
      return SetValidationResult.validImpure(
        targetRank: null,
        jokerCards: jokers,
      );
    }

    // All natural cards must have the exact same rank
    final targetRank = naturals.first.rank;
    if (naturals.any((c) => c.rank != targetRank)) {
      return const SetValidationResult.invalid('All natural cards in a set must have the same rank.');
    }

    if (jokers.isEmpty) {
      // Natural pure set without jokers: max 4 cards (one per suit)
      if (cards.length > 4) {
        return const SetValidationResult.invalid('A natural set cannot contain more than 4 cards.');
      }
      final suits = <Suit>{};
      for (final c in naturals) {
        if (c.suit == null || suits.contains(c.suit)) {
          return const SetValidationResult.invalid('A natural set cannot contain duplicate cards of the same suit.');
        }
        suits.add(c.suit!);
      }
      return SetValidationResult.validPure(targetRank: targetRank);
    } else {
      // Impure set with jokers: can have 3, 4, or 5 cards
      final suits = <Suit>{};
      for (final c in naturals) {
        if (c.suit == null || suits.contains(c.suit)) {
          return const SetValidationResult.invalid('A set cannot contain duplicate cards of the same suit.');
        }
        suits.add(c.suit!);
      }
      final availableSuits = Suit.values.where((s) => !suits.contains(s)).toList();
      final missing = availableSuits.take(jokers.length).toList();
      return SetValidationResult.validImpure(
        targetRank: targetRank,
        missingSuits: missing,
        jokerCards: jokers,
      );
    }
  }
}
