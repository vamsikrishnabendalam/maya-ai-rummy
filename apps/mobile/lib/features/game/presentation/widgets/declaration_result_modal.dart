import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import 'card_widget.dart';

/// Modal dialog showing declaration outcome with thorough diagnostics and card breakdowns.
class DeclarationResultModal extends StatelessWidget {
  final HandPartitionResult result;
  final Card openJoker;
  final VoidCallback onDismiss;
  final VoidCallback onNewGame;
  final VoidCallback? onViewScoreCard;

  const DeclarationResultModal({
    super.key,
    required this.result,
    required this.openJoker,
    required this.onDismiss,
    required this.onNewGame,
    this.onViewScoreCard,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = result.isValidDeclaration;

    return Dialog(
      backgroundColor: AppColors.tableGradientBottom,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isValid ? AppColors.success : AppColors.danger,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Icon & Title
            Row(
              children: [
                Icon(
                  isValid ? Icons.verified : Icons.error_outline,
                  color: isValid ? AppColors.success : AppColors.danger,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isValid ? 'VALID DECLARATION!' : 'INVALID DECLARATION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isValid ? AppColors.success : AppColors.danger,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Score Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isValid ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isValid ? 'Round Winner — Score: 0 PTS' : 'Penalty Points Applied:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    isValid ? '0 PTS' : '${result.penaltyScore} PTS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isValid ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Error explanation if invalid
            if (!isValid && result.errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  result.errorMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

            // Groups breakdown
            const Text(
              'HAND BREAKDOWN:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: result.groups.map((group) {
                    final color = group.isValid
                        ? (group.type == HandGroupType.pureSequence
                            ? AppColors.groupPure
                            : group.type == HandGroupType.impureSequence
                                ? AppColors.groupImpure
                                : AppColors.groupSet)
                        : AppColors.danger;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                group.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 14,
                                color: color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${group.cards.length} cards',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: group.cards.map((c) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: CardWidget(
                                  card: c,
                                  isWildJoker: JokerUtils.isWildJoker(c, openJoker),
                                  width: 32,
                                  height: 48,
                                ),
                              )).toList(),
                            ),
                          ),
                          if (group.details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              group.details,
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                if (onViewScoreCard != null) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.accent),
                    label: const Text(
                      'Scorecard',
                      style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onViewScoreCard,
                  ),
                  const Spacer(),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onDismiss,
                  child: Text(isValid ? 'Review Table' : 'Continue', style: const TextStyle(fontSize: 11)),
                ),
                if (isValid) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.black),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onNewGame,
                    label: const Text('Next Deal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
