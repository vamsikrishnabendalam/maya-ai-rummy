import 'dart:math';
import 'card.dart';

class Deck {
  final List<Card> cards;

  Deck(this.cards);

  static Deck initialize(int numberOfDecks, [int? seed]) {
    List<Card> initialCards = [];
    for (int d = 0; d < numberOfDecks; d++) {
      for (var suit in Suit.values) {
        for (var rank in Rank.values) {
          initialCards.add(Card(suit: suit, rank: rank, deckIndex: d));
        }
      }
      initialCards.add(Card(deckIndex: d, isPrintedJoker: true, jokerIndex: 0));
      initialCards.add(Card(deckIndex: d, isPrintedJoker: true, jokerIndex: 1)); // 2 PJ per deck (54 cards per deck)
    }
    final rng = seed != null ? Random(seed) : Random.secure();
    initialCards.shuffle(rng);
    return Deck(initialCards);
  }

  Card draw() {
    if (cards.isEmpty) throw StateError('Deck is empty');
    return cards.removeLast();
  }

  int get length => cards.length;

  List<int> toIntList() => cards.map((c) => c.toInt()).toList();

  static Deck fromIntList(List<int> ints) => Deck(ints.map(Card.fromInt).toList());
}
