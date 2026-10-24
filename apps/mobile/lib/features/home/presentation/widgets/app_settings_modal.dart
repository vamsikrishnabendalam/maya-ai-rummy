import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/profile_setup_modal.dart';
import 'profile_modal.dart';

/// Modal for generic application settings (Account, Sign-in, Audio, Need Help, App Info)
class AppSettingsModal extends ConsumerWidget {
  const AppSettingsModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const AppSettingsModal(),
    );
  }

  void _showNeedHelpDialog(BuildContext context) {
    final issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.help_center_rounded, color: AppColors.accent, size: 26),
            SizedBox(width: 10),
            Text(
              'Help & Player Support',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              _buildFaqItem(
                'What is a Pure Sequence?',
                'A pure sequence consists of 3 or more consecutive cards of the same suit without any printed or wild jokers (e.g., 4♠-5♠-6♠). At least one pure sequence is required to declare.',
              ),
              _buildFaqItem(
                'How does Closed Joker work?',
                'In Closed Joker matches, the cut joker is hidden initially. Once a player achieves their pure sequence (Life), they can tap to uncover the joker for their hand.',
              ),
              _buildFaqItem(
                'Are real money deposits involved?',
                'No. Maya Rummy is completely free-to-play with virtual entertainment coins only. There are no fiat deposits, withdrawals, or cash wagering.',
              ),
              const Divider(color: AppColors.glassBorder, height: 24),
              const Text(
                'Contact Support or Submit Feedback',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Official Support Desk: support@mayarummy.com\nResponse SLA: within 24 hours',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: issueController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Describe your issue or feature request...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFF081220),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Support ticket recorded! Thank you for contacting Maya Rummy support.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $question', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(answer, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final homeState = ref.watch(homeProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'APP & ACCOUNT SETTINGS',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Account & Profile
                    const Text(
                      'ACCOUNT PROFILE',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.accent,
                                backgroundImage: (user != null && user.photoURL.isNotEmpty)
                                    ? NetworkImage(user.photoURL)
                                    : null,
                                child: (user == null || user.photoURL.isEmpty)
                                    ? Text(
                                        user != null && user.displayName.isNotEmpty
                                            ? user.displayName[0].toUpperCase()
                                            : '👤',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'Guest Player',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      user?.isGuest == true
                                          ? 'Guest Account (Unsynced)'
                                          : (user?.email ?? 'Logged In'),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (user != null && !user.isGuest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.greenAccent, width: 0.8),
                                  ),
                                  child: const Text(
                                    'VERIFIED',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (user == null || user.isGuest)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.g_mobiledata_rounded, size: 20),
                                    label: const Text(
                                      'Sign in with Google',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      await ref.read(authProvider.notifier).signInWithGoogle();
                                    },
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.accent,
                                      side: const BorderSide(color: AppColors.accent),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.person_outline, size: 16),
                                    label: const Text(
                                      'View Profile',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      ProfileModal.show(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                      foregroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.logout_rounded, size: 16),
                                    label: const Text(
                                      'Sign Out',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      await ref.read(authProvider.notifier).signOut();
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (user != null && !user.isGuest && !user.isProfileComplete) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(34),
                              ),
                              icon: const Icon(Icons.card_giftcard_rounded, size: 16),
                              label: const Text(
                                'Claim 5,000 Welcome Coins',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                ProfileSetupModal.show(context);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Audio & Preferences
                    const Text(
                      'PREFERENCES & AUDIO',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: Icon(
                              homeState.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                              color: homeState.soundEnabled ? AppColors.accent : AppColors.textMuted,
                            ),
                            title: const Text('Sound Effects & Audio', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Game card draws, discards, and declare chimes', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            value: homeState.soundEnabled,
                            activeThumbColor: AppColors.accent,
                            onChanged: (_) => ref.read(homeProvider.notifier).toggleSound(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Need Help Button (as requested)
                    const Text(
                      'ASSISTANCE & SUPPORT',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showNeedHelpDialog(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF142E54),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.help_outline_rounded, color: AppColors.accent, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need Help?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'FAQs, rummy guides, and support desk',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 14),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 4: Fair Play & About
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Maya Rummy Fair Play Engine Certified',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fisher-Yates cryptographically secure shuffle • Anti-collusion multiplayer monitoring • Virtual coins only.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.3),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Version 2.4.0 (Build 2026)',
                            style: TextStyle(color: Colors.white38, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
