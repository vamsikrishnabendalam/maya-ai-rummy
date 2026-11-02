import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';

class GameCategorySelector extends ConsumerWidget {
  const GameCategorySelector({super.key});

  static const List<Map<String, String>> categories = [
    {
      'id': 'Points Rummy',
      'label': 'Points',
      'icon': '⚡',
      'subtitle': '1 Deal',
    },
    {
      'id': 'Pool 101',
      'label': '101 Pool',
      'icon': '🎱',
      'subtitle': '101 Limit',
    },
    {
      'id': 'Pool 201',
      'label': '201 Pool',
      'icon': '🏆',
      'subtitle': '201 Limit',
    },
    {
      'id': 'Pool 301',
      'label': '301 Pool',
      'icon': '👑',
      'subtitle': '301 Limit',
    },
    {
      'id': 'Best of 2 Deals',
      'label': 'Best of 2',
      'icon': '⚔️',
      'subtitle': '2 Deals',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final selectedMode = homeState.selectedGameMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B1E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.category_rounded, color: AppColors.accent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'GAME MODE',
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedMode,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedMode == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => ref.read(homeProvider.notifier).setGameMode(cat['id']!),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.glassBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cat['icon']!, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                cat['label']!,
                                style: TextStyle(
                                  color: isSelected ? AppColors.accent : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat['subtitle']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : AppColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

