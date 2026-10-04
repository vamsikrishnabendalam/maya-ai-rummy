import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/profile_setup_modal.dart';
import '../../../wallet/services/wallet_service.dart';
import '../../../wallet/models/coin_transaction.dart';
import '../../../progression/models/progression_models.dart';

class ProfileModal extends ConsumerWidget {
  const ProfileModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const ProfileModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    final levelInfo = LevelProgression.getLevelInfo(user?.xp ?? 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: levelInfo.tierColor.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: levelInfo.tierColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: levelInfo.tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: levelInfo.tierColor.withValues(alpha: 0.4)),
                    ),
                    child: Icon(
                      Icons.person_pin_rounded,
                      color: levelInfo.tierColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAYER DASHBOARD',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        user != null
                            ? '${user.currentLevel.toUpperCase()} • ${user.coins} COINS'
                            : 'Guest Mode',
                        style: TextStyle(
                          color: levelInfo.tierColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (user?.isAdmin == true)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 16),
                      label: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/admin');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header & Avatar
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: levelInfo.tierColor,
                            backgroundImage: (user != null && user.photoURL.isNotEmpty)
                                ? NetworkImage(user.photoURL)
                                : null,
                            child: (user == null || user.photoURL.isEmpty)
                                ? Text(
                                    user != null && user.displayName.isNotEmpty
                                        ? user.displayName[0].toUpperCase()
                                        : '👤',
                                    style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user?.displayName ?? 'Not Signed In',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (user != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: user.isGuest
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: user.isGuest ? Colors.amberAccent : Colors.greenAccent,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                user.isGuest
                                    ? 'Guest Player • 0 Coins'
                                    : 'Google Verified • ${user.email ?? ""}',
                                style: TextStyle(
                                  color: user.isGuest ? Colors.amberAccent : Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!user.isGuest && !user.isProfileComplete) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                                label: const Text('Complete Profile & Claim 5,000 Coins!'),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  ProfileSetupModal.show(context);
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (user.isGuest) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: const Icon(Icons.g_mobiledata_rounded, size: 20),
                                    label: const Text('Sign in with Google', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      await ref.read(authProvider.notifier).signInWithGoogle();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: const Icon(Icons.logout_rounded, size: 16),
                                  label: const Text('Sign Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    await ref.read(authProvider.notifier).signOut();
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                              ),
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                              label: const Text('Sign in with Google'),
                              onPressed: () async {
                                await ref.read(authProvider.notifier).signInWithGoogle();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Level Progression Bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: levelInfo.tierColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${levelInfo.subLevel.toUpperCase()} (Level ${levelInfo.levelIndex}/20)',
                                style: TextStyle(
                                  color: levelInfo.tierColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${levelInfo.currentXP} / ${levelInfo.nextLevelXP} XP',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: levelInfo.progressPercent,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(levelInfo.tierColor),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Career Summary Grid (Real Metrics!)
                    const Text(
                      'CAREER METRICS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.3,
                      children: [
                        _buildMetricCard('Total Matches', '${user?.gamesPlayed ?? 0}', Icons.sports_esports_rounded),
                        _buildMetricCard('Victories', '${user?.gamesWon ?? 0}', Icons.emoji_events_rounded),
                        _buildMetricCard('Win Rate', user?.winRateFormatted ?? '—', Icons.pie_chart_rounded),
                        _buildMetricCard('Coins Vault', '${user?.coins ?? 0} 🪙', Icons.monetization_on_rounded),
                        _buildMetricCard('Total Score', '${user?.totalScore ?? 0}', Icons.score_rounded),
                        _buildMetricCard('Best Score', '${user?.highestScore ?? 0}', Icons.auto_awesome_rounded),
                        _buildMetricCard('Login Streak', '${user?.loginStreak ?? 1} Days', Icons.local_fire_department_rounded),
                        _buildMetricCard('Country', user?.country ?? 'India', Icons.public_rounded),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent Coin Ledger Transactions
                    if (user != null && !user.isGuest) ...[
                      const Text(
                        'RECENT COIN TRANSACTIONS',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<CoinTransaction>>(
                        stream: WalletService().streamUserTransactions(user.uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
                          }
                          final txs = snapshot.data ?? [];
                          if (txs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: const Color(0xFF081220), borderRadius: BorderRadius.circular(10)),
                              child: const Text('No coin transactions recorded yet.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: txs.length.clamp(0, 5),
                            itemBuilder: (ctx, i) {
                              final tx = txs[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF081220),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      tx.isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                                      color: tx.isCredit ? Colors.greenAccent : Colors.redAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(tx.typeLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text(tx.reason, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${tx.formattedAmount} 🪙',
                                      style: TextStyle(
                                        color: tx.isCredit ? Colors.greenAccent : Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
