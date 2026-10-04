import 'package:game_engine/game_engine.dart';

/// Imperfect-information knowledge state visible to the AI Bot.
/// Strictly contains only information a human player could legitimately observe.
/// NEVER contains opponent hidden cards, future deck cards, or seed information.
class BotKnowledgeState {
  final List<Card> ownHand;
  final Card? openJoker;
  final List<Card> openPile;
  final List<Card> visibleDiscardHistory;
  final int closedDeckRemaining;
  final int turnNumber;
  final List<Card> opponentPicksFromOpen;
  final List<Card> opponentDiscards;
  final int opponentCardCount;
  final int humanScore;
  final int botScore;

  BotKnowledgeState({
    required this.ownHand,
    required this.openJoker,
    required this.openPile,
    required this.visibleDiscardHistory,
    required this.closedDeckRemaining,
    required this.turnNumber,
    this.opponentPicksFromOpen = const [],
    this.opponentDiscards = const [],
    this.opponentCardCount = 13,
    this.humanScore = 0,
    this.botScore = 0,
  });

  Rank? get effectiveWildRank => JokerUtils.getEffectiveWildRank(openJoker);

  Card? get topOfOpenPile => openPile.isNotEmpty ? openPile.last : null;

  /// Counts how many copies of [card] have been seen by this bot.
  /// (in own hand, open pile, visible discard history, or open joker).
  int countSeenCopies(Card card) {
    int count = 0;
    for (final c in ownHand) {
      if (_matchesCard(c, card)) count++;
    }
    for (final c in visibleDiscardHistory) {
      if (_matchesCard(c, card)) count++;
    }
    if (openJoker != null && _matchesCard(openJoker!, card)) {
      count++;
    }
    return count;
  }

  /// Calculates the exact number of copies of [card] remaining in unseen shoe.
  /// Total shoe has 2 decks (2 copies of each standard card, 2 printed jokers).
  int remainingUnseenCopies(Card card) {
    const maxCopies = 2;
    final seen = countSeenCopies(card);
    final remaining = maxCopies - seen;
    return remaining < 0 ? 0 : remaining;
  }

  /// Calculates probability of drawing a copy of [card] from the unseen shoe.
  double probabilityOfDrawing(Card card) {
    if (closedDeckRemaining <= 0) return 0.0;
    final copies = remainingUnseenCopies(card);
    if (copies <= 0) return 0.0;
    return (copies / closedDeckRemaining).clamp(0.0, 1.0);
  }

  /// Returns a copy of the state with updated hand or actions.
  BotKnowledgeState copyWith({
    List<Card>? ownHand,
    Card? openJoker,
    List<Card>? openPile,
    List<Card>? visibleDiscardHistory,
    int? closedDeckRemaining,
    int? turnNumber,
    List<Card>? opponentPicksFromOpen,
    List<Card>? opponentDiscards,
    int? opponentCardCount,
    int? humanScore,
    int? botScore,
  }) {
    return BotKnowledgeState(
      ownHand: ownHand ?? List.from(this.ownHand),
      openJoker: openJoker ?? this.openJoker,
      openPile: openPile ?? List.from(this.openPile),
      visibleDiscardHistory: visibleDiscardHistory ?? List.from(this.visibleDiscardHistory),
      closedDeckRemaining: closedDeckRemaining ?? this.closedDeckRemaining,
      turnNumber: turnNumber ?? this.turnNumber,
      opponentPicksFromOpen: opponentPicksFromOpen ?? List.from(this.opponentPicksFromOpen),
      opponentDiscards: opponentDiscards ?? List.from(this.opponentDiscards),
      opponentCardCount: opponentCardCount ?? this.opponentCardCount,
      humanScore: humanScore ?? this.humanScore,
      botScore: botScore ?? this.botScore,
    );
  }

  static bool _matchesCard(Card a, Card b) {
    if (a.isPrintedJoker && b.isPrintedJoker) return true;
    return a.suit == b.suit && a.rank == b.rank;
  }
}
