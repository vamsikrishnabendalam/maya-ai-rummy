import 'package:game_engine/game_engine.dart';

class PlayerPublicInfo {
  final String playerId;
  final int cardsInHand;
  final bool hasDropped;

  PlayerPublicInfo({
    required this.playerId,
    required this.cardsInHand,
    required this.hasDropped,
  });
}

class AIObservation {
  final List<Card> hand;
  final List<Card> discardPile;
  final Card wildJoker;
  final int closedDeckRemaining;
  final int turnNumber;
  final Map<String, PlayerPublicInfo> opponents;
  final List<Card> knownDeadCards;

  AIObservation({
    required this.hand,
    required this.discardPile,
    required this.wildJoker,
    required this.closedDeckRemaining,
    required this.turnNumber,
    required this.opponents,
    required this.knownDeadCards,
  });

  Card? get topOfOpenPile => discardPile.isNotEmpty ? discardPile.last : null;
  String get myPlayerId => "ai";
}
