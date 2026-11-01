import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/models/table_models.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_table_background.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/widgets/multiplayer_opponents_layer.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/presentation/screens/multiplayer_2p_preview_screen.dart';

void main() {
  group('Multiplayer 3, 4, 5, 6-Player Table Layout & UI Tests', () {
    // ----------------- 3-Player Table Tests -----------------
    test('3-Player Table: positions 2 opponents matching the twin royal armchairs', () {
      final positions3p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(3);
      expect(positions3p.length, equals(2));
      expect(positions3p[0].centerX, equals(550.0));
      expect(positions3p[0].top, equals(195.0));
      expect(positions3p[1].centerX, equals(1205.0));
      expect(positions3p[1].top, equals(195.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(3), equals('assets/images/multiplayer_bg_3p.webp'));
    });

    testWidgets('3-Player Table: renders 2 opponent pods with dealer and turn info', (tester) async {
      tester.view.physicalSize = const Size(1754, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final opp1 = TablePlayer(
        uid: 'opp_vikram',
        displayName: 'Vikram S.',
        photoURL: '',
        seatIndex: 1,
        cardCount: 13,
        status: 'ACTIVE',
        connected: true,
      );
      final opp2 = TablePlayer(
        uid: 'opp_ananya',
        displayName: 'Ananya R.',
        photoURL: '',
        seatIndex: 2,
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
                    maxPlayers: 3,
                    opponents: [opp1, opp2],
                    currentTurnPlayerId: 'opp_ananya',
                    dealerPlayerId: 'opp_vikram',
                    remainingTurnSeconds: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Vikram S.'), findsOneWidget);
      expect(find.textContaining('Ananya R.'), findsOneWidget);
      expect(find.text('D'), findsOneWidget); // Dealer badge
      expect(find.text('⏱ 22s'), findsOneWidget); // Turn timer
    });

    // ----------------- 4-Player Table Tests -----------------
    test('4-Player Table: positions 3 opponents across Left, Center, and Right armchair crests', () {
      final positions4p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(4);
      expect(positions4p.length, equals(3));
      expect(positions4p[0].centerX, equals(115.0));
      expect(positions4p[0].top, equals(310.0));
      expect(positions4p[1].centerX, equals(878.0));
      expect(positions4p[1].isCenter, isTrue);
      expect(positions4p[1].top, equals(245.0));
      expect(positions4p[2].centerX, equals(1640.0));
      expect(positions4p[2].top, equals(310.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(4), equals('assets/images/multiplayer_bg_4p.webp'));
    });

    // ----------------- 5-Player Table Tests -----------------
    test('5-Player Table: positions 4 opponents matching 4 armchair crests in royal arc', () {
      final positions5p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(5);
      expect(positions5p.length, equals(4));
      expect(positions5p[0].centerX, equals(85.0));
      expect(positions5p[0].top, equals(310.0));
      expect(positions5p[1].centerX, equals(640.0));
      expect(positions5p[1].top, equals(245.0));
      expect(positions5p[2].centerX, equals(1116.0));
      expect(positions5p[2].top, equals(245.0));
      expect(positions5p[3].centerX, equals(1670.0));
      expect(positions5p[3].top, equals(310.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(5), equals('assets/images/multiplayer_bg_5p.webp'));
    });

    // ----------------- 6-Player Table Tests -----------------
    test('6-Player Table: positions 5 opponents across 5 armchair crests in royal arc', () {
      final positions6p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(6);
      expect(positions6p.length, equals(5));
      expect(positions6p[0].centerX, equals(80.0));
      expect(positions6p[0].top, equals(310.0));
      expect(positions6p[1].centerX, equals(490.0));
      expect(positions6p[1].top, equals(255.0));
      expect(positions6p[2].centerX, equals(878.0));
      expect(positions6p[2].isCenter, isTrue);
      expect(positions6p[2].top, equals(245.0));
      expect(positions6p[3].centerX, equals(1266.0));
      expect(positions6p[3].top, equals(255.0));
      expect(positions6p[4].centerX, equals(1676.0));
      expect(positions6p[4].top, equals(310.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(6), equals('assets/images/multiplayer_bg_6p.webp'));
    });

    // ----------------- Preview Capacity Switcher Test -----------------
    testWidgets('Multiplayer2PPreviewScreen switches capacity on pill tap', (tester) async {
      tester.view.physicalSize = const Size(1754, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Multiplayer2PPreviewScreen(initialCapacity: 3),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Should initially display 3-MAX badge
      expect(find.text('3-MAX'), findsOneWidget);

      // Tap 5P switcher pill
      await tester.tap(find.text('5P'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now should display 5-MAX badge
      expect(find.text('5-MAX'), findsOneWidget);
    });
  });
}
