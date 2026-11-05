import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/models/table_models.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_table_background.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_opponents_layer.dart';

void main() {
  group('Multiplayer 2-Player Table UI & Extensibility Tests', () {
    testWidgets('MultiplayerTableBackground loads multiplayer_bg_2p.webp for 2 players', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MultiplayerTableBackground(
              maxPlayers: 2,
              child: SizedBox(width: 1754, height: 896),
            ),
          ),
        ),
      );

      final bgFinder = find.byType(MultiplayerTableBackground);
      expect(bgFinder, findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final Image imageWidget = tester.widget(imageFinder);
      final AssetImage assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/multiplayer_bg_2p.webp'));
    });

    test('MultiplayerTableBackground asset resolution handles 2, 3, 4, 5, 6 players', () {
      expect(MultiplayerTableBackground.assetForMaxPlayers(2), equals('assets/images/multiplayer_bg_2p.webp'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(3), equals('assets/images/multiplayer_bg_3p.webp'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(4), equals('assets/images/multiplayer_bg_4p.webp'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(5), equals('assets/images/multiplayer_bg_5p.webp'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(6), equals('assets/images/multiplayer_bg_6p.webp'));
      // Default fallback
      expect(MultiplayerTableBackground.assetForMaxPlayers(10), equals('assets/images/multiplayer_bg_6p.webp'));
    });

    test('MultiplayerSeatPosition for 2 players centers the opponent pod at top: 70 and seated avatar at top: 125', () {
      final positions2p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(2);
      expect(positions2p.length, equals(1));
      expect(positions2p.first.isCenter, isTrue);
      expect(positions2p.first.centerX, equals(877.0));
      expect(positions2p.first.top, equals(70.0));
      expect(positions2p.first.avatarTop, equals(125.0));
    });

    testWidgets('MultiplayerOpponentsLayer maps opponent player name, dealer badge, cards count and turn timer', (tester) async {
      final opponent = TablePlayer(
        uid: 'opponent_123',
        displayName: 'Rahul Sharma',
        photoURL: '',
        seatIndex: 1,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1754,
              height: 896,
              child: Stack(
                children: [
                  MultiplayerOpponentsLayer(
                    maxPlayers: 2,
                    opponents: [opponent],
                    currentTurnPlayerId: 'opponent_123',
                    dealerPlayerId: 'opponent_123',
                    remainingTurnSeconds: 25,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify opponent name is shown (instead of Maya Host)
      expect(find.textContaining('Rahul Sharma'), findsOneWidget);
      // Verify dealer badge (D) is rendered
      expect(find.text('D'), findsOneWidget);
      // Verify 13 cards chip
      expect(find.textContaining('13'), findsOneWidget);
      // Verify turn timer
      expect(find.textContaining('25s'), findsOneWidget);
    });

    testWidgets('Multiplayer Open Discard Pile DragTarget accepts dropped CardDragData without prior selection', (tester) async {
      Card? discardedCard;
      const testCard = Card(suit: Suit.hearts, rank: Rank.ten, deckIndex: 0);

      const isMyTurn = true;
      const isDiscardPhase = true;
      const isDeclaring = false;
      // Note: selectedCard is null (no card clicked/selected)
      const canDiscardOpenPile = isMyTurn && isDiscardPhase && !isDeclaring;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Open pile DragTarget
                DragTarget<Object>(
                  onWillAcceptWithDetails: (_) => canDiscardOpenPile,
                  onAcceptWithDetails: (details) {
                    if (details.data is CardDragData) {
                      discardedCard = (details.data as CardDragData).card;
                    } else if (details.data is Card) {
                      discardedCard = details.data as Card;
                    }
                  },
                  builder: (context, candidate, rejected) => Container(
                    key: const Key('open_pile_target'),
                    width: 100,
                    height: 100,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 50),
                // Draggable card in player hand
                Draggable<CardDragData>(
                  data: const CardDragData(
                    card: testCard,
                    fromGroupId: 'group_0',
                    cardIndex: 0,
                  ),
                  feedback: const SizedBox(width: 70, height: 100),
                  child: Container(
                    key: const Key('hand_card_draggable'),
                    width: 70,
                    height: 100,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Perform drag and drop from hand card to open pile target
      final draggableFinder = find.byKey(const Key('hand_card_draggable'));
      final targetFinder = find.byKey(const Key('open_pile_target'));

      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(targetFinder));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(discardedCard, equals(testCard));
    });

    testWidgets('Finish slot accepts drag and drop card for declare without prior card selection', (tester) async {
      const testCard = Card(suit: Suit.spades, rank: Rank.ace, deckIndex: 0);
      Card? finishDeclaredCard;

      const isMyTurn = true;
      const isDiscardPhase = true;
      const isDeclaring = false;
      const canAcceptDrop = isMyTurn && isDiscardPhase && !isDeclaring;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Finish Slot DragTarget
                DragTarget<Object>(
                  onWillAcceptWithDetails: (_) => canAcceptDrop,
                  onAcceptWithDetails: (details) {
                    if (details.data is CardDragData) {
                      finishDeclaredCard = (details.data as CardDragData).card;
                    } else if (details.data is Card) {
                      finishDeclaredCard = details.data as Card;
                    }
                  },
                  builder: (context, candidate, rejected) => Container(
                    key: const Key('finish_slot_target'),
                    width: 70,
                    height: 100,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 50),
                // Draggable card in player hand
                Draggable<CardDragData>(
                  data: const CardDragData(
                    card: testCard,
                    fromGroupId: 'group_0',
                    cardIndex: 0,
                  ),
                  feedback: const SizedBox(width: 70, height: 100),
                  child: Container(
                    key: const Key('hand_card_draggable_for_finish'),
                    width: 70,
                    height: 100,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final draggableFinder = find.byKey(const Key('hand_card_draggable_for_finish'));
      final targetFinder = find.byKey(const Key('finish_slot_target'));

      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(targetFinder));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(finishDeclaredCard, equals(testCard));
    });
  });
}
