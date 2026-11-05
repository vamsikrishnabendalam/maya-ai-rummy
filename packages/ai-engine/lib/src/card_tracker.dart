import 'package:game_engine/game_engine.dart';
import 'observation.dart';

class CardTracker {
  final Set<Card> seenCards = {};
  final Map<String, int> discardCounts = {};
  final int totalDecks;

  CardTracker({this.totalDecks = 2});

  static String _cardKey(Card card) {
    if (card.isPrintedJoker) return 'PJ';
    return '${card.suit?.name}_${card.rank?.name}';
  }

  void recordVisibleCard(Card card) {
    seenCards.add(card);
    final key = _cardKey(card);
    discardCounts[key] = (discardCounts[key] ?? 0) + 1;
  }

  double probabilityOfDrawing(Card card, AIObservation obs) {
    int totalUnseen = obs.closedDeckRemaining;
    if (totalUnseen <= 0) return 0.0;
    final key = _cardKey(card);
    int copiesSeen = discardCounts[key] ?? 0;
    // In a standard rummy shoe, each standard card has totalDecks copies, printed jokers have totalDecks * 2
    int maxCopies = card.isPrintedJoker ? (totalDecks * 2) : totalDecks;
    int remainingInDeck = maxCopies - copiesSeen;
    if (remainingInDeck <= 0) return 0.0;
    return remainingInDeck / totalUnseen;
  }
}
