import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/hero_section.dart';
import '../widgets/maya_avatar_widget.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/joker_mode_selector.dart';
import '../widgets/play_with_maya_cta.dart';
import '../widgets/game_modes_selector.dart';
import '../widgets/player_progress_widget.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/rewards_modal.dart';
import '../widgets/profile_modal.dart';
import '../../../rules/presentation/rule_book_modal.dart';
import '../../../game/presentation/screens/game_table_screen.dart';
import '../../../game/presentation/widgets/game_settings_modal.dart';
import '../widgets/app_settings_modal.dart';
import 'package:flutter/foundation.dart';
import '../../../game/providers/game_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialModal;
  const HomeScreen({Key? key, this.initialModal}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDirectInviteUrl();
      if (widget.initialModal == 'profile') {
        ProfileModal.show(context);
      } else if (widget.initialModal == 'rewards') {
        RewardsModal.show(context);
      }
    });
  }

  void _checkDirectInviteUrl() {
    if (!kIsWeb) return;
    try {
      final uri = Uri.base;

      // 1. Check query parameters e.g. ?join=CODE or ?room=CODE
      final queryCode = uri.queryParameters['join'] ?? uri.queryParameters['room'];
      if (queryCode != null && queryCode.trim().isNotEmpty) {
        context.go('/join/${queryCode.trim().toUpperCase()}');
        return;
      }

      // 2. Check path segments e.g. /join/CODE or /lobby/CODE
      final segs = uri.pathSegments;
      if (segs.length >= 2 && (segs[0] == 'join' || segs[0] == 'lobby')) {
        context.go('/join/${segs[1].toUpperCase()}');
        return;
      }

      // 3. Check hash fragment e.g. #/join/CODE or #/lobby/CODE
      if (uri.fragment.isNotEmpty) {
        final frag = uri.fragment;
        final match = RegExp(r'/(?:join|lobby)/([A-Za-z0-9]+)').firstMatch(frag);
        if (match != null && match.group(1) != null) {
          context.go('/join/${match.group(1)!.toUpperCase()}');
          return;
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] _checkDirectInviteUrl notice: $e');
    }
  }

  void _launchGame(BuildContext context) {
    final homeState = ref.read(homeProvider);
    final notifier = ref.read(gameTableProvider.notifier);
    notifier.setAILevel(homeState.selectedDifficulty);
    notifier.setJokerMode(homeState.selectedJokerMode);
    notifier.startNewGame();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const GameTableScreen(),
      ),
    );
  }

  void _launchMultiplayer(BuildContext context) {
    context.push('/multiplayer');
  }

  void _openSettings(BuildContext context) {
    AppSettingsModal.show(context);
  }

  void _openMayaGameSettings(BuildContext context) {
    final tableState = ref.read(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) => GameSettingsModal(
        currentSettings: tableState.gameSettings,
        onSave: (newSettings) {
          notifier.updateSettings(newSettings);
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Widget _buildMayaSettingsButton(BuildContext context) {
    final tableState = ref.watch(gameTableProvider);
    final settings = tableState.gameSettings;
    return InkWell(
      onTap: () => _openMayaGameSettings(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF142E54).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Maya AI Game Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Drop: ${settings.firstDropPenalty}/${settings.middleDropPenalty}/${settings.fullCountPenalty} • Elim: ${settings.eliminationScore}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.settings, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _openRewards(BuildContext context) {
    RewardsModal.show(context);
  }

  void _openProfile(BuildContext context) {
    ProfileModal.show(context);
  }

  void _openRules(BuildContext context) {
    RuleBookModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1050;
    final isTablet = size.width >= 700 && size.width < 1050;

    return Scaffold(
      backgroundColor: AppColors.tableGradientTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [
              AppColors.tableGradientBottom,
              AppColors.tableGradientTop,
              Color(0xFF060D18),
            ],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              HomeTopBar(
                onOpenSettings: () => _openSettings(context),
                onOpenRewards: () => _openRewards(context),
              ),

              // Main Responsive Body
              Expanded(
                child: isDesktop
                    ? _buildDesktopLayout(context)
                    : isTablet
                        ? _buildTabletLayout(context)
                        : _buildMobileLayout(context),
              ),

              // Bottom Navigation (shown on mobile / tablet)
              if (!isDesktop)
                HomeBottomNav(
                  currentIndex: homeState.activeBottomNavIndex,
                  onTap: (index) {
                    ref.read(homeProvider.notifier).setBottomNavIndex(index);
                    switch (index) {
                      case 0:
                        // Already Home
                        break;
                      case 1:
                        _launchGame(context);
                        break;
                      case 2:
                        _openRules(context);
                        break;
                      case 3:
                        _openRewards(context);
                        break;
                      case 4:
                        _openProfile(context);
                        break;
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOBILE LAYOUT (< 700px) ---
  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          const HeroSection(isCompact: true),
          const SizedBox(height: 16),
          const MayaAvatarWidget(),
          const SizedBox(height: 18),
          PlayWithMayaCTA(
            onPressed: () => _launchGame(context),
          ),
          const SizedBox(height: 14),
          const JokerModeSelector(),
          const SizedBox(height: 16),
          const DifficultySelector(isCompact: true),
          const SizedBox(height: 12),
          _buildMayaSettingsButton(context),
          const SizedBox(height: 18),
          const DailyChallengeCard(),
          const SizedBox(height: 18),
          GameModesSelector(
            onSelectAI: () => _launchGame(context),
            onSelectFriends: () => _launchMultiplayer(context),
          ),
          const SizedBox(height: 18),
          const PlayerProgressWidget(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- TABLET LAYOUT (700px - 1050px) ---
  Widget _buildTabletLayout(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const HeroSection(isCompact: false),
          const SizedBox(height: 20),
          const MayaAvatarWidget(isHorizontal: true),
          const SizedBox(height: 20),
          SizedBox(
            width: 380,
            child: PlayWithMayaCTA(
              onPressed: () => _launchGame(context),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(
            width: 380,
            child: JokerModeSelector(),
          ),
          const SizedBox(height: 18),
          const DifficultySelector(isCompact: false),
          const SizedBox(height: 14),
          SizedBox(
            width: 380,
            child: _buildMayaSettingsButton(context),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GameModesSelector(
                  onSelectAI: () => _launchGame(context),
                  onSelectFriends: () => _launchMultiplayer(context),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  children: [
                    DailyChallengeCard(),
                    SizedBox(height: 16),
                    PlayerProgressWidget(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- DESKTOP LAYOUT (>= 1050px) ---
  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1350),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Maya AI & Play Action
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          children: [
                            const MayaAvatarWidget(),
                            const SizedBox(height: 16),
                            PlayWithMayaCTA(
                              onPressed: () => _launchGame(context),
                            ),
                            const SizedBox(height: 14),
                            const JokerModeSelector(),
                            const SizedBox(height: 16),
                            const DifficultySelector(isCompact: true),
                            const SizedBox(height: 14),
                            _buildMayaSettingsButton(context),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quick Rule Card shortcut
                      InkWell(
                        onTap: () => _openRules(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.glass,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rummy Rule Book',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Review Pure Sequences & Jokers',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Center Column: Hero Branding & Modes
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const HeroSection(isCompact: false),
                      const SizedBox(height: 28),
                      GameModesSelector(
                        onSelectAI: () => _launchGame(context),
                        onSelectFriends: () => _launchMultiplayer(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right Column: Progress, Challenge, Vault
              const Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      PlayerProgressWidget(),
                      SizedBox(height: 16),
                      DailyChallengeCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
