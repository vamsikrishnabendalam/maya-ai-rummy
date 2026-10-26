import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/player_hand.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/screens/game_table_screen.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/card_widget.dart';

void main() {
  testWidgets('PlayerHand in mobile landscape (850px) renders cards with generous width and zero overflow', (tester) async {
    tester.view.physicalSize = const Size(850, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cardGroups = [
      CardGroup(
        id: 'group_1',
        type: CardGroupType.pureSequence,
        cards: const [
          Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_2',
        type: CardGroupType.impureSequence,
        cards: const [
          Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
          Card(suit: Suit.hearts, rank: Rank.jack, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_3',
        type: CardGroupType.set,
        cards: const [
          Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
          Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_4',
        type: CardGroupType.deadwood,
        cards: const [
          Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
          Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
          Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 850,
            child: PlayerHand(
              cardGroups: cardGroups,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PlayerHand), findsOneWidget);
    // Find rendered CardWidgets
    final cardWidgetFinders = find.byType(CardWidget);
    expect(cardWidgetFinders, findsNWidgets(13));

    // Verify each card width is at least 56.0 logical pixels (large and legible)
    final firstCard = tester.widget<CardWidget>(cardWidgetFinders.first);
    expect(firstCard.width, greaterThanOrEqualTo(56.0));

    expect(tester.takeException(), isNull);
  });

  testWidgets('GameTableScreen in mobile landscape renders with zero overflows and visible thumb controls', (tester) async {
    // Realme RMX3360 typical viewport in landscape
    tester.view.physicalSize = const Size(872, 392);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameTableScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify table rendered with no RenderFlex overflow exceptions
    expect(tester.takeException(), isNull);

    // Verify brand title is visible
    expect(find.text('MAYA AI RUMMY'), findsOneWidget);

    // Verify thumb controls exist
    expect(find.text('Sort Hand'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
  });
}
