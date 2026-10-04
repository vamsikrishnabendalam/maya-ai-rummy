import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Compact score and round indicator anchored at the bottom-left of the gameplay area.
/// Distinguishes between active hand score (deadwood) and total cumulative game score.
class ScoreBottomLeft extends StatelessWidget {
  final int handScore;
  final int totalGameScore;
  final int roundNumber;
  final int opponentTotalScore;
  final int targetScore;
  final bool isDealer;
  final VoidCallback? onTapScoreCard;

  const ScoreBottomLeft({
    super.key,
    required this.handScore,
    required this.totalGameScore,
    this.roundNumber = 1,
    this.opponentTotalScore = 0,
    this.targetScore = 201,
    this.isDealer = false,
    this.onTapScoreCard,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapScoreCard,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.glass,
          border: Border.all(color: AppColors.glassBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'HAND SCORE: ',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '$handScore PTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: handScore == 0 ? AppColors.success : AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isDealer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: const Text(
                          '🅳 DEALER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL: $totalGameScore / $targetScore',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deal $roundNumber',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Bot: $opponentTotalScore',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_chart_outlined,
                size: 14,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
