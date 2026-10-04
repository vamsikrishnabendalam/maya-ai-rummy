import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Compact horizontal bar with glass-morphic styling displaying player scores,
/// current round number, and target score.
class ScorePanel extends StatelessWidget {
  /// The human player's current score.
  final int humanScore;

  /// The AI opponent's current score.
  final int aiScore;

  /// The current game round number.
  final int roundNumber;

  /// The target score for game end.
  final int targetScore;

  const ScorePanel({
    super.key,
    required this.humanScore,
    required this.aiScore,
    this.roundNumber = 1,
    this.targetScore = 101,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.glass,
        border: Border.all(color: AppColors.glassBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScoreItem(
            label: 'YOU',
            value: humanScore,
            color: AppColors.success,
          ),
          const _VerticalDivider(),
          _ScoreItem(
            label: 'BOT',
            value: aiScore,
            color: AppColors.danger,
          ),
          const _VerticalDivider(),
          _InfoItem(
            label: 'ROUND',
            value: '$roundNumber',
          ),
          const _VerticalDivider(),
          _InfoItem(
            label: 'TARGET',
            value: '$targetScore',
          ),
        ],
      ),
    );
  }
}

/// Displays a labeled score metric with prominent colored text.
class _ScoreItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScoreItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Displays a labeled round or target info item.
class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Thin vertical separator between score and info items.
class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0x33FFFFFF),
    );
  }
}
