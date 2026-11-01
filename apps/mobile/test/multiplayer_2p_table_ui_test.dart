import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/models/table_models.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_table_background.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_opponents_layer.dart';

void main() {
  group('Multiplayer 2-Player Table UI & Extensibility Tests', () {
    testWidgets('MultiplayerTableBackground loads multiplayer_bg_2p.png for 2 players', (tester) async {
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
      expect(assetImage.assetName, equals('assets/images/multiplayer_bg_2p.png'));
    });

    test('MultiplayerTableBackground asset resolution handles 2, 3, 4, 5, 6 players', () {
      expect(MultiplayerTableBackground.assetForMaxPlayers(2), equals('assets/images/multiplayer_bg_2p.png'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(3), equals('assets/images/multiplayer_bg_3p.png'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(4), equals('assets/images/multiplayer_bg_4p.png'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(5), equals('assets/images/multiplayer_bg_5p.png'));
      expect(MultiplayerTableBackground.assetForMaxPlayers(6), equals('assets/images/multiplayer_bg_6p.png'));
      // Default fallback
      expect(MultiplayerTableBackground.assetForMaxPlayers(10), equals('assets/images/multiplayer_bg_6p.png'));
    });

    test('MultiplayerSeatPosition for 2 players centers the opponent pod at top: 195 directly above armchair', () {
      final positions2p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(2);
      expect(positions2p.length, equals(1));
      expect(positions2p.first.isCenter, isTrue);
      expect(positions2p.first.top, equals(195.0));
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
      expect(find.text('13 🂠'), findsOneWidget);
      // Verify turn timer
      expect(find.text('⏱ 25s'), findsOneWidget);
    });
  });
}
