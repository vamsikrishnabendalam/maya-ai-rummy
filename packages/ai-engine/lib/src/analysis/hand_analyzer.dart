import 'package:game_engine/game_engine.dart';

class HandAnalysisResult {
  final List<List<Card>> pureSequences;
  final List<List<Card>> impureSequences;
  final List<List<Card>> sets;
  final List<List<Card>> potentialSequences;
  final List<List<Card>> potentialSets;
  final List<Card> unmatchedCards;
  final int deadwoodPoints;
  final bool canDeclare;
  final double declarationReadiness;
  final double strategicHandValue;
  final Set<Card> cardsInPureSequences;
  final Set<Card> cardsInCompletedMelds;
  final Set<Card> cardsInPotentialMelds;

  const HandAnalysisResult({
    required this.pureSequences,
    required this.impureSequences,
    required this.sets,
    required this.potentialSequences,
    required this.potentialSets,
    required this.unmatchedCards,
    required this.deadwoodPoints,
    required this.canDeclare,
    required this.declarationReadiness,
    required this.strategicHandValue,
    required this.cardsInPureSequences,
    required this.cardsInCompletedMelds,
    required this.cardsInPotentialMelds,
  });

  bool isCardInPureSequence(Card card) => cardsInPureSequences.contains(card);
  bool isCardInCompletedMeld(Card card) => cardsInCompletedMelds.contains(card);
  bool isCardInPotentialMeld(Card card) => cardsInPotentialMelds.contains(card);
}

/// Deep strategic hand analysis engine for Indian 13-Card Rummy.
class HandAnalyzer {
  /// Analyzes a 13-card or 14-card hand against the effective wild joker.
  static HandAnalysisResult analyze(List<Card> hand, Card? openJoker) {
    if (hand.isEmpty) {
      return const HandAnalysisResult(
        pureSequences: [],
        impureSequences: [],
        sets: [],
        potentialSequences: [],
        potentialSets: [],
        unmatchedCards: [],
        deadwoodPoints: 0,
        canDeclare: false,
        declarationReadiness: 0.0,
        strategicHandValue: 0.0,
        cardsInPureSequences: {},
        cardsInCompletedMelds: {},
        cardsInPotentialMelds: {},
      );
    }

    // 1. Partition the hand using the authoritative game engine
    final partition = HandPartitioner.findBestPartition(hand, openJoker);

    final pureSequences = <List<Card>>[];
    final impureSequences = <List<Card>>[];
    final sets = <List<Card>>[];
    final potentialSequences = <List<Card>>[];
    final potentialSets = <List<Card>>[];
    final unmatchedCards = <Card>[];

    final cardsInPure = <Card>{};
    final cardsInMelds = <Card>{};
    final cardsInPotentials = <Card>{};

    for (final g in partition.groups) {
      if (g.isValid) {
        if (g.type == HandGroupType.pureSequence) {
          pureSequences.add(g.cards);
          cardsInPure.addAll(g.cards);
          cardsInMelds.addAll(g.cards);
        } else if (g.type == HandGroupType.impureSequence) {
          impureSequences.add(g.cards);
          cardsInMelds.addAll(g.cards);
        } else if (g.type == HandGroupType.validSet) {
          sets.add(g.cards);
          cardsInMelds.addAll(g.cards);
        }
      } else {
        // Group is invalid — check if it's a 2-card potential sequence or pair
        if (g.cards.length == 2) {
          final c1 = g.cards[0];
          final c2 = g.cards[1];
          if (c1.suit == c2.suit && !c1.isPrintedJoker && !c2.isPrintedJoker) {
            final v1 = SequenceValidator.rankToLowValue(c1.rank!);
            final v2 = SequenceValidator.rankToLowValue(c2.rank!);
            final diff = (v2 - v1).abs();
            if (diff == 1 || diff == 2) {
              potentialSequences.add(g.cards);
              cardsInPotentials.addAll(g.cards);
              continue;
            }
          } else if (c1.rank == c2.rank && !c1.isPrintedJoker && !c2.isPrintedJoker) {
            potentialSets.add(g.cards);
            cardsInPotentials.addAll(g.cards);
            continue;
          }
        }
        unmatchedCards.addAll(g.cards);
      }
    }

    // Deadwood points from the partition
    final deadwoodPoints = partition.isValidDeclaration ? 0 : partition.penaltyScore;
    final canDeclare = partition.isValidDeclaration && hand.length == 13;

    // Declaration readiness calculation:
    // Pure sequence = 40% weight
    // Second sequence = 30% weight
    // Sets / remaining melds = 20% weight
    // Deadwood reduction = 10% weight
    double readiness = 0.0;
    if (pureSequences.isNotEmpty) readiness += 0.40;
    if (pureSequences.length + impureSequences.length >= 2) readiness += 0.30;
    final completedMeldsCount = pureSequences.length + impureSequences.length + sets.length;
    if (completedMeldsCount >= 3) readiness += 0.15;
    if (completedMeldsCount >= 4) readiness += 0.05;
    readiness += ((80 - deadwoodPoints) / 80.0) * 0.10;
    readiness = readiness.clamp(0.0, 1.0);

    // Strategic hand value calculation:
    // High positive points for completed melds, high penalty for deadwood
    double handValue = 0.0;
    handValue += pureSequences.length * 600.0; // Pure sequence is king
    handValue += impureSequences.length * 400.0;
    handValue += sets.length * 350.0;
    handValue += potentialSequences.length * 90.0;
    handValue += potentialSets.length * 60.0;
    handValue -= deadwoodPoints * 4.0; // Minimize deadwood

    if (canDeclare) {
      handValue += 5000.0;
    }

    return HandAnalysisResult(
      pureSequences: pureSequences,
      impureSequences: impureSequences,
      sets: sets,
      potentialSequences: potentialSequences,
      potentialSets: potentialSets,
      unmatchedCards: unmatchedCards,
      deadwoodPoints: deadwoodPoints,
      canDeclare: canDeclare,
      declarationReadiness: readiness,
      strategicHandValue: handValue,
      cardsInPureSequences: cardsInPure,
      cardsInCompletedMelds: cardsInMelds,
      cardsInPotentialMelds: cardsInPotentials,
    );
  }
}
