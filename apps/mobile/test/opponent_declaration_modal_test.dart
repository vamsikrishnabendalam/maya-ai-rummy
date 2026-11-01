import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/opponent_declaration_modal.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create mock HandPartitionResult for Maya
  final List<Card> pureGroup = [
    const Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
    const Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
    const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
  ];
  final List<Card> impureGroup = [
    const Card(suit: Suit.spades, rank: Rank.ten, deckIndex: 0),
    const Card(suit: Suit.spades, rank: Rank.jack, deckIndex: 0),
    const Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
  ];
  final List<Card> setGroup1 = [
    const Card(suit: Suit.clubs, rank: Rank.five, deckIndex: 0),
    const Card(suit: Suit.diamonds, rank: Rank.five, deckIndex: 0),
    const Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
  ];
  final List<Card> setGroup2 = [
    const Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
    const Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
    const Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
    const Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
  ];

  final mockBotPartition = HandPartitionResult(
    isValidDeclaration: true,
    penaltyScore: 0,
    errorMessage: '',
    pureSequenceCount: 1,
    totalSequenceCount: 2,
    groups: [
      GroupDiagnosis(
        cards: pureGroup,
        type: HandGroupType.pureSequence,
        isValid: true,
        label: 'PURE SEQUENCE',
        details: 'Pure sequence of 3 cards',
      ),
      GroupDiagnosis(
        cards: impureGroup,
        type: HandGroupType.impureSequence,
        isValid: true,
        label: 'IMPURE SEQUENCE',
        details: 'Sequence of 3 cards',
      ),
      GroupDiagnosis(
        cards: setGroup1,
        type: HandGroupType.validSet,
        isValid: true,
        label: 'SET',
        details: 'Set of 3 cards',
      ),
      GroupDiagnosis(
        cards: setGroup2,
        type: HandGroupType.validSet,
        isValid: true,
        label: 'SET',
        details: 'Set of 4 cards',
      ),
    ],
    unmatchedCards: [],
  );

  const mockFinishCard = Card(suit: Suit.diamonds, rank: Rank.ace, deckIndex: 0);
  const mockWildJoker = Card(suit: Suit.spades, rank: Rank.seven, deckIndex: 0);

  testWidgets('OpponentDeclarationModal displays Maya declaration and prompts player',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(() {
      try {
        container.read(gameTableProvider.notifier).cancelTurnTimer();
      } catch (_) {}
      container.dispose();
    });

    bool didRearrange = false;
    bool didDeclare = false;

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          home: Scaffold(
            body: OpponentDeclarationModal(
              declarerName: 'Maya (AI Host)',
              botDeclarationResult: mockBotPartition,
              finishCard: mockFinishCard,
              wildJoker: mockWildJoker,
              onRearrange: () => didRearrange = true,
              onDeclareFinalHand: () => didDeclare = true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verifies Header & Maya Declaration Title
    expect(find.text('Maya (AI Host) Declared Show!'), findsOneWidget);
    expect(find.text('VALID SHOW • 0 PTS'), findsOneWidget);

    // 2. Verifies Melds Breakdown
    expect(find.text("OPPONENT'S WINNING DECLARATION"), findsOneWidget);
    expect(find.text('PURE SEQUENCE'), findsOneWidget);
    expect(find.text('IMPURE SEQUENCE'), findsOneWidget);
    expect(find.text('SET'), findsWidgets);
    expect(find.text('FINISH CARD'), findsOneWidget);

    // 3. Verifies Player Prompt & Final Hand Section
    expect(find.text('YOUR FINAL HAND DECLARATION'), findsOneWidget);
    expect(
      find.text(
        'Maya has declared her hand. Arrange your remaining 13 cards to minimize penalty points, then declare your final hand for scoring.',
      ),
      findsOneWidget,
    );

    // 4. Verifies Action Buttons
    expect(find.text('Rearrange Hand'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);

    // 5. Test Rearrange Hand button
    await tester.tap(find.text('Rearrange Hand'));
    await tester.pump();
    expect(didRearrange, isTrue);

    // 6. Test Declare Final Hand button
    await tester.tap(find.byIcon(Icons.emoji_events_rounded).last);
    await tester.pump();
    expect(didDeclare, isTrue);

    // Cancel timer before test ends so no pending timers remain
    container.read(gameTableProvider.notifier).cancelTurnTimer();
    await tester.pump(const Duration(seconds: 2));
  });
}
