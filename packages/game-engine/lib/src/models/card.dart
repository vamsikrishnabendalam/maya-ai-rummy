enum Suit { hearts, diamonds, clubs, spades }
enum Rank { ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king }

class Card {
  final Suit? suit;
  final Rank? rank;
  final int deckIndex; // 0 or 1
  final bool isPrintedJoker;

  const Card({
    this.suit,
    this.rank,
    required this.deckIndex,
    this.isPrintedJoker = false,
  });

  int toInt() {
    if (isPrintedJoker) return (deckIndex * 53) + 52;
    return (deckIndex * 53) + (suit!.index * 13) + rank!.index;
  }

  String get cardId {
    if (isPrintedJoker) return 'PJ-D$deckIndex-${toInt()}';
    const rankShort = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suitShort = ['H', 'D', 'C', 'S'];
    return '${rankShort[rank!.index]}${suitShort[suit!.index]}-D$deckIndex-${toInt()}';
  }

  String get label => toString();
  bool get isJoker => isPrintedJoker;

  static Card fromInt(int val) {
    int deckIndex = val >= 53 ? 1 : 0;
    int remainder = val % 53;
    if (remainder == 52) {
      return Card(deckIndex: deckIndex, isPrintedJoker: true);
    }
    return Card(
      suit: Suit.values[(remainder / 13).floor()],
      rank: Rank.values[remainder % 13],
      deckIndex: deckIndex,
    );
  }

  Map<String, dynamic> toJson() => {'val': toInt()};

  factory Card.fromJson(Map<String, dynamic> json) => Card.fromInt(json['val']);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Card &&
        other.suit == suit &&
        other.rank == rank &&
        other.deckIndex == deckIndex &&
        other.isPrintedJoker == isPrintedJoker;
  }

  @override
  int get hashCode => toInt().hashCode;

  @override
  String toString() {
    if (isPrintedJoker) return 'PJ($deckIndex)';
    String suitStr = const ['♥', '♦', '♣', '♠'][suit!.index];
    String rankStr = const ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'][rank!.index];
    return '$rankStr$suitStr';
  }
}
