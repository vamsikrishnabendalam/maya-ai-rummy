import '../models/card.dart';
import 'sequence_validator.dart';
import 'set_validator.dart';

enum SuggestionCategory {
  found,
  probable,
  possible,
  unlikely,
}

enum SuggestionKind {
  pureSequence,
  impureSequence,
  set,
  potentialSequence,
  potentialSet,
}

class GroupSuggestion {
  final SuggestionCategory category;
  final SuggestionKind kind;
  final List<Card> currentCards;
  final List<Card> neededCards;
  final double probabilityPercentage;
  final String title;
  final String description;

  const GroupSuggestion({
    required this.category,
    required this.kind,
    required this.currentCards,
    this.neededCards = const [],
    this.probabilityPercentage = 0.0,
    required this.title,
    required this.description,
  });
}

/// Fair, non-cheating probability and hand grouping suggestion engine.
class ProbabilityEngine {
  /// Analyzes the player's hand and identifies Found groups and Probable/Possible combinations.
  static List<GroupSuggestion> analyzeHand({
    required List<Card> playerHand,
    required List<Card> openPile,
    required Card? openJoker,
    required int closedDeckCount,
  }) {
    final suggestions = <GroupSuggestion>[];

    // Build knowledge base of all known cards to the player
    final knownCardCounts = <int, int>{};
    void record(Card c) {
      final key = c.toInt();
      knownCardCounts[key] = (knownCardCounts[key] ?? 0) + 1;
    }

    for (final c in playerHand) {
      record(c);
    }
    for (final c in openPile) {
      record(c);
    }
    if (openJoker != null) {
      record(openJoker);
    }

    // 2-deck shoe has 108 cards total (52*2 + 4 jokers). Unseen cards count:
    const totalShoeCards = 108;
    final totalKnown = playerHand.length + openPile.length + (openJoker != null ? 1 : 0);
    final totalUnseen = (totalShoeCards - totalKnown).clamp(1, totalShoeCards);

    // Helper: calculate probability of drawing at least one card from a list of targets
    double calculateProbability(List<Card> targets) {
      int remainingCopies = 0;
      for (final t in targets) {
        final seen = knownCardCounts[t.toInt()] ?? 0;
        final maxCopies = t.isPrintedJoker ? 2 : 2;
        final left = (maxCopies - seen).clamp(0, maxCopies);
        remainingCopies += left;
      }
      if (remainingCopies <= 0) return 0.0;
      final prob = (remainingCopies / totalUnseen) * 100.0;
      return double.parse(prob.toStringAsFixed(1)).clamp(0.0, 99.0);
    }

    // 1. Identify existing 3+ card valid groups (FOUND)
    // Check 3-5 card sequences
    final usedInFound = <Card>{};

    for (final suit in Suit.values) {
      final suitCards = playerHand.where((c) => c.suit == suit && !c.isPrintedJoker).toList()
        ..sort((a, b) => SequenceValidator.rankToLowValue(a.rank!).compareTo(SequenceValidator.rankToLowValue(b.rank!)));

      // Search sequences of length 3, 4, 5
      for (int len = 3; len <= 5; len++) {
        if (suitCards.length < len) continue;
        for (int i = 0; i <= suitCards.length - len; i++) {
          final sub = suitCards.sublist(i, i + len);
          final res = SequenceValidator.validate(sub, openJoker);
          if (res.isValid) {
            suggestions.add(GroupSuggestion(
              category: SuggestionCategory.found,
              kind: res.type == SequenceType.pure ? SuggestionKind.pureSequence : SuggestionKind.impureSequence,
              currentCards: sub,
              probabilityPercentage: 100.0,
              title: res.type == SequenceType.pure ? 'PURE SEQUENCE' : 'IMPURE SEQUENCE',
              description: '${sub.map((c) => c.toString()).join(' ')} (Valid ${res.type.name})',
            ));
            usedInFound.addAll(sub);
          }
        }
      }
    }

    // Check sets
    for (final rank in Rank.values) {
      final rankCards = playerHand.where((c) => c.rank == rank && !c.isPrintedJoker).toList();
      final uniqueSuits = <Suit>{};
      final setCandidate = <Card>[];
      for (final c in rankCards) {
        if (c.suit != null && !uniqueSuits.contains(c.suit)) {
          uniqueSuits.add(c.suit!);
          setCandidate.add(c);
        }
      }
      if (setCandidate.length >= 3) {
        final res = SetValidator.validate(setCandidate, openJoker);
        if (res.isValid) {
          suggestions.add(GroupSuggestion(
            category: SuggestionCategory.found,
            kind: SuggestionKind.set,
            currentCards: setCandidate,
            probabilityPercentage: 100.0,
            title: 'SET',
            description: '${setCandidate.map((c) => c.toString()).join(' ')} (Valid set)',
          ));
          usedInFound.addAll(setCandidate);
        }
      }
    }

    // 2. Identify candidate 2-card sequences (POSSIBLE / PROBABLE)
    for (final suit in Suit.values) {
      final suitCards = playerHand.where((c) => c.suit == suit && !c.isPrintedJoker).toList()
        ..sort((a, b) => SequenceValidator.rankToLowValue(a.rank!).compareTo(SequenceValidator.rankToLowValue(b.rank!)));

      for (int i = 0; i < suitCards.length; i++) {
        for (int j = i + 1; j < suitCards.length; j++) {
          final c1 = suitCards[i];
          final c2 = suitCards[j];
          final v1 = SequenceValidator.rankToLowValue(c1.rank!);
          final v2 = SequenceValidator.rankToLowValue(c2.rank!);
          final diff = v2 - v1;

          final needed = <Card>[];

          if (diff == 1) {
            // Open-ended straight (e.g. 5♥ 6♥ -> needs 4♥ or 7♥)
            if (v1 > 1) {
              needed.add(Card(suit: suit, rank: SequenceValidator.intToRank(v1 - 1), deckIndex: 0));
            }
            if (v2 < 13) {
              needed.add(Card(suit: suit, rank: SequenceValidator.intToRank(v2 + 1), deckIndex: 0));
            } else if (v2 == 13) {
              // Q-K needs Ace
              needed.add(Card(suit: suit, rank: Rank.ace, deckIndex: 0));
            }
          } else if (diff == 2) {
            // Inside straight (e.g. 5♥ 7♥ -> needs 6♥)
            needed.add(Card(suit: suit, rank: SequenceValidator.intToRank(v1 + 1), deckIndex: 0));
          } else if (c1.rank == Rank.ace && c2.rank == Rank.queen) {
            // Q-A needs King
            needed.add(Card(suit: suit, rank: Rank.king, deckIndex: 0));
          } else if (c1.rank == Rank.ace && c2.rank == Rank.king) {
            // K-A needs Queen
            needed.add(Card(suit: suit, rank: Rank.queen, deckIndex: 0));
          }

          if (needed.isNotEmpty) {
            // Add Open Joker as alternative completion
            if (openJoker != null) {
              needed.add(openJoker);
            }

            final prob = calculateProbability(needed);
            final category = prob >= 18.0
                ? SuggestionCategory.probable
                : prob > 0.0
                    ? SuggestionCategory.possible
                    : SuggestionCategory.unlikely;

            suggestions.add(GroupSuggestion(
              category: category,
              kind: SuggestionKind.potentialSequence,
              currentCards: [c1, c2],
              neededCards: needed,
              probabilityPercentage: prob,
              title: category == SuggestionCategory.probable ? 'PROBABLE SEQUENCE' : 'POSSIBLE SEQUENCE',
              description: '${c1.toString()} ${c2.toString()} → Need ${needed.take(2).map((c) => c.toString()).join(' or ')}',
            ));
          }
        }
      }
    }

    // 3. Identify candidate 2-card sets (POSSIBLE / PROBABLE)
    for (final rank in Rank.values) {
      final rankCards = playerHand.where((c) => c.rank == rank && !c.isPrintedJoker).toList();
      if (rankCards.length == 2 && rankCards[0].suit != rankCards[1].suit) {
        final c1 = rankCards[0];
        final c2 = rankCards[1];
        final neededSuits = Suit.values.where((s) => s != c1.suit && s != c2.suit).toList();
        final needed = neededSuits.map((s) => Card(suit: s, rank: rank, deckIndex: 0)).toList();

        if (openJoker != null) {
          needed.add(openJoker);
        }

        final prob = calculateProbability(needed);
        final category = prob >= 18.0
            ? SuggestionCategory.probable
            : prob > 0.0
                ? SuggestionCategory.possible
                : SuggestionCategory.unlikely;

        suggestions.add(GroupSuggestion(
          category: category,
          kind: SuggestionKind.potentialSet,
          currentCards: [c1, c2],
          neededCards: needed,
          probabilityPercentage: prob,
          title: category == SuggestionCategory.probable ? 'PROBABLE SET' : 'POSSIBLE SET',
          description: '${c1.toString()} ${c2.toString()} → Need ${needed.take(2).map((c) => c.toString()).join(' or ')}',
        ));
      }
    }

    // Sort: Found first, then highest probability
    suggestions.sort((a, b) {
      if (a.category == SuggestionCategory.found && b.category != SuggestionCategory.found) return -1;
      if (b.category == SuggestionCategory.found && a.category != SuggestionCategory.found) return 1;
      return b.probabilityPercentage.compareTo(a.probabilityPercentage);
    });

    return suggestions;
  }
}
