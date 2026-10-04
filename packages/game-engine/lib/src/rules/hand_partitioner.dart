import '../models/card.dart';
import 'sequence_validator.dart';
import 'set_validator.dart';
import 'scoring.dart';

enum HandGroupType {
  pureSequence,
  impureSequence,
  validSet,
  invalid,
}

class GroupDiagnosis {
  final List<Card> cards;
  final HandGroupType type;
  final bool isValid;
  final String label;
  final String details;

  const GroupDiagnosis({
    required this.cards,
    required this.type,
    required this.isValid,
    required this.label,
    required this.details,
  });
}

class HandPartitionResult {
  final bool isValidDeclaration;
  final int penaltyScore;
  final String errorMessage;
  final int pureSequenceCount;
  final int totalSequenceCount;
  final List<GroupDiagnosis> groups;
  final List<Card> unmatchedCards;

  const HandPartitionResult({
    required this.isValidDeclaration,
    required this.penaltyScore,
    required this.errorMessage,
    required this.pureSequenceCount,
    required this.totalSequenceCount,
    required this.groups,
    required this.unmatchedCards,
  });
}

/// Discovers valid combinations, partitions hands, and diagnoses declarations.
class HandPartitioner {
  /// Evaluates an explicit set of groups (as organized by player).
  static HandPartitionResult evaluateGroups(List<List<Card>> groups, Card? openJoker) {
    int totalCards = 0;
    int pureSeqCount = 0;
    int totalSeqCount = 0;
    final diagnoses = <GroupDiagnosis>[];
    final unmatched = <Card>[];

    for (final group in groups) {
      totalCards += group.length;
      if (group.isEmpty) continue;

      if (group.length < 3) {
        diagnoses.add(GroupDiagnosis(
          cards: group,
          type: HandGroupType.invalid,
          isValid: false,
          label: 'UNRESOLVED',
          details: 'Needs at least 3 cards to form a sequence or set.',
        ));
        unmatched.addAll(group);
        continue;
      }

      // Check sequence
      final seqRes = SequenceValidator.validate(group, openJoker);
      if (seqRes.isValid) {
        if (seqRes.type == SequenceType.pure) {
          pureSeqCount++;
          totalSeqCount++;
          diagnoses.add(GroupDiagnosis(
            cards: group,
            type: HandGroupType.pureSequence,
            isValid: true,
            label: 'PURE SEQUENCE',
            details: 'Valid pure sequence (${group.first.suit?.name ?? ''})',
          ));
        } else {
          totalSeqCount++;
          final missingDesc = seqRes.missingCards.map((c) => c.toString()).join(', ');
          diagnoses.add(GroupDiagnosis(
            cards: group,
            type: HandGroupType.impureSequence,
            isValid: true,
            label: 'IMPURE SEQUENCE',
            details: 'Valid impure sequence (Joker substitutes: $missingDesc)',
          ));
        }
        continue;
      }

      // Check set
      final setRes = SetValidator.validate(group, openJoker);
      if (setRes.isValid) {
        diagnoses.add(GroupDiagnosis(
          cards: group,
          type: HandGroupType.validSet,
          isValid: true,
          label: 'SET',
          details: 'Valid set of ${setRes.targetRank?.name ?? 'cards'}',
        ));
        continue;
      }

      // Neither sequence nor set
      diagnoses.add(GroupDiagnosis(
        cards: group,
        type: HandGroupType.invalid,
        isValid: false,
        label: 'INVALID GROUP',
        details: seqRes.reason.isNotEmpty ? seqRes.reason : setRes.reason,
      ));
      unmatched.addAll(group);
    }

    String error = '';
    bool isValid = true;
    int penalty = 0;

    if (totalCards != 13) {
      isValid = false;
      error = 'Hand must have exactly 13 cards (currently has $totalCards).';
    } else if (unmatched.isNotEmpty) {
      isValid = false;
      error = '${unmatched.length} card(s) are not part of any valid group.';
    } else if (pureSeqCount < 1) {
      isValid = false;
      error = 'Invalid Declaration: You need at least one pure sequence (no jokers).';
    } else if (totalSeqCount < 2) {
      isValid = false;
      error = 'Invalid Declaration: At least two sequences are required (one must be pure).';
    }

    if (!isValid) {
      // Calculate penalty using authoritative Scoring.calculateHandDeadwood
      penalty = Scoring.calculateHandDeadwood(
        groups: groups,
        wildJoker: openJoker,
      );
    }

    return HandPartitionResult(
      isValidDeclaration: isValid,
      penaltyScore: penalty,
      errorMessage: error,
      pureSequenceCount: pureSeqCount,
      totalSequenceCount: totalSeqCount,
      groups: diagnoses,
      unmatchedCards: unmatched,
    );
  }

