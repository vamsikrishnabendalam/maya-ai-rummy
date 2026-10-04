import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/round_score.dart';

/// Interactive modal displaying tournament score card, deal history, and player elimination status.
class ScoreCardModal extends StatelessWidget {
  final List<RoundScore> roundScores;
  final int totalHumanScore;
  final int totalAiScore;
  final int eliminationScore;
  final bool isHumanEliminated;
  final bool isAiEliminated;
  final VoidCallback onClose;
  final VoidCallback onResetTournament;

  const ScoreCardModal({
    super.key,
    required this.roundScores,
    required this.totalHumanScore,
    required this.totalAiScore,
    required this.eliminationScore,
    required this.isHumanEliminated,
    required this.isAiEliminated,
    required this.onClose,
    required this.onResetTournament,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFF141E18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // --- Header ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: AppColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'GAME SCORE CARD',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // --- Elimination Limit Rule Banner ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.glass,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Elimination Threshold: $eliminationScore pts (Player with > ${eliminationScore - 1} pts is eliminated)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // --- Player Summary Cards ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildPlayerSummary(
                      name: 'YOU',
                      totalScore: totalHumanScore,
                      eliminationScore: eliminationScore,
                      isEliminated: isHumanEliminated,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPlayerSummary(
                      name: 'AI BOT 1',
                      totalScore: totalAiScore,
                      eliminationScore: eliminationScore,
                      isEliminated: isAiEliminated,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),

            // --- Deal / Round History Table ---
            Expanded(
              child: roundScores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 36, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text(
                            'No completed deals yet.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Complete the current round or drop to see round history.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  'DEAL',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'YOU',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'AI BOT',
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...roundScores.map((round) => _buildRoundRow(round)),
                      ],
                    ),
            ),

            // --- Footer Actions ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.danger),
                    label: const Text(
                      'Reset Tournament',
                      style: TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                    onPressed: onResetTournament,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSummary({
    required String name,
    required int totalScore,
    required int eliminationScore,
    required bool isEliminated,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEliminated ? AppColors.danger : color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isEliminated ? AppColors.danger : AppColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isEliminated ? 'ELIMINATED' : 'ACTIVE',
                  style: TextStyle(
                    color: isEliminated ? Colors.white : AppColors.success,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalScore',
                style: TextStyle(
                  color: isEliminated ? AppColors.danger : AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $eliminationScore PTS',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundRow(RoundScore round) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '#${round.roundNumber}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${round.humanScore} pts (Total: ${round.cumulativeHumanScore})',
                  style: TextStyle(
                    color: round.humanScore == 0 ? AppColors.success : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  round.humanOutcome,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${round.aiScore} pts (Total: ${round.cumulativeAiScore})',
                  style: TextStyle(
                    color: round.aiScore == 0 ? AppColors.success : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  round.aiOutcome,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
