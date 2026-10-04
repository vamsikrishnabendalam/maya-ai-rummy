import 'package:game_engine/game_engine.dart' show Card;

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
