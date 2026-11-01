import 'package:game_engine/game_engine.dart';

/// Single logged event during Maya AI Rummy gameplay.
class GameActionLogEntry {
  final int roundNumber;
  final int turnNumber;
  final String player; // 'Human' or 'Maya (AI Host)'
  final String action; // 'Deal', 'Draw Deck', 'Draw Open', 'Discard', 'Drop', 'Declare', 'Round Result'
  final String details;
  final Card? card;
  final DateTime timestamp;

  const GameActionLogEntry({
    required this.roundNumber,
    required this.turnNumber,
    required this.player,
    required this.action,
    required this.details,
    this.card,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'round': roundNumber,
    'turn': turnNumber,
    'player': player,
    'action': action,
    'details': details,
    if (card != null) 'card': card.toString(),
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() {
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final cardStr = card != null ? ' [$card]' : '';
    return '[$timeStr] R$roundNumber Turn $turnNumber - $player: $action - $details$cardStr';
  }
}