  /// Searches the entire 13-card hand for ANY valid partition satisfying declaration rules.
  /// If the player's visual groups are invalid, this checks if the hand itself is valid.
  static HandPartitionResult findValidPartition(List<Card> hand, Card? openJoker) {
    if (hand.length != 13) {
      return evaluateGroups([hand], openJoker);
    }

    // 1. Generate candidate valid pure sequences (length 3, 4, 5) capped and deduped
    final rawPure = _findCandidateSequences(hand, openJoker, pureOnly: true);
    final pureSequences = rawPure.length > 15 ? rawPure.sublist(0, 15) : rawPure;

    // If there is no pure sequence candidate in the entire hand, it cannot be a valid declaration
    if (pureSequences.isEmpty) {
      return evaluateGroups([hand], openJoker);
    }

    // 2. Generate candidate impure sequences (length 3, 4, 5) capped and deduped
    final rawImpure = _findCandidateSequences(hand, openJoker, impureOnly: true);
    final impureSequences = rawImpure.length > 20 ? rawImpure.sublist(0, 20) : rawImpure;

    int searchSteps = 0;
    const int maxSearchSteps = 150;

    // Check combinations: Pure Sequence 1 + Sequence 2 + remaining valid groups
    for (final seq1 in pureSequences) {
      final rem1 = _removeSublist(hand, seq1);
      if (rem1 == null) continue;

      // Second sequence can be pure or impure
      final allSecondSequences = <List<Card>>[
        ...pureSequences.where((s) => _isDisjoint(seq1, s)),
        ...impureSequences.where((s) => _isDisjoint(seq1, s)),
      ];

      for (final seq2 in allSecondSequences) {
        if (++searchSteps > maxSearchSteps) break;
        final rem2 = _removeSublist(rem1, seq2);
        if (rem2 == null) continue;

        // rem2 now has 13 - seq1.length - seq2.length cards (typically 7 or 6 cards)
        final restPartition = _partitionRemainingCards(rem2, openJoker);
        if (restPartition != null) {
          final allGroups = <List<Card>>[seq1, seq2, ...restPartition];
          return evaluateGroups(allGroups, openJoker);
        }
      }
      if (searchSteps > maxSearchSteps) break;
    }

    // No valid declaration partition found
    return evaluateGroups([hand], openJoker);
  }

