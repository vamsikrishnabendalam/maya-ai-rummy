import 'package:game_engine/game_engine.dart' show Card, Rank;

/// Types of card groupings in Indian Rummy
enum CardGroupType {
  /// A pure sequence (3+ consecutive cards of the same suit, no jokers)
  pureSequence,

  /// An impure sequence (3+ consecutive cards of the same suit, uses joker(s))
  impureSequence,

  /// A set (3-4 cards of the same rank, different suits)
  set,

  /// Ungrouped/deadwood cards
  deadwood,
}

/// Represents a group of cards organized by the player.
class CardGroup {
  /// Unique identifier for this group
  final String id;

  /// The type of grouping
  final CardGroupType type;

  /// Cards in this group, ordered by position
  final List<Card> cards;

  /// Whether this group forms a valid meld according to Rummy rules
  final bool isValid;

  /// Optional override for the group label (e.g. 'DRAWN')
  final String? customLabel;

  const CardGroup({
    required this.id,
    required this.type,
    required this.cards,
    this.isValid = false,
    this.customLabel,
  });

  /// Display label for the group type
  String get label {
    if (customLabel != null && customLabel!.isNotEmpty) {
      return customLabel!;
    }
    switch (type) {
      case CardGroupType.pureSequence:
        return 'PURE SEQ';
      case CardGroupType.impureSequence:
        return 'IMPURE SEQ';
      case CardGroupType.set:
        return 'SET';
      case CardGroupType.deadwood:
        return 'UNGROUPED';
    }
  }

  /// Whether this group is empty
  bool get isEmpty => cards.isEmpty;

  /// Number of cards in this group
  int get length => cards.length;

  /// Total deadwood penalty points for this group
  int get points {
    if (isValid && type != CardGroupType.deadwood) return 0;
    int sum = 0;
    for (final card in cards) {
      if (card.isPrintedJoker) continue;
      switch (card.rank) {
        case Rank.ace:
        case Rank.jack:
        case Rank.queen:
        case Rank.king:
        case Rank.ten:
          sum += 10;
          break;
        case Rank.nine: sum += 9; break;
        case Rank.eight: sum += 8; break;
        case Rank.seven: sum += 7; break;
        case Rank.six: sum += 6; break;
        case Rank.five: sum += 5; break;
        case Rank.four: sum += 4; break;
        case Rank.three: sum += 3; break;
        case Rank.two: sum += 2; break;
        case null: break;
      }
    }
    return sum;
  }

  /// Create a copy with optional field overrides
  CardGroup copyWith({
    String? id,
    CardGroupType? type,
    List<Card>? cards,
    bool? isValid,
    String? customLabel,
    bool clearCustomLabel = false,
  }) {
    return CardGroup(
      id: id ?? this.id,
      type: type ?? this.type,
      cards: cards ?? List.from(this.cards),
      isValid: isValid ?? this.isValid,
      customLabel: clearCustomLabel ? null : (customLabel ?? this.customLabel),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'cards': cards.map((c) => c.toJson()).toList(),
    'isValid': isValid,
    'customLabel': customLabel,
  };

  factory CardGroup.fromJson(Map<String, dynamic> json) => CardGroup(
    id: json['id'] as String? ?? 'grp_0',
    type: CardGroupType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => CardGroupType.deadwood,
    ),
    cards: (json['cards'] as List<dynamic>? ?? [])
        .map((c) => Card.fromJson(c as Map<String, dynamic>))
        .toList(),
    isValid: json['isValid'] as bool? ?? false,
    customLabel: json['customLabel'] as String?,
  );

  @override
  String toString() => '$label(${cards.map((c) => c.toString()).join(", ")})';
}

/// Data payload carried during drag-and-drop operations
class CardDragData {
  final Card card;
  final String fromGroupId;
  final int cardIndex;

  const CardDragData({
    required this.card,
    required this.fromGroupId,
    this.cardIndex = 0,
  });
}
