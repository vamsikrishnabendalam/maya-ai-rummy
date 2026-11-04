import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/providers/multiplayer_providers.dart';
import 'package:maya_ai_rummy_mobile/features/multiplayer/services/multiplayer_service.dart';

void main() {
  group('Network Resilience & Indicator Tests', () {
    setUp(() {
      MultiplayerService().resetPingForTesting();
    });

    test('NetworkStatus states: Healthy, Degraded, Disconnected', () {
      // 1. Healthy state (< 150ms)
      const healthy = NetworkStatus(pingMs: 45, isOffline: false, pendingActions: 0);
      expect(healthy.isDegraded, isFalse);
      expect(healthy.isDisconnected, isFalse);

      // 2. Degraded state (>= 150ms or pending actions)
      const degradedPing = NetworkStatus(pingMs: 220, isOffline: false, pendingActions: 0);
      expect(degradedPing.isDegraded, isTrue);
      expect(degradedPing.isDisconnected, isFalse);

      const degradedQueue = NetworkStatus(pingMs: 50, isOffline: false, pendingActions: 1);
      expect(degradedQueue.isDegraded, isTrue);
      expect(degradedQueue.isDisconnected, isFalse);

      // 3. Disconnected state (offline or ping >= 600)
      const offline = NetworkStatus(pingMs: 35, isOffline: true, pendingActions: 0);
      expect(offline.isDisconnected, isTrue);

      const hugePing = NetworkStatus(pingMs: 850, isOffline: false, pendingActions: 0);
      expect(hugePing.isDisconnected, isTrue);
    });

    test('MultiplayerService recordPing and setOffline updates smoothing and notifiers', () {
      final service = MultiplayerService();

      expect(service.lastPingMs, 32);
      expect(service.isOffline, isFalse);

      // Record a new ping of 100ms
      service.recordPing(100, offline: false);
      // Smoothed: ((32 * 3) + (100 * 2)) ~/ 5 = (96 + 200) ~/ 5 = 59
      expect(service.lastPingMs, 59);
      expect(service.pingNotifier.value, 59);
      expect(service.isOffline, isFalse);

      // Mark offline
      service.setOffline(true);
      expect(service.isOffline, isTrue);
      expect(service.offlineNotifier.value, isTrue);

      // Reconnect with 40ms ping
      service.recordPing(40, offline: false);
      expect(service.isOffline, isFalse);
      expect(service.offlineNotifier.value, isFalse);
    });

    test('networkStatusProvider emits updated status reactively', () async {
      final service = MultiplayerService();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Subscribe to provider
      final sub = container.listen<AsyncValue<NetworkStatus>>(
        networkStatusProvider,
        (prev, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final initial = await container.read(networkStatusProvider.future);
      expect(initial.pingMs, 32);

      // 500ms ping gives smoothed value of ((32*3) + (500*2)) ~/ 5 = 219ms >= 150ms (Degraded)
      service.recordPing(500, offline: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = container.read(networkStatusProvider).value;
      expect(updated, isNotNull);
      expect(updated!.isDegraded, isTrue);
    });
  });
}
