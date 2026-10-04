import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';

class DifficultySelector extends ConsumerWidget {
  final bool isCompact;

  const DifficultySelector({Key? key, this.isCompact = false}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final selectedLevel = homeState.selectedDifficulty;

    final options = [
      _DifficultyOption(
        level: AILevel.beginner,
        title: 'EASY',
        stars: 1,
        subtitle: 'Maya is learning. Relaxed play with simple strategies.',
        icon: Icons.sentiment_satisfied_alt_rounded,
        tagColor: Colors.tealAccent,
      ),
      _DifficultyOption(
        level: AILevel.intermediate,
        title: 'MEDIUM',
        stars: 2,
        subtitle: 'Maya plays smart. Balanced sequences & tactical discards.',
        icon: Icons.psychology_rounded,
        tagColor: AppColors.accent,
      ),
      _DifficultyOption(
        level: AILevel.advanced,
        title: 'HARD',
        stars: 3,
        subtitle: 'Maya plays to win. 40+ Monte Carlo rollouts & defensive play.',
        icon: Icons.local_fire_department_rounded,
        tagColor: Colors.deepOrangeAccent,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.accent, size: 16),
                SizedBox(width: 6),
                Text(
                  'SELECT DIFFICULTY',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getDifficultyName(selectedLevel),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isCompact)
          // Vertical stack for compact mobile
          Column(
            children: options.map((opt) {
              final isSelected = selectedLevel == opt.level;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildDifficultyCard(
                  context,
                  ref,
                  opt,
                  isSelected,
                  isCompact: true,
                ),
              );
            }).toList(),
          )
        else
          // Horizontal row for tablet / desktop
          Row(
            children: options.map((opt) {
              final isSelected = selectedLevel == opt.level;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _buildDifficultyCard(
                    context,
                    ref,
                    opt,
                    isSelected,
                    isCompact: false,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    WidgetRef ref,
    _DifficultyOption opt,
    bool isSelected, {
    required bool isCompact,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF142744) : AppColors.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.glassBorder,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(homeProvider.notifier).setDifficulty(opt.level);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isCompact ? 10 : 14,
            ),
            child: isCompact
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: opt.tagColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(opt.icon, color: opt.tagColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt.title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStars(opt.stars),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt.subtitle,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCheckIndicator(isSelected),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: opt.tagColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(opt.icon, color: opt.tagColor, size: 18),
                          ),
                          _buildCheckIndicator(isSelected),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        opt.title,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStars(opt.stars),
                      const SizedBox(height: 6),
                      Text(
                        opt.subtitle,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckIndicator(bool isSelected) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.accent : Colors.transparent,
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.glassBorder,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.black)
          : null,
    );
  }

  Widget _buildStars(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 13,
          color: i < count ? AppColors.accent : AppColors.textMuted,
        );
      }),
    );
  }

  String _getDifficultyName(AILevel level) {
    switch (level) {
      case AILevel.beginner:
        return 'EASY';
      case AILevel.advanced:
      case AILevel.expert:
        return 'HARD';
      case AILevel.intermediate:
        return 'MEDIUM';
    }
  }
}

class _DifficultyOption {
  final AILevel level;
  final String title;
  final int stars;
  final String subtitle;
  final IconData icon;
  final Color tagColor;

  _DifficultyOption({
    required this.level,
    required this.title,
    required this.stars,
    required this.subtitle,
    required this.icon,
    required this.tagColor,
  });
}
