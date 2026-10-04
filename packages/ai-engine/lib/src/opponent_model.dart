import 'package:game_engine/game_engine.dart';

class OpponentModel {
  final String opponentId;
  final List<Card> pickedCards = [];
  final List<Card> discardedCards = [];
  
  OpponentModel(this.opponentId);

  void recordOpponentPick(Card card) {
    pickedCards.add(card);
  }

  void recordOpponentDiscard(Card card) {
    discardedCards.add(card);
  }

  double getDiscardDangerRating(Card card) {
    if (pickedCards.isEmpty || card.rank == null || card.suit == null) return 0.1;
    for (var picked in pickedCards) {
      if (picked.suit == card.suit && picked.rank != null) {
        if ((picked.rank!.index - card.rank!.index).abs() <= 2) {
          return 0.8;
        }
      }
    }
    return 0.2;
  }
}
