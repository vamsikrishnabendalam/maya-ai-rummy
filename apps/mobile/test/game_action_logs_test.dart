import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/game_action_log.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/game_logs_modal.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';

void main() {
  group('Game Action Logs & Download Tests', () {
    test('GameActionLogEntry model serializes to JSON and formats text string', () {
      final entry = GameActionLogEntry(
        roundNumber: 1,
        turnNumber: 3,
        player: 'Human',
        action: 'Discard',
        details: 'Discarded 7 of hearts',
        card: const Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        timestamp: DateTime(2026, 11, 1, 14, 30, 0),
      );

      final json = entry.toJson();
      expect(json['round'], 1);
      expect(json['turn'], 3);
      expect(json['player'], 'Human');
      expect(json['action'], 'Discard');
      expect(json['details'], 'Discarded 7 of hearts');
      expect(json['card'], contains('7'));

      final str = entry.toString();
      expect(str, contains('R1 Turn 3 - Human: Discard - Discarded 7 of hearts'));
    });

    testWidgets('GameTableNotifier logs moves and generates export text and JSON', (tester) async {
      final container = ProviderContainer();

      final notifier = container.read(gameTableProvider.notifier);

      // Allow startNewGame microtask and UI action timers to execute
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Initial deal should be logged
      expect(notifier.state.actionLogs.isNotEmpty, isTrue);
      expect(notifier.state.actionLogs.first.action, 'Deal');

      // Human draws from closed deck
      if (notifier.isHumanTurn && notifier.isDrawPhase) {
        notifier.drawFromClosedDeck();
        await tester.pump(const Duration(milliseconds: 700));
        expect(notifier.state.actionLogs.any((l) => l.action == 'Draw Deck'), isTrue);
      }

      // Check text export
      final text = notifier.getLogsText();
      expect(text, contains('MAYA AI RUMMY GAME ACTION LOGS'));
      expect(text, contains('Human'));

      // Check JSON export
      final jsonStr = notifier.getLogsJson();
      expect(jsonStr, contains('Maya AI Rummy Action Logs'));
      expect(jsonStr, contains('logs'));

      // Check download function executes safely
      notifier.downloadLogs(roundNumber: 1, asJson: true);
      notifier.downloadLogs(roundNumber: 1, asJson: false);

      notifier.cancelTurnTimer();
      await tester.pump(const Duration(milliseconds: 500));
      container.dispose();
    });

    testWidgets('GameLogsModal renders logged events and filter chips', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testLogs = [
        GameActionLogEntry(
          roundNumber: 1,
          turnNumber: 1,
          player: 'Dealer (Maya Bot)',
          action: 'Deal',
          details: 'Deal 1 dealt. Wild Joker: 5 of spades.',
          timestamp: DateTime.now(),
        ),
        GameActionLogEntry(
          roundNumber: 1,
          turnNumber: 1,
          player: 'Human',
          action: 'Draw Deck',
          details: 'Drew card from closed deck',
          timestamp: DateTime.now(),
        ),
        GameActionLogEntry(
          roundNumber: 2,
          turnNumber: 1,
          player: 'Maya (AI Host)',
          action: 'Discard',
          details: 'Discarded 10 of clubs',
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameLogsModal(
              logs: testLogs,
              totalRounds: 2,
              onDownloadLogs: ({int? roundNumber, bool asJson = true}) {},
              onGetLogsText: ({int? roundNumber}) => 'Test Log Text',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify modal header
      expect(find.text('GAME ACTION LOGS'), findsOneWidget);
      expect(find.text('Download JSON'), findsOneWidget);
      expect(find.text('Download Text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Verify round filter chips exist
      expect(find.text('All'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R2'), findsOneWidget);

      // Verify log actions are visible
      expect(find.text('Deal'), findsOneWidget);
      expect(find.text('Draw Deck'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Filter to Round 2
      await tester.tap(find.text('R2'));
      await tester.pumpAndSettle();

      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Draw Deck'), findsNothing);
    });

    testWidgets('GameLogsModal handles 17+ rounds without squishing title or overflowing', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final manyLogs = List.generate(
        34,
        (i) => GameActionLogEntry(
          roundNumber: (i ~/ 2) + 1,
          turnNumber: (i % 2) + 1,
          player: i.isEven ? 'Human' : 'Maya (AI Host)',
          action: i.isEven ? 'Draw Deck' : 'Discard',
          details: 'Action details for round ${(i ~/ 2) + 1}',
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameLogsModal(
              logs: manyLogs,
              totalRounds: 17,
              onDownloadLogs: ({int? roundNumber, bool asJson = true}) {},
              onGetLogsText: ({int? roundNumber}) => 'Test Log Text',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title is rendered cleanly
      expect(find.text('GAME ACTION LOGS'), findsOneWidget);
      expect(find.text('34 events logged across 17 round(s)'), findsOneWidget);

      // Verify round filter chips exist for R1 through R17
      expect(find.text('All'), findsOneWidget);
      expect(find.text('R1'), findsOneWidget);
      expect(find.text('R17'), findsWidgets);

      // Verify action buttons exist
      expect(find.text('Download JSON'), findsOneWidget);
      expect(find.text('Download Text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Verify actions list is visible
      expect(find.text('Draw Deck'), findsWidgets);
      expect(find.text('Discard'), findsWidgets);
    });
  });
}
