import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:game_engine/game_engine.dart';
import '../models/card_group.dart';
import '../models/game_settings.dart';
import '../models/round_score.dart';

/// Service that synchronizes the live game state and decision logs
/// from the active player game (http://localhost:8080) to the
/// live Bot Spectator Mirror (http://localhost:8081).
class SpectatorSyncService {
  static const String _syncEndpoint = 'http://localhost:8081/api/sync';
  static bool isEnabled = kDebugMode && !kIsWeb;

  /// Sends a game snapshot + optional event payload to port 8081.
  /// Wrapped in try-catch with timeout so game on 8080 is never blocked or affected.
  static Future<void> syncState({
    required GameState gameState,
    required List<CardGroup> humanGroups,
    required Card? wildJoker,
    required GameSettings gameSettings,
    required List<RoundScore> roundScores,
    required bool isRoundOver,
    bool isAwaitingHumanDeclarationShow = false,
    String? dealerId,
    Map<String, dynamic>? event,
  }) async {
    if (!isEnabled || kIsWeb) return;

    try {
      final humanPlayer = gameState.players.firstWhere(
        (p) => p.id == 'human_player',
        orElse: () => Player(id: 'human_player', hand: []),
      );
      final aiPlayer = gameState.players.firstWhere(
        (p) => p.id == 'ai_bot_1',
        orElse: () => Player(id: 'ai_bot_1', hand: []),
      );

      // Dynamically diagnose Maya Bot's melds using HandPartitioner
      final botPartition = HandPartitioner.findBestPartition(aiPlayer.hand, wildJoker);

      final payload = <String, dynamic>{
        'gameId': gameState.gameId,
        'dealerId': dealerId ?? 'ai_bot_1',
        'turnNumber': gameState.turnNumber,
        'phase': gameState.phase.name,
        'currentPlayerId': gameState.players.isNotEmpty
            ? gameState.players[gameState.currentPlayerIndex].id
            : 'human_player',
        'closedDeckCount': gameState.closedDeck.length,
        'isRoundOver': isRoundOver,
        'isAwaitingHumanDeclarationShow': isAwaitingHumanDeclarationShow,
        'wildJoker': wildJoker != null ? _cardToJson(wildJoker, wildJoker) : null,
        'openPile': gameState.openPile
            .map((c) => _cardToJson(c, wildJoker))
            .toList(),
        'humanPlayer': {
          'id': humanPlayer.id,
          'score': humanPlayer.score,
          'handCount': humanPlayer.hand.length,
          'groups': humanGroups.map((g) => {
            'id': g.id,
            'label': g.label,
            'type': g.type.name,
            'isValid': g.isValid,
            'cards': g.cards.map((c) => _cardToJson(c, wildJoker)).toList(),
          }).toList(),
        },
        'botPlayer': {
          'id': aiPlayer.id,
          'score': aiPlayer.score,
          'handCount': aiPlayer.hand.length,
          'deadwoodPoints': botPartition.penaltyScore,
          'isValidDeclaration': botPartition.isValidDeclaration,
          'pureSeqCount': botPartition.pureSequenceCount,
          'totalSeqCount': botPartition.totalSequenceCount,
          'groups': botPartition.groups.map((g) => {
            'label': g.label,
            'type': g.type.name,
            'isValid': g.isValid,
            'details': g.details,
            'cards': g.cards.map((c) => _cardToJson(c, wildJoker)).toList(),
          }).toList(),
        },
        'gameSettings': {
          'firstDropPenalty': gameSettings.firstDropPenalty,
          'middleDropPenalty': gameSettings.middleDropPenalty,
          'fullCountPenalty': gameSettings.fullCountPenalty,
          'eliminationScore': gameSettings.eliminationScore,
        },
        'roundScores': roundScores.map((r) => {
          'roundNumber': r.roundNumber,
          'humanScore': r.humanScore,
          'aiScore': r.aiScore,
          'cumulativeHumanScore': r.cumulativeHumanScore,
          'cumulativeAiScore': r.cumulativeAiScore,
          'humanOutcome': r.humanOutcome,
          'aiOutcome': r.aiOutcome,
          'timestamp': r.timestamp.toIso8601String(),
        }).toList(),
      };

      if (event != null) {
        payload['event'] = event;
      }

      await http
          .post(
            Uri.parse(_syncEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      // Intentionally silent: Spectator mirror is decoupled and non-blocking
    }
  }

  static Map<String, dynamic> _cardToJson(Card card, Card? wildJoker) {
    final isWild = JokerUtils.isWildJoker(card, wildJoker);

    return {
      'suit': card.suit?.name,
      'rank': card.rank?.name,
      'isPrintedJoker': card.isPrintedJoker,
      'isWild': isWild,
      'display': card.toString(),
      'deckIndex': card.deckIndex,
    };
  }
}
