import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/round_score.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/score_card_modal.dart';

void main() {
  testWidgets('ScoreCardModal displays Next Deal button when round completes', (WidgetTester tester) async {
    bool nextDealTapped = false;
    bool resetTapped = false;

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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScoreCardModal(
              roundScores: roundScores,
              totalHumanScore: 54,
              totalAiScore: 43,
              eliminationScore: 201,
              isHumanEliminated: false,
              isAiEliminated: false,
              isRoundComplete: true,
              onClose: () {},
              onResetTournament: () {
                resetTapped = true;
              },
              onNextDeal: () {
                nextDealTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    // Verify Scorecard Header and Scores
    expect(find.text('GAME SCORE CARD'), findsOneWidget);
    expect(find.text('54'), findsOneWidget);
    expect(find.text('43'), findsOneWidget);

    // Verify Deal rows
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);

    // Verify Buttons
    expect(find.text('Review Table'), findsOneWidget);
    expect(find.text('Next Deal (#3)'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);

    // Tap Next Deal
    await tester.tap(find.text('Next Deal (#3)'));
    await tester.pump();
    expect(nextDealTapped, isTrue);

    // Tap Reset
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(resetTapped, isTrue);
  });

  testWidgets('ScoreCardModal displays New Tournament when player is eliminated', (WidgetTester tester) async {
    bool resetTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScoreCardModal(
              roundScores: const [],
              totalHumanScore: 205,
              totalAiScore: 80,
              eliminationScore: 201,
              isHumanEliminated: true,
              isAiEliminated: false,
              isRoundComplete: true,
              onClose: () {},
              onResetTournament: () {
                resetTapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('New Tournament'), findsOneWidget);
    await tester.tap(find.text('New Tournament'));
    await tester.pump();
    expect(resetTapped, isTrue);
  });
}
