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
    addTearDown(() => notifier.cancelTurnTimer());
    notifier.state = notifier.state.copyWith(
      gameState: notifier.state.gameState.copyWith(phase: GamePhase.COMPLETE),
      roundScores: roundScores,
      isRoundOver: true,
      currentScore: 54,
    );
    await tester.pump();

    // Verify toast pill / bottom instruction bar mentions round 2 completed
    expect(find.textContaining('Round 2 completed!'), findsAtLeastNWidgets(1));

    // Verify Deal Next Round bar is visible with Deal #3
    expect(find.text('Deal Next Round (#3)'), findsOneWidget);
    expect(find.text('Scorecard'), findsAtLeastNWidgets(1));

    // Tap Deal Next Round
    await tester.tap(find.text('Deal Next Round (#3)'));
    await tester.pump();
    // Allow action timer to complete
    await tester.pump(const Duration(milliseconds: 600));

    // Verify a new deal was started (turn resets to DRAW_PHASE)
    expect(find.textContaining('Your Turn!'), findsAtLeastNWidgets(1));
    notifier.cancelTurnTimer();
  });

  testWidgets('Round 1 declared finish card is completely cleared and NOT rendered in finish slot in Round 2', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final oldHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      oldHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldHandler);

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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final notifier = container.read(gameTableProvider.notifier);
    addTearDown(() => notifier.cancelTurnTimer());

    // Simulate Round 1 declaration with 6 of hearts as finishCard
    const finishCardRound1 = Card(suit: Suit.hearts, rank: Rank.six, deckIndex: 0);
    notifier.state = notifier.state.copyWith(
      finishCard: finishCardRound1,
      isRoundOver: true,
      currentScore: 0,
      roundScores: [
        RoundScore(
          roundNumber: 1,
          humanScore: 0,
          aiScore: 40,
          cumulativeHumanScore: 0,
          cumulativeAiScore: 40,
          humanOutcome: 'Declared (0 pts)',
          aiOutcome: 'Lost (40 pts)',
          timestamp: DateTime.now(),
        ),
      ],
    );
    await tester.pump();

    // In Round 1 complete state, finishCard is shown
    expect(notifier.state.finishCard, equals(finishCardRound1));

    // Now start Round 2
    notifier.startNextRound();
    await tester.pump();
    // Allow the AI turn timer, discard animation, and dealing animation to complete
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify finishCard in state is strictly null in Round 2
    expect(notifier.state.finishCard, isNull);
    expect(notifier.state.botDiscardCard, isNull);
    expect(notifier.state.isRoundOver, isFalse);
    expect(notifier.state.currentRoundNumber, equals(2));

    // Verify 6 of hearts is NOT rendered as the finish card in the table
    // (There should be no CardWidget matching 6 of hearts inside the finish slot)
    expect(find.text('6♥'), findsNothing);
    notifier.cancelTurnTimer();
  });
}
