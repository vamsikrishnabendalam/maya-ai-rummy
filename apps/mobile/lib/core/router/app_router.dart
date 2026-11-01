import 'package:go_router/go_router.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/game/presentation/screens/game_table_screen.dart';
import '../../features/multiplayer/presentation/screens/multiplayer_hub_screen.dart';
import '../../features/multiplayer/presentation/screens/multiplayer_lobby_screen.dart';
import '../../features/multiplayer/presentation/screens/multiplayer_table_screen.dart';
import '../../features/multiplayer/presentation/screens/join_redirect_screen.dart';
import '../../features/multiplayer/presentation/screens/multiplayer_2p_preview_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const HomeScreen(initialModal: 'profile'),
    ),
    GoRoute(
      path: '/rewards',
      builder: (context, state) => const HomeScreen(initialModal: 'rewards'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/play-ai',
      builder: (context, state) => const GameTableScreen(),
    ),
    GoRoute(
      path: '/multiplayer',
      builder: (context, state) => const MultiplayerHubScreen(),
    ),
    GoRoute(
      path: '/lobby/:roomCode',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode'] ?? '';
        return MultiplayerLobbyScreen(roomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/join/:roomCode',
      builder: (context, state) {
        final roomCode = state.pathParameters['roomCode'] ?? '';
        return JoinRedirectScreen(roomCode: roomCode);
      },
    ),
    GoRoute(
      path: '/table/:gameId',
      builder: (context, state) {
        final gameId = state.pathParameters['gameId'] ?? '';
        return MultiplayerTableScreen(gameId: gameId);
      },
    ),
    GoRoute(
      path: '/multiplayer-2p-preview',
      builder: (context, state) => const Multiplayer2PPreviewScreen(initialCapacity: 2),
    ),
    GoRoute(
      path: '/multiplayer-3p-preview',
      builder: (context, state) => const Multiplayer2PPreviewScreen(initialCapacity: 3),
    ),
    GoRoute(
      path: '/multiplayer-4p-preview',
      builder: (context, state) => const Multiplayer2PPreviewScreen(initialCapacity: 4),
    ),
    GoRoute(
      path: '/multiplayer-5p-preview',
      builder: (context, state) => const Multiplayer2PPreviewScreen(initialCapacity: 5),
    ),
    GoRoute(
      path: '/multiplayer-6p-preview',
      builder: (context, state) => const Multiplayer2PPreviewScreen(initialCapacity: 6),
    ),
  ],
);
