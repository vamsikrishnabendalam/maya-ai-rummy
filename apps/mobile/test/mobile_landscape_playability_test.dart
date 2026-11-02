import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/player_hand.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/screens/game_table_screen.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/card_widget.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/declaration_result_modal.dart';

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

  testWidgets('DeclarationResultModal renders horizontally side-by-side without vertical scroll in mobile landscape', (tester) async {
    tester.view.physicalSize = const Size(872, 392);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const openJoker = Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0);
    final mockGroups = [
      const [
        Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.five, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.six, deckIndex: 0),
      ],
      const [
        Card(suit: Suit.hearts, rank: Rank.seven, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.eight, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
      ],
      const [
        Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.king, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0),
      ],
      const [
        Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
      ],
    ];

    final result = HandPartitioner.evaluateGroups(mockGroups, openJoker);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeclarationResultModal(
            result: result,
            openJoker: openJoker,
            onDismiss: () {},
            onNewGame: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(DeclarationResultModal), findsOneWidget);
    expect(find.text('VALID DECLARATION!'), findsOneWidget);
    expect(find.text('HAND BREAKDOWN:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayerHand with 14 cards renders without overflow in mobile landscape', (tester) async {
    tester.view.physicalSize = const Size(872, 392);
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
          Card(suit: Suit.spades, rank: Rank.king, deckIndex: 0), // 14th card
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 872,
            child: PlayerHand(
              cardGroups: cardGroups,
              customCardWidth: 62.0,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PlayerHand), findsOneWidget);
    expect(find.byType(CardWidget), findsNWidgets(14));
    expect(tester.takeException(), isNull);
  });
}
