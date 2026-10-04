import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../rewards/services/rewards_service.dart';
import '../../../progression/models/progression_models.dart';
import '../../../progression/services/progression_service.dart';

class RewardsModal extends ConsumerStatefulWidget {
  const RewardsModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const RewardsModal(),
    );
  }

  @override
  ConsumerState<RewardsModal> createState() => _RewardsModalState();
}

class _RewardsModalState extends ConsumerState<RewardsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isClaiming = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleClaimDailyReward(String uid) async {
    setState(() {
      _isClaiming = true;
      _statusMessage = null;
    });

    try {
      final res = await RewardsService().claimDailyReward(uid);
      if (mounted) {
        setState(() {
          _isClaiming = false;
          _statusMessage = 'Claimed Day ${res['day']} Bonus: +${res['coins']} Coins & +${res['xp']} XP! 🪙';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isClaiming = false;
          _statusMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final levelInfo = LevelProgression.getLevelInfo(user?.xp ?? 0);
    final today = RewardsService.getTodayUtcString();
    final isClaimedToday = user?.lastRewardDate == today;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REWARD & PROGRESSION CENTER',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        user != null ? '${user.coins} Virtual Coins • ${levelInfo.subLevel}' : 'Sign in to earn rewards',
                        style: const TextStyle(color: AppColors.textGold, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_today_rounded, size: 16), text: 'DAILY REWARDS'),
                Tab(icon: Icon(Icons.military_tech_rounded, size: 16), text: 'LEVELS (20)'),
                Tab(icon: Icon(Icons.emoji_events_rounded, size: 16), text: 'ACHIEVEMENTS'),
              ],
            ),
            const Divider(color: AppColors.glassBorder, height: 1),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Daily Login Rewards
                  _buildDailyRewardsTab(user, isClaimedToday),

                  // Tab 2: Level Progression (20 levels)
                  _buildLevelsTab(levelInfo),

                  // Tab 3: Achievements (14 Real Achievements)
                  _buildAchievementsTab(user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DAILY REWARDS ---
  Widget _buildDailyRewardsTab(dynamic user, bool isClaimedToday) {
    final streak = user?.loginStreak ?? 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3A60), Color(0xFF0F2643)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day $streak Login Streak',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Login daily to advance your streak and earn up to 750 coins on Day 7!',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClaimedToday ? Colors.grey.shade700 : AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: (_isClaiming || isClaimedToday || user == null || user.isGuest)
                      ? null
                      : () => _handleClaimDailyReward(user.uid),
                  child: _isClaiming
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          isClaimedToday ? 'CLAIMED' : 'CLAIM TODAY',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                ),
              ],
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
              ),
              child: Text(_statusMessage!, style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 20),

          const Text(
            '7-DAY REWARD CYCLE',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: RewardsService.schedule.length,
            itemBuilder: (ctx, i) {
              final tier = RewardsService.schedule[i];
              final isCurrent = streak == tier.day;
              final isPast = streak > tier.day;

              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : (isPast ? const Color(0xFF14243B) : const Color(0xFF081220)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? AppColors.accent : (isPast ? Colors.green.withValues(alpha: 0.5) : Colors.white12),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Day ${tier.day}', style: TextStyle(color: isCurrent ? AppColors.accent : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(tier.isBonus ? '🏆' : '🪙', style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('+${tier.coins}', style: const TextStyle(color: AppColors.textGold, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('+${tier.xp} XP', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- TAB 2: LEVEL PROGRESSION (20 LEVELS) ---
  Widget _buildLevelsTab(LevelInfo current) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: LevelProgression.thresholds.length,
      itemBuilder: (ctx, i) {
        final t = LevelProgression.thresholds[i];
        final isUnlocked = current.currentXP >= t.requiredXP;
        final isCurrent = current.levelIndex == t.levelIndex;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? LevelProgression.getTierColor(t.tier).withValues(alpha: 0.15)
                : (isUnlocked ? const Color(0xFF14243B) : const Color(0xFF081220)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? LevelProgression.getTierColor(t.tier)
                  : (isUnlocked ? Colors.white24 : Colors.white10),
              width: isCurrent ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: LevelProgression.getTierColor(t.tier).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: LevelProgression.getTierColor(t.tier), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${t.levelIndex}',
                    style: TextStyle(
                      color: LevelProgression.getTierColor(t.tier),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.subLevel,
                      style: TextStyle(
                        color: isUnlocked ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${t.requiredXP} Required XP',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LevelProgression.getTierColor(t.tier),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CURRENT', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                )
              else if (isUnlocked)
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18)
              else
                const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 18),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: 14 REAL ACHIEVEMENTS ---
  Widget _buildAchievementsTab(dynamic user) {
    if (user == null || user.isGuest) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Please sign in with Google to view and claim achievements.', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return StreamBuilder<List<UserAchievement>>(
      stream: ProgressionService().streamUserAchievements(user.uid),
      builder: (context, snapshot) {
        final userAchMap = {for (final a in (snapshot.data ?? [])) a.achievementId: a};

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: AchievementDefinition.all.length,
          itemBuilder: (ctx, i) {
            final def = AchievementDefinition.all[i];
            final userAch = userAchMap[def.id];
            final isCompleted = userAch?.completed ?? false;
            final currentProgress = userAch?.progress ?? 0;
            final progressPercent = def.target > 0 ? (currentProgress / def.target).clamp(0.0, 1.0) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF14243B) : const Color(0xFF081220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isCompleted ? AppColors.accent.withValues(alpha: 0.4) : Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.accent.withValues(alpha: 0.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(def.icon, color: isCompleted ? AppColors.accent : Colors.white38, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(def.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('+${def.coinReward} 🪙 • +${def.xpReward} XP', style: const TextStyle(color: AppColors.textGold, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(def.description, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.greenAccent : AppColors.accent),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isCompleted ? 'COMPLETED' : '$currentProgress / ${def.target}',
                          style: TextStyle(
                            color: isCompleted ? Colors.greenAccent : Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
