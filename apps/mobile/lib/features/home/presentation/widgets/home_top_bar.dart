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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            // Logo / Branding
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                    child: Text('🂡', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 6),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MAYA',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1,
                      ),
                    ),
                    Text(
                      'RUMMY',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Profile / Login Details Chip
            InkWell(
              onTap: () => ProfileModal.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF142E54),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.accent,
                      backgroundImage: (user != null && user.photoURL.isNotEmpty)
                          ? NetworkImage(user.photoURL)
                          : null,
                      child: (user == null || user.photoURL.isEmpty)
                          ? Text(
                              user != null && user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '👤',
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 75),
                      child: Text(
                        user?.displayName ?? 'Sign In',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(width: 4),
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
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Coin Balance Badge
            InkWell(
              onTap: onOpenRewards,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '${homeState.coins}',
                      style: const TextStyle(
                        color: AppColors.textGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.add_circle,
                      color: AppColors.accent,
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Rule Book Button
            IconButton(
              tooltip: 'Rule Book',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 20),
              onPressed: () => RuleBookModal.show(context),
            ),
            const SizedBox(width: 4),

            // Sound Toggle Button
            IconButton(
              tooltip: homeState.soundEnabled ? 'Mute Audio' : 'Unmute Audio',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: Icon(
                homeState.soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: homeState.soundEnabled ? AppColors.textPrimary : AppColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                ref.read(homeProvider.notifier).toggleSound();
              },
            ),
            const SizedBox(width: 4),

            // Settings Button
            IconButton(
              tooltip: 'Settings',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
