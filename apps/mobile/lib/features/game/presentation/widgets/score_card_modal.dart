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
  final VoidCallback? onNextDeal;
  final bool isRoundComplete;
  final VoidCallback? onViewLogs;
  final String? gameMode;

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
    this.onNextDeal,
    this.isRoundComplete = false,
    this.onViewLogs,
    this.gameMode,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompactLandscape = size.width > size.height && size.height < 550;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isCompactLandscape ? 8 : 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isCompactLandscape ? 720 : 620,
          maxHeight: isCompactLandscape ? 340 : 540,
        ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header: Title + Player Scores on Right ---
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isCompactLandscape ? 8 : 12,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
                gradient: LinearGradient(
                  colors: [Color(0xFF18261F), Color(0xFF111A15)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'GAME SCORE CARD',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Player Scores moved to the right of header title
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildHeaderScoreBadge(
                            label: 'YOU',
                            score: totalHumanScore,
                            isEliminated: isHumanEliminated,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderScoreBadge(
                            label: 'AI BOT 1',
                            score: totalAiScore,
                            isEliminated: isAiEliminated,
                            color: Colors.blueAccent,
                          ),
                          if (gameMode != null && gameMode!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Text(
                                gameMode!,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ] else if (eliminationScore > 0 && eliminationScore < 900) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(Limit: $eliminationScore pts)',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // --- Compact Round History Table ---
            Expanded(
              child: roundScores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 32, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 6),
                          const Text(
                            'No completed deals yet.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Complete round or drop to see deal history.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      children: [
                        // Small Table Structure Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 55,
                                child: Text(
                                  'ROUND',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
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
                                  'AI BOT 1',
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
                        const SizedBox(height: 4),

                        // Deal / Round Rows
                        ...roundScores.map((round) => _buildCompactTableRow(round)),

                        // Table Summary Row
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2A22),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 55,
                                child: Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '$totalHumanScore pts',
                                  style: TextStyle(
                                    color: isHumanEliminated ? AppColors.danger : AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '$totalAiScore pts',
                                  style: TextStyle(
                                    color: isAiEliminated ? AppColors.danger : Colors.blueAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            // --- Footer: Only Review Table and Next Deal / New Tournament (Reset, Logs, Close removed) ---
            if (onNextDeal != null && !isHumanEliminated && !isAiEliminated)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompactLandscape ? 6 : 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.glassBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Review Table', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.black),
                      label: Text(
                        'Next Deal (#${roundScores.length + 1})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onNextDeal,
                    ),
                  ],
                ),
              )
            else if (isRoundComplete && (isHumanEliminated || isAiEliminated))
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompactLandscape ? 6 : 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.glassBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Review Table', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.black),
                      label: const Text(
                        'New Tournament',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onResetTournament,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderScoreBadge({
    required String label,
    required int score,
    required bool isEliminated,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEliminated
            ? AppColors.danger.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isEliminated ? AppColors.danger : color.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isEliminated ? AppColors.danger : color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: isEliminated ? AppColors.danger : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'pts',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isEliminated) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'OUT',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTableRow(RoundScore round) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(
              '#${round.roundNumber}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  '+${round.humanScore} pts',
                  style: TextStyle(
                    color: round.humanScore == 0 ? AppColors.success : AppColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '(${round.humanOutcome})',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  '+${round.aiScore} pts',
                  style: TextStyle(
                    color: round.aiScore == 0 ? AppColors.success : AppColors.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '(${round.aiOutcome})',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    overflow: TextOverflow.ellipsis,
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
