import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Contextual turn indicator displaying player status, guidance messages,
/// and smooth animated transitions.
class TurnIndicator extends StatelessWidget {
  /// Whether it is currently the human player's turn.
  final bool isHumanTurn;

  /// Whether the game is currently in the draw phase.
  final bool isDrawPhase;

  /// Whether the game is currently in the discard phase.
  final bool isDiscardPhase;

  /// Whether the game has finished.
  final bool isGameComplete;

  /// Whether the player has already drawn a card during this turn.
  final bool hasDrawnThisTurn;

  /// Whether the player currently has a card selected.
  final bool hasSelectedCard;

  /// Whether the opponent (Maya Bot) declared show and human is rearranging cards before submission.
  final bool isAwaitingDeclarationShow;

  /// Current turn number of the active deal (0 = first turn).
  final int turnNumber;

  const TurnIndicator({
    super.key,
    required this.isHumanTurn,
    required this.isDrawPhase,
    required this.isDiscardPhase,
    this.isGameComplete = false,
    this.hasDrawnThisTurn = false,
    this.hasSelectedCard = false,
    this.isAwaitingDeclarationShow = false,
    this.turnNumber = 0,
  });

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            status.icon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              status.text,
              key: ValueKey<String>(status.text),
              style: TextStyle(
                color: status.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TurnStatus _resolveStatus() {
    if (isAwaitingDeclarationShow) {
      return const _TurnStatus(
        icon: '🤖',
        text: 'Maya Bot Declared Show! Rearrange cards to reduce count, then tap SUBMIT SHOW',
        color: AppColors.accent,
      );
    }
    if (isGameComplete) {
      return const _TurnStatus(
        icon: '🏆',
        text: 'Game Over!',
        color: AppColors.accent,
      );
    }
    if (isHumanTurn && isDrawPhase) {
      if (turnNumber == 0) {
        return const _TurnStatus(
          icon: '🎯',
          text: 'Your Turn — Pick First Open Card or Draw Closed Deck',
          color: AppColors.accent,
        );
      }
      return const _TurnStatus(
        icon: '🎯',
        text: 'Your Turn — Tap deck or pile to draw',
        color: AppColors.accent,
      );
    }
    if (isHumanTurn && isDiscardPhase) {
      if (hasSelectedCard) {
        return const _TurnStatus(
          icon: '👉',
          text: 'Card selected — Click DISCARD to finish turn',
          color: AppColors.accent,
        );
      }
      return const _TurnStatus(
        icon: '🃏',
        text: 'Select a card to discard',
        color: AppColors.accent,
      );
    }
    if (!isHumanTurn) {
      if (turnNumber == 0) {
        return const _TurnStatus(
          icon: '🤖',
          text: 'Maya Bot\'s Turn — Evaluating First Open Card...',
          color: AppColors.textSecondary,
        );
      }
      return const _TurnStatus(
        icon: '⏳',
        text: 'Maya is thinking...',
        color: AppColors.textSecondary,
      );
    }
    return const _TurnStatus(
      icon: '⏳',
      text: 'Waiting...',
      color: AppColors.textMuted,
    );
  }
}

/// Helper model for resolved turn indicator icon, text, and color.
class _TurnStatus {
  final String icon;
  final String text;
  final Color color;

  const _TurnStatus({
    required this.icon,
    required this.text,
    required this.color,
  });
}
