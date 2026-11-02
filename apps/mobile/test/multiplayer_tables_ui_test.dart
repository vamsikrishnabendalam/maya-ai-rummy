import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:maya_ai_rummy_mobile/features/auth/models/avatar_catalog.dart';
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
      expect(positions3p[0].top, equals(58.0));
      expect(positions3p[0].avatarTop, equals(110.0));
      expect(positions3p[1].centerX, equals(1205.0));
      expect(positions3p[1].top, equals(58.0));
      expect(positions3p[1].avatarTop, equals(110.0));
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
      expect(find.textContaining('22s'), findsOneWidget); // Turn timer
    });

    // ----------------- 4-Player Table Tests -----------------
    test('4-Player Table: positions 3 opponents across Left, Center, and Right armchair crests', () {
      final positions4p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(4);
      expect(positions4p.length, equals(3));
      expect(positions4p[0].centerX, equals(160.0));
      expect(positions4p[0].top, equals(150.0));
      expect(positions4p[1].centerX, equals(878.0));
      expect(positions4p[1].isCenter, isTrue);
      expect(positions4p[1].top, equals(85.0));
      expect(positions4p[2].centerX, equals(1600.0));
      expect(positions4p[2].top, equals(150.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(4), equals('assets/images/multiplayer_bg_4p.webp'));
    });

    // ----------------- 5-Player Table Tests -----------------
    test('5-Player Table: positions 4 opponents matching 4 armchair crests in royal arc', () {
      final positions5p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(5);
      expect(positions5p.length, equals(4));
      expect(positions5p[0].centerX, equals(130.0));
      expect(positions5p[0].top, equals(150.0));
      expect(positions5p[1].centerX, equals(640.0));
      expect(positions5p[1].top, equals(85.0));
      expect(positions5p[2].centerX, equals(1116.0));
      expect(positions5p[2].top, equals(85.0));
      expect(positions5p[3].centerX, equals(1620.0));
      expect(positions5p[3].top, equals(150.0));
      expect(MultiplayerTableBackground.assetForMaxPlayers(5), equals('assets/images/multiplayer_bg_5p.webp'));
    });

    // ----------------- 6-Player Table Tests -----------------
    test('6-Player Table: positions 5 opponents across 5 armchair crests in royal arc', () {
      final positions6p = MultiplayerOpponentsLayer.getPositionsForPlayerCount(6);
      expect(positions6p.length, equals(5));
      expect(positions6p[0].centerX, equals(110.0));
      expect(positions6p[0].top, equals(150.0));
      expect(positions6p[1].centerX, equals(490.0));
      expect(positions6p[1].top, equals(100.0));
      expect(positions6p[2].centerX, equals(878.0));
      expect(positions6p[2].isCenter, isTrue);
      expect(positions6p[2].top, equals(85.0));
      expect(positions6p[3].centerX, equals(1266.0));
      expect(positions6p[3].top, equals(100.0));
      expect(positions6p[4].centerX, equals(1640.0));
      expect(positions6p[4].top, equals(150.0));
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

    // ----------------- Seated Avatar & Empty Chair Tests -----------------
    test('AvatarCatalog contains 45 total avatars (1 default, 18 female, 26 male)', () {
      expect(AvatarCatalog.all.length, equals(45));
      expect(AvatarCatalog.femaleAvatars.length, equals(18));
      expect(AvatarCatalog.maleAvatars.length, equals(26));
      expect(AvatarCatalog.defaultAvatar.id, equals('default_avatar'));

      final rand = AvatarCatalog.getRandom();
      expect(rand, isNotNull);
      expect(AvatarCatalog.isPreset(rand.id), isTrue);
      expect(AvatarCatalog.isCustomPhoto('data:image/png;base64,1234'), isTrue);
      expect(AvatarCatalog.isCustomPhoto('https://example.com/pic.jpg'), isTrue);
    });

    testWidgets('MultiplayerOpponentsLayer seats preset avatar in chair with ShaderMask fade', (tester) async {
      tester.view.physicalSize = const Size(1754, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final opp = TablePlayer(
        uid: 'opp_queen',
        displayName: 'Rani Saheba',
        photoURL: 'female_02',
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
                    opponents: [opp],
                    currentTurnPlayerId: 'opp_queen',
                    dealerPlayerId: 'opp_queen',
                    remainingTurnSeconds: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Rani Saheba'), findsOneWidget);
      // ShaderMask used for bottom fade of seated cutout avatar
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('MultiplayerOpponentsLayer renders Option B luxury circular gold badge for custom uploaded photo', (tester) async {
      tester.view.physicalSize = const Size(1754, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customOpp = TablePlayer(
        uid: 'opp_custom',
        displayName: 'Custom Player',
        photoURL: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
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
                    opponents: [customOpp],
                    currentTurnPlayerId: '',
                    dealerPlayerId: '',
                    remainingTurnSeconds: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Custom Player'), findsOneWidget);
      // ClipOval is used to frame the custom photo inside the luxury circular badge
      expect(find.byType(ClipOval), findsWidgets);
    });

    testWidgets('MultiplayerOpponentsLayer keeps unoccupied chairs empty when opponents count is less than capacity', (tester) async {
      tester.view.physicalSize = const Size(1754, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Only 1 opponent joined on a 4-player table (which has 3 opponent chairs across the table)
      final singleOpp = TablePlayer(
        uid: 'opp_only_one',
        displayName: 'First Joined Opponent',
        photoURL: 'male_05',
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
                    maxPlayers: 4,
                    opponents: [singleOpp], // Only 1 opponent, 2 chairs empty
                    currentTurnPlayerId: '',
                    dealerPlayerId: '',
                    remainingTurnSeconds: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Exactly 1 opponent pod rendered; other 2 chairs remain completely empty!
      expect(find.byType(MultiplayerOpponentPod), findsNWidgets(1));
    });
  });
}
