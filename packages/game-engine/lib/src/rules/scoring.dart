import '../models/card.dart';
import 'joker_utils.dart';
import 'sequence_validator.dart';
import 'set_validator.dart';

class Scoring {
  static int getCardValue(Card c, Card? wildJoker) {
    if (JokerUtils.isJoker(c, wildJoker)) return 0;
    if (c.rank == Rank.ace || c.rank == Rank.king || c.rank == Rank.queen || c.rank == Rank.jack) return 10;
    return (c.rank?.index ?? 0) + 1;
  }

  static int calculateDeadwood(List<Card> deadwood, Card? wildJoker, {int maxPenalty = 80}) {
    int score = 0;
    for (var c in deadwood) {
      score += getCardValue(c, wildJoker);
    }
    return score > maxPenalty ? maxPenalty : score;
  }

  /// Evaluates groups and calculates authentic Indian Rummy deadwood score:
  /// - Full valid declaration (>= 2 sequences, >= 1 pure, all 13 cards valid): 0 points.
  /// - No pure sequence: all cards count as deadwood, capped at [maxPenalty].
  /// - 1 pure sequence, < 2 total sequences: pure sequence is exempt (0 pts), all other cards count as deadwood, capped at [maxPenalty].
  /// - >= 2 sequences (at least 1 pure): all valid sequences and valid sets are exempt (0 pts). Only cards in invalid/unmatched groups count as deadwood, capped at [maxPenalty].
  static int calculateHandDeadwood({
    required List<List<Card>> groups,
    required Card? wildJoker,
    int maxPenalty = 80,
  }) {
    if (groups.isEmpty) return 0;

    int pureSeqCount = 0;
    int totalSeqCount = 0;
    final validGroupFlags = List<bool>.filled(groups.length, false);
    final isPureSeqFlags = List<bool>.filled(groups.length, false);

    for (int i = 0; i < groups.length; i++) {
      final grp = groups[i];
      if (grp.length < 3) continue;

      final seqRes = SequenceValidator.validate(grp, wildJoker);
      if (seqRes.isValid) {
        validGroupFlags[i] = true;
        totalSeqCount++;
        if (seqRes.type == SequenceType.pure) {
          pureSeqCount++;
          isPureSeqFlags[i] = true;
        }
        continue;
      }

      final setRes = SetValidator.validate(grp, wildJoker);
      if (setRes.isValid) {
        validGroupFlags[i] = true;
        continue;
      }
    }

    final allCardsCount = groups.fold<int>(0, (sum, g) => sum + g.length);
    final allGroupsValid = !validGroupFlags.contains(false);

    // If all cards form valid groups and minimum declaration requirements met:
    if (allCardsCount == 13 && allGroupsValid && pureSeqCount >= 1 && totalSeqCount >= 2) {
      return 0;
    }

    // 1. If no pure sequence:
    // ALL cards count towards deadwood (even if some form sets or impure sequences)!
    if (pureSeqCount == 0) {
      int deadwood = 0;
      for (final grp in groups) {
        for (final card in grp) {
          deadwood += getCardValue(card, wildJoker);
        }
      }
      return deadwood > maxPenalty ? maxPenalty : deadwood;
    }

    // 2. If at least 1 pure sequence, but less than 2 total sequences:
    // The pure sequence is exempt. ALL other cards count towards deadwood.
    if (totalSeqCount < 2) {
      int deadwood = 0;
      bool exemptedFirstPure = false;
      for (int i = 0; i < groups.length; i++) {
        if (isPureSeqFlags[i] && !exemptedFirstPure) {
          exemptedFirstPure = true; // exempt this pure sequence
          continue;
        }
        for (final card in groups[i]) {
          deadwood += getCardValue(card, wildJoker);
        }
      }
      return deadwood > maxPenalty ? maxPenalty : deadwood;
    }

    // 3. At least 2 sequences (at least 1 pure):
    // All valid sequences and sets are exempt.
    // Only invalid groups count towards deadwood.
    int deadwood = 0;
    for (int i = 0; i < groups.length; i++) {
      if (validGroupFlags[i]) continue; // Exempt!
      for (final card in groups[i]) {
        deadwood += getCardValue(card, wildJoker);
      }
    }
    return deadwood > maxPenalty ? maxPenalty : deadwood;
  }
}
