import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class GameModesSelector extends StatelessWidget {
  final VoidCallback onSelectAI;
  final VoidCallback? onSelectFriends;

  const GameModesSelector({
    Key? key,
    required this.onSelectAI,
    this.onSelectFriends,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.style_rounded, color: AppColors.accent, size: 16),
            SizedBox(width: 6),
            Text(
              'GAME MODES',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _buildModeCard(
              title: 'Maya AI Solo',
              description: '1v1 Practice & Ranked against Maya',
              icon: Icons.smart_toy_rounded,
              tag: 'ACTIVE',
              isAvailable: true,
              color: AppColors.accent,
              onTap: onSelectAI,
            ),
            _buildModeCard(
              title: 'Play Friends',
              description: 'Private online table (2-6 players)',
              icon: Icons.group_rounded,
              tag: 'ONLINE',
              isAvailable: true,
              color: Colors.blueAccent,
              onTap: onSelectFriends,
            ),
            _buildModeCard(
              title: 'Multiplayer',
              description: 'Quick matchmaking with 2-6 players',
              icon: Icons.public_rounded,
              tag: 'SOON',
              isAvailable: false,
              color: Colors.purpleAccent,
            ),
            _buildModeCard(
              title: 'Tournaments',
              description: 'Daily pool brackets & mega coins',
              icon: Icons.emoji_events_rounded,
              tag: 'SOON',
              isAvailable: false,
              color: Colors.amberAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required String tag,
    required bool isAvailable,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.65,
      child: Container(
        decoration: BoxDecoration(
          color: isAvailable ? const Color(0xFF142744) : AppColors.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAvailable ? AppColors.accent.withValues(alpha: 0.6) : AppColors.glassBorder,
            width: isAvailable ? 1.5 : 1,
          ),
          boxShadow: isAvailable
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () {},
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: color, size: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.groupPure.withValues(alpha: 0.2)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAvailable ? AppColors.groupPure : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: isAvailable ? AppColors.groupPure : AppColors.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }
}
