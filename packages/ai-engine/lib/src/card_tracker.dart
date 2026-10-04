import 'package:game_engine/game_engine.dart';
import 'observation.dart';

class CardTracker {
  final Set<Card> seenCards = {};
  final Map<Card, int> discardCounts = {};
  final int totalDecks = 2;

  void recordVisibleCard(Card card) {
    seenCards.add(card);
    discardCounts[card] = (discardCounts[card] ?? 0) + 1;
  }

  double probabilityOfDrawing(Card card, AIObservation obs) {
    int totalUnseen = obs.closedDeckRemaining;
    if (totalUnseen <= 0) return 0.0;
    int copiesSeen = discardCounts[card] ?? 0;
    int maxCopies = card.isPrintedJoker ? 2 : 2;
    int remainingInDeck = maxCopies - copiesSeen;
    if (remainingInDeck <= 0) return 0.0;
    return remainingInDeck / totalUnseen;
  }
}
