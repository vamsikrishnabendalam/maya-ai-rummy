import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom action bar offering primary gameplay actions like sorting, grouping, declaring, and dropping.
class ActionBar extends StatelessWidget {
  /// Callback to sort hand cards.
  final VoidCallback? onSort;

  /// Callback to automatically group hand cards into valid melds.
  final VoidCallback? onAutoGroup;

  /// Callback to discard selected card.
  final VoidCallback? onDiscard;

  /// Whether discard is currently enabled (player turn, discard phase, 1 card selected).
  final bool canDiscard;

  /// Callback to discard the selected card and declare the hand.
  final VoidCallback? onDiscardAndDeclare;

  /// Whether discard & declare is enabled (player turn, discard phase, 1 card selected).
  final bool canDiscardAndDeclare;

  /// Whether the remaining 13 cards form a winning declaration (green glow).
  final bool isDeclarationWinning;

  /// Callback to drop the current hand.
  final VoidCallback? onDrop;

  /// Whether drop is allowed.
  final bool canDrop;

  /// Callback to start a new game round.
  final VoidCallback? onNewGame;

  /// Whether the human player is responding to an opponent declaration show.
  final bool isAwaitingDeclarationShow;

  /// Current deadwood score to display on the Submit Show button.
  final int currentDeclarationScore;

  /// Callback to auto-arrange hand to optimal least-count grouping.
  final VoidCallback? onAutoArrange;

  /// Callback to submit rearranged cards for show.
  final VoidCallback? onSubmitShow;

  const ActionBar({
    super.key,
    this.onSort,
    this.onAutoGroup,
    this.onDiscard,
    this.canDiscard = false,
    this.onDiscardAndDeclare,
    this.canDiscardAndDeclare = false,
    this.isDeclarationWinning = false,
    this.onDrop,
    this.canDrop = true,
    this.onNewGame,
    this.isAwaitingDeclarationShow = false,
    this.currentDeclarationScore = 0,
    this.onAutoArrange,
    this.onSubmitShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.glass,
        border: Border.all(color: AppColors.glassBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: isAwaitingDeclarationShow
            ? [
                _ActionButton(
                  icon: Icons.sort,
                  label: 'Sort',
                  onTap: onSort,
                ),
                _ActionButton(
                  icon: Icons.auto_awesome,
                  label: 'Auto-Arrange',
                  onTap: onAutoArrange,
                  isHighlighted: true,
                  highlightColor: AppColors.accent,
                ),
                _ActionButton(
                  icon: Icons.auto_fix_high,
                  label: 'Group',
                  onTap: onAutoGroup,
                ),
                _ActionButton(
                  icon: Icons.assignment_turned_in,
                  label: 'Submit Show ($currentDeclarationScore pts)',
                  onTap: onSubmitShow,
                  isHighlighted: true,
                  highlightColor: AppColors.success,
                ),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'New',
                  onTap: onNewGame,
                ),
              ]
            : [
                _ActionButton(
                  icon: Icons.sort,
                  label: 'Sort',
                  onTap: onSort,
                ),
                _ActionButton(
                  icon: Icons.auto_fix_high,
                  label: 'Group',
                  onTap: onAutoGroup,
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Discard',
                  onTap: canDiscard ? onDiscard : null,
                  isHighlighted: canDiscard && !isDeclarationWinning,
                  highlightColor: AppColors.danger,
                  isDisabled: !canDiscard,
                ),
                _ActionButton(
                  icon: Icons.done_all,
                  label: 'Discard & Declare',
                  onTap: canDiscardAndDeclare ? onDiscardAndDeclare : null,
                  isHighlighted: isDeclarationWinning,
                  highlightColor: AppColors.success,
                  isDisabled: !canDiscardAndDeclare,
                ),
                _ActionButton(
                  icon: Icons.exit_to_app,
                  label: 'Drop',
                  onTap: canDrop ? onDrop : null,
                  color: AppColors.danger,
                  isDisabled: !canDrop,
                ),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'New',
                  onTap: onNewGame,
                ),
              ],
      ),
    );
  }
}

/// Action button item within [ActionBar].
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final Color? highlightColor;
  final Color? color;
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isHighlighted = false,
    this.highlightColor,
    this.color,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isDisabled
        ? const Color(0x33FFFFFF)
        : isHighlighted
            ? (highlightColor ?? AppColors.success)
            : (color ?? const Color(0xCCFFFFFF));

    final effectiveTextColor = isDisabled
        ? const Color(0x33FFFFFF)
        : isHighlighted
            ? (highlightColor ?? AppColors.success)
            : (color != null ? color!.withValues(alpha: 0.85) : const Color(0x99FFFFFF));

    Widget iconWidget = Icon(
      icon,
      size: 18,
      color: effectiveIconColor,
    );

    if (isHighlighted) {
      iconWidget = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (highlightColor ?? AppColors.success).withValues(alpha: 0.2),
          boxShadow: [
            BoxShadow(
              color: (highlightColor ?? AppColors.success).withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: iconWidget,
      );
    } else {
      iconWidget = Padding(
        padding: const EdgeInsets.all(4),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: effectiveTextColor,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
