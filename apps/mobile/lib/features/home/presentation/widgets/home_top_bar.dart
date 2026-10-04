import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';
import '../../../rules/presentation/rule_book_modal.dart';
import '../../../auth/providers/auth_provider.dart';
import 'profile_modal.dart';

class HomeTopBar extends ConsumerWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenRewards;

  const HomeTopBar({
    Key? key,
    required this.onOpenSettings,
    required this.onOpenRewards,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final user = ref.watch(authProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Logo / Branding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD54F),
                      AppColors.accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🂡', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAYA',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      height: 1,
                    ),
                  ),
                  Text(
                    'RUMMY',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Profile / Login Details Chip
          InkWell(
            onTap: () => ProfileModal.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF142E54),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.accent,
                    backgroundImage: (user != null && user.photoURL.isNotEmpty)
                        ? NetworkImage(user.photoURL)
                        : null,
                    child: (user == null || user.photoURL.isEmpty)
                        ? Text(
                            user != null && user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '👤',
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 85),
                    child: Text(
                      user?.displayName ?? 'Sign In',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: user.isGuest
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.isGuest ? 'GUEST' : 'USER',
                        style: TextStyle(
                          color: user.isGuest ? Colors.amberAccent : Colors.greenAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Coin Balance Badge
          InkWell(
            onTap: onOpenRewards,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    '${homeState.coins}',
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.add_circle,
                    color: AppColors.accent,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Rule Book Button
          IconButton(
            tooltip: 'Rule Book',
            icon: const Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 22),
            onPressed: () => RuleBookModal.show(context),
          ),

          // Sound Toggle Button
          IconButton(
            tooltip: homeState.soundEnabled ? 'Mute Audio' : 'Unmute Audio',
            icon: Icon(
              homeState.soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: homeState.soundEnabled ? AppColors.textPrimary : AppColors.textMuted,
              size: 22,
            ),
            onPressed: () {
              ref.read(homeProvider.notifier).toggleSound();
            },
          ),

          // Settings Button
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary, size: 22),
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}