  /// Partitions the hand into optimal valid groups (pure sequences, impure sequences, sets)
  /// that achieve the MINIMUM possible deadwood points according to official Rummy rules.
  /// Appropriately rearranges Jokers into high-value sequences/sets to eliminate maximum count.
  /// Guarantees that EVERY card in hand appears EXACTLY once across all groups.
  static HandPartitionResult findBestPartition(List<Card> hand, Card? openJoker) {
    if (hand.isEmpty) {
      return evaluateGroups([], openJoker);
    }

    // 1. Check if a full valid declaration partition already exists
    if (hand.length == 13) {
      final validDecl = findValidPartition(hand, openJoker);
      if (validDecl.isValidDeclaration) {
        return validDecl;
      }
    }

    // 2. Generate all candidate valid melds:
    final pureCandidates = _findCandidateSequences(hand, openJoker, pureOnly: true);
    final impureCandidates = _findCandidateSequences(hand, openJoker, impureOnly: true);
    final setCandidates = _findCandidateSets(hand, openJoker);

    int meldPointValue(List<Card> meld) {
      int val = meld.length * 10;
      for (final c in meld) {
        val += Scoring.getCardValue(c, openJoker);
      }
      return val;
    }

    // Sort candidates so combinations saving higher card values and lengths are evaluated first
    pureCandidates.sort((a, b) => meldPointValue(b).compareTo(meldPointValue(a)));
    impureCandidates.sort((a, b) => meldPointValue(b).compareTo(meldPointValue(a)));
    setCandidates.sort((a, b) => meldPointValue(b).compareTo(meldPointValue(a)));

    final seenCandidateKeys = <String>{};
    final uniqueCandidates = <List<Card>>[];
    for (final c in [...pureCandidates, ...impureCandidates, ...setCandidates]) {
      final key = (c.map((card) => card.cardId).toList()..sort()).join('_');
      if (!seenCandidateKeys.contains(key)) {
        seenCandidateKeys.add(key);
        uniqueCandidates.add(c);
      }
    }
    // Cap to top 50 highest-value candidates to prevent combinatorial explosion while retaining sets
    final allCandidates = uniqueCandidates.length > 50 ? uniqueCandidates.sublist(0, 50) : uniqueCandidates;

    List<List<Card>> bestMelds = [];
    int lowestDeadwood = 999;
    int bestPureCount = 0;
    int bestTotalSeqCount = 0;
    int maxMeldedCards = 0;
    int exploreIterations = 0;
    const int maxExploreIterations = 400;

    void explore(int startIndex, List<List<Card>> currentMelds, List<Card> remaining) {
      if (exploreIterations++ >= maxExploreIterations) return;
      final testGroups = <List<Card>>[...currentMelds];
      if (remaining.isNotEmpty) {
        testGroups.add(remaining);
      }
      final deadwood = Scoring.calculateHandDeadwood(groups: testGroups, wildJoker: openJoker);
      final meldedCount = hand.length - remaining.length;

      int currentPureCount = 0;
      int currentTotalSeqCount = 0;
      for (final m in currentMelds) {
        final seq = SequenceValidator.validate(m, openJoker);
        if (seq.isValid) {
          currentTotalSeqCount++;
          if (seq.type == SequenceType.pure) {
            currentPureCount++;
          }
        }
      }

      bool isBetter = false;
      if (deadwood < lowestDeadwood) {
        isBetter = true;
      } else if (deadwood == lowestDeadwood) {
        if (currentPureCount > bestPureCount) {
          isBetter = true;
        } else if (currentPureCount == bestPureCount) {
          if (currentTotalSeqCount > bestTotalSeqCount) {
            isBetter = true;
          } else if (currentTotalSeqCount == bestTotalSeqCount) {
            if (meldedCount > maxMeldedCards) {
              isBetter = true;
            }
          }
        }
      }

      if (isBetter) {
        lowestDeadwood = deadwood;
        bestPureCount = currentPureCount;
        bestTotalSeqCount = currentTotalSeqCount;
        maxMeldedCards = meldedCount;
        bestMelds = List.from(currentMelds);
      }

      if (lowestDeadwood == 0) return;
      if (currentMelds.length >= 4) return;

      for (int i = startIndex; i < allCandidates.length; i++) {
        final meld = allCandidates[i];
        final rem = _removeSublist(remaining, meld);
        if (rem != null) {
          currentMelds.add(meld);
          explore(i + 1, currentMelds, rem);
          currentMelds.removeLast();
        }
      }
    }

    explore(0, [], hand);

    // Remaining unmelded cards
    final remainingCards = List<Card>.from(hand);
    for (final meld in bestMelds) {
      for (final c in meld) {
        remainingCards.remove(c);
      }
    }

    // From remaining cards, extract 2-card potential sequences and 2-card pairs for clean visualization
    final twoCardSeqs = _findCandidateTwoCardSequences(remainingCards, openJoker);
    final visualTwoCards = <List<Card>>[];
    for (final seq in twoCardSeqs) {
      final rem = _removeSublist(remainingCards, seq);
      if (rem != null) {
        visualTwoCards.add(seq);
        remainingCards.clear();
        remainingCards.addAll(rem);
      }
    }

    final twoCardSets = _findCandidateTwoCardSets(remainingCards, openJoker);
    for (final s in twoCardSets) {
      final rem = _removeSublist(remainingCards, s);
      if (rem != null) {
        visualTwoCards.add(s);
        remainingCards.clear();
        remainingCards.addAll(rem);
      }
    }

    final finalGroups = <List<Card>>[
      ...bestMelds,
      ...visualTwoCards,
    ];
    if (remainingCards.isNotEmpty) {
      finalGroups.add(remainingCards);
    }

    return evaluateGroups(finalGroups, openJoker);
  }

  static List<List<Card>> _findCandidateTwoCardSequences(List<Card> cards, Card? openJoker) {
    final pairs = <List<Card>>[];
    for (final suit in Suit.values) {
      final suitCards = cards.where((c) => c.suit == suit && !c.isPrintedJoker).toList()
        ..sort((a, b) => SequenceValidator.rankToLowValue(a.rank!).compareTo(SequenceValidator.rankToLowValue(b.rank!)));
      for (int i = 0; i < suitCards.length - 1; i++) {
        final c1 = suitCards[i];
        final c2 = suitCards[i + 1];
        final v1 = SequenceValidator.rankToLowValue(c1.rank!);
        final v2 = SequenceValidator.rankToLowValue(c2.rank!);
        final diff = (v2 - v1).abs();
        if (diff == 1 || diff == 2) {
          pairs.add([c1, c2]);
        }
      }
    }
    return pairs;
  }

