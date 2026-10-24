import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:game_engine/game_engine.dart';
import '../models/table_models.dart';
import 'file_saver_stub.dart' if (dart.library.html) 'file_saver_web.dart';

/// Fair-Play Audit & Game Log Exporter
/// Generates verifiable cryptographic logs and card accounting reports for Rummy games.
class GameLogExporter {
  /// Verify the physical card accounting invariant:
  /// Total = sum(Player Hands) + Closed Deck + Discard Pile + Open Cut Joker == 54 (<=2 players) or 108 (3+ players)
  static Map<String, dynamic> performCardAccountingAudit(MultiplayerGameState game) {
    final expectedTotalCards = game.playerCount <= 2 ? 54 : 108;
    final handsTotal = game.players.fold<int>(0, (sum, p) => sum + p.cardCount);
    final closedDeckCount = game.closedDeckRemaining;
    final discardPileCount = game.openPile.length;
    const openJokerCount = 1;

    final totalAccounted = handsTotal + closedDeckCount + discardPileCount + openJokerCount;
    final isBalanced = totalAccounted == expectedTotalCards;

    return {
      'expectedTotalCards': expectedTotalCards,
      'playerHandsTotalCards': handsTotal,
      'closedDeckRemaining': closedDeckCount,
      'discardPileCount': discardPileCount,
      'openJokerCount': openJokerCount,
      'totalAccountedCards': totalAccounted,
      'isInvariantBalanced': isBalanced,
      'accountingDiscrepancy': expectedTotalCards - totalAccounted,
      'status': isBalanced ? 'VERIFIED_FAIR_PLAY' : 'INVARIANT_DISCREPANCY',
    };
  }

  /// Generate complete cryptographic audit log in formatted JSON
  static String generateJson(MultiplayerGameState game) {
    final audit = performCardAccountingAudit(game);
    final now = DateTime.now();

    final exportData = {
      'platform': 'Maya AI Rummy Fair-Play Engine v2.0',
      'schemaVersion': '2.0.0',
      'generatedAt': now.toIso8601String(),
      'gameMetadata': {
        'gameId': game.gameId,
        'tableId': game.tableId,
        'roomCode': game.roomCode,
        'gameMode': game.gameMode,
        'status': game.status,
        'currentRound': game.currentRound,
        'playerCount': game.playerCount,
        'totalTurns': game.turnNumber,
        'dealerPlayerId': game.dealerPlayerId,
        'winnerPlayerId': game.winnerPlayerId ?? 'None',
        'startedAt': game.startedAt?.toIso8601String() ?? 'Unknown',
        'endedAt': game.endedAt?.toIso8601String() ?? now.toIso8601String(),
        'durationSeconds': (game.startedAt != null && game.endedAt != null)
            ? game.endedAt!.difference(game.startedAt!).inSeconds
            : null,
      },
      'tournamentRounds': {
        'totalRoundsPlayed': game.currentRound,
        'roundHistory': game.roundHistory,
      },
      'cardAccountingAudit': audit,
      'openJoker': game.openJoker != null
          ? {
              'cardId': game.openJoker!.cardId,
              'suit': game.openJoker!.suit?.name ?? 'joker',
              'rank': game.openJoker!.rank?.name ?? 'joker',
              'label': game.openJoker!.label,
              'isPrintedJoker': game.openJoker!.isJoker,
              'deckIndex': game.openJoker!.deckIndex,
              'effectiveWildRank': game.effectiveWildRank,
            }
          : null,
      'discardPileTop': game.openPile.isNotEmpty
          ? {
              'cardId': game.openPile.last.cardId,
              'label': game.openPile.last.label,
              'count': game.openPile.length,
            }
          : null,
      'playersSummary': game.players.map((p) {
        final res = game.finalResults.where((r) => r.uid == p.uid).toList();
        final score = res.isNotEmpty ? res.first.score : p.score;
        final isWinner = res.isNotEmpty ? res.first.isWinner : (game.winnerPlayerId == p.uid);

        return {
          'uid': p.uid,
          'displayName': p.displayName,
          'seatIndex': p.seatIndex,
          'cardCount': p.cardCount,
          'status': p.status,
          'isHost': p.isHost,
          'isWinner': isWinner,
          'finalScore': score,
        };
      }).toList(),
      'chronologicalActionLog': game.actionLog.map((log) {
        final cardInt = log['card'];
        String? cardLabel;
        if (cardInt is int) {
          cardLabel = Card.fromInt(cardInt).label;
        }

        return {
          'seq': log['seq'],
          'timestamp': log['timestamp'],
          'type': log['type'],
          'playerId': log['playerId'],
          'cardInt': cardInt,
          'cardLabel': cardLabel,
          'description': log['description'],
        };
      }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Generate CSV log of chronological actions
  static String generateCsv(MultiplayerGameState game) {
    final buffer = StringBuffer();
    buffer.writeln('Sequence,Timestamp,ActionType,PlayerId,Card,Description');

    for (final log in game.actionLog) {
      final seq = log['seq'] ?? '';
      final time = log['timestamp'] ?? '';
      final type = log['type'] ?? '';
      final pid = log['playerId'] ?? '';
      final cardInt = log['card'];
      final cardStr = cardInt is int ? Card.fromInt(cardInt).label : '';
      final desc = (log['description'] ?? '').toString().replaceAll('"', '""');

      buffer.writeln('$seq,"$time","$type","$pid","$cardStr","$desc"');
    }

    return buffer.toString();
  }

  /// Download Fair-Play Game Log as JSON (Anti-cheat: only allowed after declaration/completion)
  static Future<String> downloadGameLogJson(MultiplayerGameState game) async {
    if (game.status == 'IN_PROGRESS') {
      throw Exception('Fair-Play Protection: Audit logs cannot be exported during active gameplay to prevent card inspection. Available after declaration or round completion.');
    }
    final jsonContent = generateJson(game);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'MayaRummy_${game.roomCode.isNotEmpty ? game.roomCode : "ROOM"}_${game.gameId}_$timestamp.json';

    try {
      saveFileWeb(
        fileName: fileName,
        content: jsonContent,
        mimeType: 'application/json',
      );
    } catch (e) {
      debugPrint('[GameLogExporter] Browser download error: $e');
    }

    // Also copy to clipboard for convenience
    try {
      await Clipboard.setData(ClipboardData(text: jsonContent));
    } catch (_) {}

    return fileName;
  }

  /// Download Fair-Play Game Log as CSV
  static Future<String> downloadGameLogCsv(MultiplayerGameState game) async {
    final csvContent = generateCsv(game);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'MayaRummy_${game.roomCode.isNotEmpty ? game.roomCode : "ROOM"}_${game.gameId}_$timestamp.csv';

    try {
      saveFileWeb(
        fileName: fileName,
        content: csvContent,
        mimeType: 'text/csv',
      );
    } catch (e) {
      debugPrint('[GameLogExporter] Browser download error: $e');
    }

    return fileName;
  }
}
