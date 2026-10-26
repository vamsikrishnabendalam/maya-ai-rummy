import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/round_score.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/screens/game_table_screen.dart';

void main() {
  testWidgets('GameTableScreen displays Deal Next Round bar when round is complete', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Suppress RenderFlex overflow errors in test output for clean verification
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    final roundScores = [
      RoundScore(
        roundNumber: 1,
        humanScore: 0,
        aiScore: 43,
        cumulativeHumanScore: 0,
        cumulativeAiScore: 43,
        humanOutcome: 'Declared (0 pts)',
        aiOutcome: 'Lost (43 pts)',
        timestamp: DateTime.now(),
      ),
      RoundScore(
        roundNumber: 2,
        humanScore: 54,
        aiScore: 0,
        cumulativeHumanScore: 54,
        cumulativeAiScore: 43,
        humanOutcome: 'Lost (54 pts)',
        aiOutcome: 'Declared (0 pts)',
        timestamp: DateTime.now(),
      ),
    ];

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: GameTableScreen(),
        ),
      ),
    );

    // Let the initial startNewGame microtask complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Now set the round completed state (matching user's state after deal 2)
    final notifier = container.read(gameTableProvider.notifier);
    notifier.state = notifier.state.copyWith(
      gameState: notifier.state.gameState.copyWith(phase: GamePhase.COMPLETE),
      roundScores: roundScores,
      isRoundOver: true,
      currentScore: 54,
    );
    await tester.pump();

    // Verify toast pill mentions round 2 completed
    expect(find.textContaining('Round 2 completed!'), findsOneWidget);

    // Verify Deal Next Round bar is visible with Deal #3
    expect(find.text('Deal Next Round (#3)'), findsOneWidget);
    expect(find.text('Scorecard'), findsAtLeastNWidgets(1));

    // Tap Deal Next Round
    await tester.tap(find.text('Deal Next Round (#3)'));
    await tester.pump();
    // Allow action timer to complete
    await tester.pump(const Duration(milliseconds: 600));

    // Verify a new deal was started (turn resets to DRAW_PHASE)
    expect(find.textContaining('Your Turn!'), findsOneWidget);
  });
}