  static List<List<Card>> _findCandidateTwoCardSets(List<Card> cards, Card? openJoker) {
    final pairs = <List<Card>>[];
    for (final rank in Rank.values) {
      final rankCards = cards.where((c) => c.rank == rank && !c.isPrintedJoker).toList();
      final uniqueSuits = <Suit>{};
      final pair = <Card>[];
      for (final c in rankCards) {
        if (c.suit != null && !uniqueSuits.contains(c.suit)) {
          uniqueSuits.add(c.suit!);
          pair.add(c);
        }
      }
      if (pair.length >= 2) {
        pairs.add(pair.sublist(0, 2));
      }
    }
    return pairs;
  }

  /// Attempts to partition remaining cards into valid sequences or sets
  static List<List<Card>>? _partitionRemainingCards(List<Card> cards, Card? openJoker, {int depth = 0}) {
    if (cards.isEmpty) return [];
    if (cards.length < 3 || depth > 2) return null;

    final seqs = _findCandidateSequences(cards, openJoker);
    final sets = _findCandidateSets(cards, openJoker);
    final rawCandidates = <List<Card>>[...seqs, ...sets];

    // Deduplicate candidate groups by card IDs and sort by length descending to prefer larger melds
    final seen = <String>{};
    final candidateGroups = <List<Card>>[];
    for (final g in rawCandidates) {
      final key = (g.map((c) => c.cardId).toList()..sort()).join('_');
      if (seen.add(key)) {
        candidateGroups.add(g);
        if (candidateGroups.length >= 50) break;
      }
    }
    candidateGroups.sort((a, b) => b.length.compareTo(a.length));

    for (final g in candidateGroups) {
      final rem = _removeSublist(cards, g);
      if (rem != null) {
        if (rem.isEmpty) return [g];
        final sub = _partitionRemainingCards(rem, openJoker, depth: depth + 1);
        if (sub != null) {
          return [g, ...sub];
        }
      }
    }

    return null;
  }

  static List<List<Card>> _findCandidateSequences(
    List<Card> cards,
    Card? openJoker, {
    bool pureOnly = false,
    bool impureOnly = false,
  }) {
    final candidates = <List<Card>>[];
    final seen = <String>{};
    // Generate combinations of 5, 4, 3 cards of matching suit / jokers (longer first)
    for (int len = 5; len >= 3; len--) {
      if (len > cards.length) continue;
      _generateCombinations(cards, len, 0, [], (combo) {
        if (candidates.length >= 35) return;
        final key = (combo.map((c) => c.cardId).toList()..sort()).join('_');
        if (seen.contains(key)) return;
        final res = SequenceValidator.validate(combo, openJoker);
        if (res.isValid) {
          if (pureOnly && res.type != SequenceType.pure) return;
          if (impureOnly && res.type != SequenceType.impure) return;
          seen.add(key);
          candidates.add(combo);
        }
      });
    }
    return candidates;
  }

  static List<List<Card>> _findCandidateSets(List<Card> cards, Card? openJoker) {
    final candidates = <List<Card>>[];
    final seen = <String>{};
    for (int len = 5; len >= 3; len--) {
      if (len > cards.length) continue;
      _generateCombinations(cards, len, 0, [], (combo) {
        if (candidates.length >= 40) return;
        final key = (combo.map((c) => c.cardId).toList()..sort()).join('_');
        if (seen.contains(key)) return;
        final res = SetValidator.validate(combo, openJoker);
        if (res.isValid) {
          seen.add(key);
          candidates.add(combo);
        }
      });
    }
    return candidates;
  }

  static void _generateCombinations(
    List<Card> pool,
    int k,
    int start,
    List<Card> current,
    void Function(List<Card>) onCombination,
  ) {
    if (current.length == k) {
      onCombination(List.from(current));
      return;
    }
    for (int i = start; i < pool.length; i++) {
      current.add(pool[i]);
      _generateCombinations(pool, k, i + 1, current, onCombination);
      current.removeLast();
    }
  }

  static List<Card>? _removeSublist(List<Card> source, List<Card> toRemove) {
    final copy = List<Card>.from(source);
    for (final c in toRemove) {
      if (!copy.remove(c)) return null;
    }
    return copy;
  }

  static bool _isDisjoint(List<Card> a, List<Card> b) {
    for (final c in a) {
      if (b.contains(c)) return false;
    }
    return true;
  }
}
