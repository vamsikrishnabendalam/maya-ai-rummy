import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../progression/models/progression_models.dart';
import '../../providers/home_provider.dart';
import '../widgets/profile_modal.dart';

class PlayerProgressWidget extends ConsumerWidget {
  final bool isHorizontal;

  const PlayerProgressWidget({Key? key, this.isHorizontal = false}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);

    final xp = authUser?.xp ?? homeState.playerXP;
    final levelInfo = LevelProgression.getLevelInfo(xp);

    final playerName = (authUser != null && authUser.displayName.trim().isNotEmpty)
        ? authUser.displayName.trim()
        : 'Player';

    final gamesPlayed = authUser?.gamesPlayed ?? homeState.gamesPlayed;
    final gamesWon = authUser?.gamesWon ?? homeState.gamesWon;
    final winRateText = gamesPlayed > 0 ? '${((gamesWon / gamesPlayed) * 100).toStringAsFixed(1)}%' : '—';

    final currentLevelXP = levelInfo.currentXP - levelInfo.levelMinXP;
    final neededLevelXP = levelInfo.nextLevelXP - levelInfo.levelMinXP;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ProfileModal.show(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar with Tier border
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: levelInfo.tierColor, width: 2),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB300),
                            Color(0xFFFF6F00),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '👤',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and Level
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  playerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: levelInfo.tierColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: levelInfo.tierColor.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  levelInfo.subLevel.toUpperCase(),
                                  style: TextStyle(
                                    color: levelInfo.tierColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // XP Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: levelInfo.progressPercent,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(levelInfo.tierColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lvl ${levelInfo.levelIndex} • $currentLevelXP / $neededLevelXP XP',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'Total: ${levelInfo.currentXP} XP',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.glassBorder, height: 1),
                const SizedBox(height: 10),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Played', '$gamesPlayed'),
                    _buildVerticalDivider(),
                    _buildStatItem('Won', '$gamesWon'),
                    _buildVerticalDivider(),
                    _buildStatItem('Win Rate', winRateText),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.glassBorder,
    );
  }
}
