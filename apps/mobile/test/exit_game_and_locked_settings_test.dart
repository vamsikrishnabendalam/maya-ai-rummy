import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_ai_rummy_mobile/features/game/models/game_settings.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/widgets/game_settings_modal.dart';
import 'package:maya_ai_rummy_mobile/features/game/presentation/screens/game_table_screen.dart';
import 'package:maya_ai_rummy_mobile/features/game/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exit Game & Locked Settings Tests', () {
    testWidgets('GameSettingsModal in isReadOnly=true mode displays locked banner and disabled controls', (tester) async {
      const settings = GameSettings(
        firstDropPenalty: 20,
        middleDropPenalty: 40,
        fullCountPenalty: 80,
        eliminationScore: 201,
        jokerMode: 'OPEN',
        turnTimerSeconds: 30,
      );

      var wasSaved = false;
      var wasClosed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameSettingsModal(
              currentSettings: settings,
              isReadOnly: true,
              onSave: (_) => wasSaved = true,
              onClose: () => wasClosed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('TABLE RULES (LOCKED)'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      // Check Read-Only Banner
      expect(
        find.text('Tournament in progress. Settings cannot be edited after the tournament starts.'),
        findsOneWidget,
      );

      // Save button should NOT be present; Close button should be present
      expect(find.text('Save & Apply'), findsNothing);
      expect(find.text('Close'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(wasClosed, isTrue);
      expect(wasSaved, isFalse);
    });

    testWidgets('GameTableScreen top bar does NOT contain back arrow and DOES contain Exit button', (tester) async {
      final container = ProviderContainer();
      addTearDown(() {
        container.read(gameTableProvider.notifier).cancelTurnTimer();
        container.dispose();
      });

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GameTableScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Back arrow icon should NOT be in top HUD bar
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // 1st: 20p • Mid: 40p container should NOT be present
      expect(find.textContaining('1st: 20p • Mid: 40p'), findsNothing);

      // Exit button should be present
      expect(find.text('Exit'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Tap Exit button to trigger confirmation dialog
      await tester.tap(find.text('Exit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirmation dialog should be displayed
      expect(find.text('Exit Game?'), findsOneWidget);
      expect(find.text('Stay & Play'), findsOneWidget);
      expect(find.text('Exit to Lobby'), findsOneWidget);

      // Cancel exit
      await tester.tap(find.text('Stay & Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Exit Game?'), findsNothing);

      container.read(gameTableProvider.notifier).cancelTurnTimer();
    });
  });
}
