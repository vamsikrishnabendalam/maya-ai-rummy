import 'package:game_engine/game_engine.dart';

enum GroupType { pureSequence, impureSequence, set }

class CardGroup {
  final List<Card> cards;
  final GroupType type;
  CardGroup(this.cards, this.type);
}

class HandScore {
  final int deadwoodPoints;
  final List<CardGroup> groups;
  final List<Card> ungrouped;
  final bool canDeclare;
  
  double completionPercentage;
  List<Card> neededCards;
  List<Card> disposableCards;

  HandScore({
    required this.deadwoodPoints,
    required this.groups,
    required this.ungrouped,
    required this.canDeclare,
    this.completionPercentage = 0.0,
    this.neededCards = const [],
    this.disposableCards = const [],
  });

  factory HandScore.worstPossible(List<Card> hand, Card wildJoker) {
    int totalPoints = Scoring.calculateDeadwood(hand, wildJoker);
    return HandScore(
      deadwoodPoints: totalPoints,
      groups: [],
      ungrouped: hand,
      canDeclare: false,
      disposableCards: List.from(hand),
    );
  }
}

class HandEvaluator {
  HandScore evaluate(List<Card> hand, Card wildJoker) {
    final partition = HandPartitioner.findValidPartition(hand, wildJoker);
    
    final groups = <CardGroup>[];
    for (final g in partition.groups) {
      if (g.isValid) {
        GroupType type = GroupType.set;
        if (g.type == HandGroupType.pureSequence) {
          type = GroupType.pureSequence;
        } else if (g.type == HandGroupType.impureSequence) {
          type = GroupType.impureSequence;
        }
        groups.add(CardGroup(g.cards, type));
      }
    }

    final deadwood = partition.unmatchedCards;
    final deadwoodPoints = partition.isValidDeclaration
        ? 0
        : Scoring.calculateDeadwood(deadwood, wildJoker);

    return HandScore(
      deadwoodPoints: deadwoodPoints,
      groups: groups,
      ungrouped: deadwood,
      canDeclare: partition.isValidDeclaration,
      completionPercentage: (1.0 - (deadwoodPoints / 80.0)).clamp(0.0, 1.0),
      disposableCards: deadwood.isNotEmpty ? List.from(deadwood) : List.from(hand),
    );
  }
}
