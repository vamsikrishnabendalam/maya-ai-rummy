import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_engine/game_engine.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/card_group.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_table_background.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_opponents_layer.dart';

void main() {
  group('Multiplayer Mobile Landscape Layout & Seating Tests', () {
    test('MultiplayerTableBackground resolves mobile assets when isMobileLandscape is true', () {
      expect(
        MultiplayerTableBackground.assetForMaxPlayers(2, isMobileLandscape: true),
        equals('assets/images/multiplayer_mobile_bg_2p.webp'),
      );
      expect(
        MultiplayerTableBackground.assetForMaxPlayers(3, isMobileLandscape: true),
        equals('assets/images/multiplayer_mobile_bg_3p.webp'),
      );
      expect(
        MultiplayerTableBackground.assetForMaxPlayers(4, isMobileLandscape: true),
        equals('assets/images/multiplayer_mobile_bg_4p.webp'),
      );
      expect(
        MultiplayerTableBackground.assetForMaxPlayers(5, isMobileLandscape: true),
        equals('assets/images/multiplayer_mobile_bg_5p.webp'),
      );
      expect(
        MultiplayerTableBackground.assetForMaxPlayers(6, isMobileLandscape: true),
        equals('assets/images/multiplayer_mobile_bg_6p.webp'),
      );
    });

    test('Mobile seat positions are calibrated for 1024x491 canvas', () {
      // 2 Players: 1 opponent centered in central armchair
      final pos2p = MultiplayerOpponentsLayer.getMobilePositionsForPlayerCount(2);
      expect(pos2p.length, equals(1));
      expect(pos2p.first.isCenter, isTrue);
      expect(pos2p.first.centerX, equals(512.0));
      expect(pos2p.first.top, equals(80.0));
      expect(pos2p.first.avatarTop, equals(102.0));
      expect(pos2p.first.avatarHeight, equals(140.0));

      // 3 Players: 2 opponents in twin armchairs
      final pos3p = MultiplayerOpponentsLayer.getMobilePositionsForPlayerCount(3);
      expect(pos3p.length, equals(2));
      expect(pos3p[0].centerX, equals(326.0));
      expect(pos3p[1].centerX, equals(695.0));

      // 4 Players: 3 opponents
      final pos4p = MultiplayerOpponentsLayer.getMobilePositionsForPlayerCount(4);
      expect(pos4p.length, equals(3));
      expect(pos4p[0].centerX, equals(200.0));
      expect(pos4p[1].centerX, equals(510.0));
      expect(pos4p[2].centerX, equals(828.0));

      // 5 Players: 4 opponents in royal arc
      final pos5p = MultiplayerOpponentsLayer.getMobilePositionsForPlayerCount(5);
      expect(pos5p.length, equals(4));
      expect(pos5p[0].centerX, equals(158.0));
      expect(pos5p[1].centerX, equals(385.0));
      expect(pos5p[2].centerX, equals(647.0));
      expect(pos5p[3].centerX, equals(879.0));

      // 6 Players: 5 opponents
      final pos6p = MultiplayerOpponentsLayer.getMobilePositionsForPlayerCount(6);
      expect(pos6p.length, equals(5));
      expect(pos6p[0].centerX, equals(114.0));
      expect(pos6p[1].centerX, equals(298.0));
      expect(pos6p[2].centerX, equals(508.0));
      expect(pos6p[3].centerX, equals(696.0));
      expect(pos6p[4].centerX, equals(900.0));
    });

    testWidgets('Multiplayer mobile DragTarget on Open Pile accepts drag and drop card for discard', (tester) async {
      Card? discardedCard;
      const testCard = Card(suit: Suit.clubs, rank: Rank.king, deckIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DragTarget<Object>(
                  onWillAcceptWithDetails: (details) =>
                      details.data is CardDragData || details.data is Card,
                  onAcceptWithDetails: (details) {
                    if (details.data is CardDragData) {
                      discardedCard = (details.data as CardDragData).card;
                    } else if (details.data is Card) {
                      discardedCard = details.data as Card;
                    }
                  },
                  builder: (context, candidate, rejected) => Container(
                    key: const Key('mobile_open_pile_target'),
                    width: 58,
                    height: 82,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 50),
                Draggable<CardDragData>(
                  data: const CardDragData(
                    card: testCard,
                    fromGroupId: 'group_0',
                    cardIndex: 0,
                  ),
                  feedback: const SizedBox(width: 58, height: 82),
                  child: Container(
                    key: const Key('mobile_hand_card'),
                    width: 58,
                    height: 82,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final draggable = find.byKey(const Key('mobile_hand_card'));
      final target = find.byKey(const Key('mobile_open_pile_target'));

      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(discardedCard, equals(testCard));
    });

    testWidgets('Multiplayer mobile DragTarget on Finish Slot accepts drag and drop card for declare', (tester) async {
      Card? declaredCard;
      const testCard = Card(suit: Suit.diamonds, rank: Rank.queen, deckIndex: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DragTarget<Object>(
                  onWillAcceptWithDetails: (details) =>
                      details.data is CardDragData || details.data is Card,
                  onAcceptWithDetails: (details) {
                    if (details.data is CardDragData) {
                      declaredCard = (details.data as CardDragData).card;
                    } else if (details.data is Card) {
                      declaredCard = details.data as Card;
                    }
                  },
                  builder: (context, candidate, rejected) => Container(
                    key: const Key('mobile_finish_slot_target'),
                    width: 58,
                    height: 82,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 50),
                Draggable<CardDragData>(
                  data: const CardDragData(
                    card: testCard,
                    fromGroupId: 'group_0',
                    cardIndex: 0,
                  ),
                  feedback: const SizedBox(width: 58, height: 82),
                  child: Container(
                    key: const Key('mobile_finish_draggable'),
                    width: 58,
                    height: 82,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final draggable = find.byKey(const Key('mobile_finish_draggable'));
      final target = find.byKey(const Key('mobile_finish_slot_target'));

      final gesture = await tester.startGesture(tester.getCenter(draggable));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(declaredCard, equals(testCard));
    });
  });
}

