import 'card.dart';

abstract class GameAction {
  final String playerId;
  final String gameId;
  final int sequenceNumber;
  final DateTime timestamp;

  GameAction({
    required this.playerId,
    required this.gameId,
    required this.sequenceNumber,
    required this.timestamp,
  });
}

class DrawFromClosedDeck extends GameAction {
  DrawFromClosedDeck({required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

class DrawFromOpenDeck extends GameAction {
  DrawFromOpenDeck({required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

class DiscardCard extends GameAction {
  final Card card;
  DiscardCard(this.card, {required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

class DeclareHand extends GameAction {
  final List<List<Card>> groups; // Must total 13 cards
  DeclareHand(this.groups, {required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

enum DropType { FIRST_DROP, MIDDLE_DROP }

class DropGame extends GameAction {
  final DropType type;
  DropGame(this.type, {required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

class SendChat extends GameAction {
  final String message;
  SendChat(this.message, {required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}

class RequestReconnect extends GameAction {
  final String reconnectToken;
  RequestReconnect(this.reconnectToken, {required super.playerId, required super.gameId, required super.sequenceNumber, required super.timestamp});
}
