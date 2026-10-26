import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/player_hand.dart';

void main() {
  testWidgets('PlayerHand in compact portrait (360px) fits all 13 cards without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cardGroups = [
      CardGroup(
        id: 'group_1',
        type: CardGroupType.pureSequence,
        cards: [
          const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_2',
        type: CardGroupType.impureSequence,
        cards: [
          const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
          const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
          const Card(suit: Suit.hearts, rank: Rank.jack, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_3',
        type: CardGroupType.set,
        cards: [
          const Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
          const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_4',
        type: CardGroupType.deadwood,
        cards: [
          const Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
          const Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
          const Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: PlayerHand(
              cardGroups: cardGroups,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify all 13 cards are rendered in the widget tree
    expect(find.byType(PlayerHand), findsOneWidget);
    // No overflow errors
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlayerHand in portrait (390px) fits 14 cards (after drawing) without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cardGroups = [
      CardGroup(
        id: 'group_1',
        type: CardGroupType.pureSequence,
        cards: [
          const Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.two, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.three, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.four, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_2',
        type: CardGroupType.impureSequence,
        cards: [
          const Card(suit: Suit.hearts, rank: Rank.nine, deckIndex: 0),
          const Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0),
          const Card(suit: Suit.hearts, rank: Rank.jack, deckIndex: 0),
          const Card(suit: Suit.hearts, rank: Rank.queen, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_3',
        type: CardGroupType.set,
        cards: [
          const Card(suit: Suit.clubs, rank: Rank.queen, deckIndex: 0),
          const Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0),
          const Card(suit: Suit.spades, rank: Rank.queen, deckIndex: 0),
        ],
      ),
      CardGroup(
        id: 'group_4',
        type: CardGroupType.deadwood,
        cards: [
          const Card(suit: Suit.hearts, rank: Rank.king, deckIndex: 0),
          const Card(suit: Suit.diamonds, rank: Rank.four, deckIndex: 0),
          const Card(suit: Suit.clubs, rank: Rank.six, deckIndex: 0),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: PlayerHand(
              cardGroups: cardGroups,
              isDiscardPhase: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PlayerHand), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
