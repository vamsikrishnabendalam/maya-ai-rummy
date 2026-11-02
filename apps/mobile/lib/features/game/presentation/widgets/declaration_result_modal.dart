import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/round_score.dart';
import 'card_widget.dart';

/// Modal dialog showing declaration outcome with thorough diagnostics and card breakdowns.
class DeclarationResultModal extends StatelessWidget {
  final HandPartitionResult result;
  final Card openJoker;
  final VoidCallback onDismiss;
  final VoidCallback onNewGame;
  final VoidCallback? onViewScoreCard;
  final RoundScore? roundScore;

  const DeclarationResultModal({
    super.key,
    required this.result,
    required this.openJoker,
    required this.onDismiss,
    required this.onNewGame,
    this.onViewScoreCard,
    this.roundScore,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = result.isValidDeclaration;

    return Dialog(
      backgroundColor: AppColors.tableGradientBottom,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isValid ? AppColors.success : AppColors.danger,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isValid ? 'VALID DECLARATION!' : 'INVALID DECLARATION',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isValid ? AppColors.success : AppColors.danger,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Score Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isValid ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isValid ? 'Round Winner — Score: 0 PTS' : 'Penalty Points Applied:',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isValid ? '0 PTS' : '${result.penaltyScore} PTS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isValid ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              if (roundScore != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33D4AF37)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Maya Bot: ${roundScore!.aiScore} PTS (${roundScore!.aiOutcome})',
                        style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                      ),
                      Text(
                        'Totals: You ${roundScore!.cumulativeHumanScore}p • Maya ${roundScore!.cumulativeAiScore}p',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFFEF08A)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Error explanation if invalid
              if (!isValid && result.errorMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    result.errorMessage,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Groups breakdown Header
              const Text(
                'HAND BREAKDOWN:',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Side-by-side Horizontal Hand Groups (Eliminates downward scrolling)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.groups.map((group) {
                    final color = group.isValid
                        ? (group.type == HandGroupType.pureSequence
                            ? AppColors.groupPure
                            : group.type == HandGroupType.impureSequence
                                ? AppColors.groupImpure
                                : AppColors.groupSet)
                        : AppColors.danger;

                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.glass,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                group.isValid ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 12,
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
                              const SizedBox(width: 5),
                              Text(
                                '(${group.cards.length})',
                                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: group.cards.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: CardWidget(
                                card: c,
                                isWildJoker: JokerUtils.isWildJoker(c, openJoker),
                                width: 30,
                                height: 44,
                              ),
                            )).toList(),
                          ),
                          if (group.details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                group.details,
                                style: const TextStyle(fontSize: 8.5, color: AppColors.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onViewScoreCard != null) ...[
                    TextButton.icon(
                      icon: const Icon(Icons.table_chart_outlined, size: 15, color: AppColors.accent),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      ),
    );
  }
}
