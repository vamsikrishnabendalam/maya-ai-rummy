import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';

import '../../../../core/theme/app_colors.dart';
import 'card_back_widget.dart';

/// Glass-morphism horizontal bar at the top of the game table showing the AI opponent's info.
class OpponentPanel extends StatefulWidget {
  /// The AI opponent player state.
  final Player opponent;

  /// Whether the AI is currently calculating its move.
  final bool isThinking;

  /// Difficulty label displayed on the badge (e.g. 'Beginner', 'Expert').
  final String difficultyLabel;

  /// Whether the AI opponent is the dealer for the current deal.
  final bool isDealer;

  const OpponentPanel({
    Key? key,
    required this.opponent,
    this.isThinking = false,
    this.difficultyLabel = 'Expert',
    this.isDealer = false,
  }) : super(key: key);

  @override
  State<OpponentPanel> createState() => _OpponentPanelState();
}

class _OpponentPanelState extends State<OpponentPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLeftSection(),
          _buildCenterSection(),
          _buildRightSection(),
        ],
      ),
    );
  }

  /// Builds the left section with the avatar, name, and difficulty badge.
  Widget _buildLeftSection() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.deckBack,
                AppColors.groupImpure,
              ],
            ),
          ),
          child: const CircleAvatar(
            backgroundColor: Colors.transparent,
            radius: 19,
            child: Text(
              '🤖',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Maya Bot',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.difficultyLabel,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.isDealer) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.amber,
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '🅳 DEALER',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the center section with miniature overlapping face-down cards and hand count.
  Widget _buildCenterSection() {
    final int cardCount = math.min(widget.opponent.hand.length, 5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          child: cardCount > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < cardCount; i++)
                      Align(
                        widthFactor: i == cardCount - 1 ? 1.0 : 0.45,
                        alignment: Alignment.centerLeft,
                        child: CardBackWidget(
                          width: 24,
                          height: 36,
                          rotation: _getCardRotation(i, cardCount),
                        ),
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 2),
        Text(
          '${widget.opponent.hand.length} cards',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Calculates slight rotation variations for fanned miniature cards (-2, -1, 0, 1, 2 degrees).
  double _getCardRotation(int index, int count) {
    if (count <= 1) return 0.0;
    if (count == 5) {
      const rotations = [-2.0, -1.0, 0.0, 1.0, 2.0];
      return rotations[index];
    }
    return -2.0 + (4.0 * index / (count - 1));
  }

  /// Builds the right section showing either animated thinking dots or 'Waiting' label.
  Widget _buildRightSection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: widget.isThinking
          ? const _ThinkingDots(key: ValueKey('thinking_dots'))
          : const Text(
              'Waiting',
              key: ValueKey('waiting_text'),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
    );
  }
}

/// Animated thinking indicator with 3 sequential pulsing dots and amber/gold text.
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({Key? key}) : super(key: key);

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thinking...',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  _buildDot(i),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  /// Builds an individual pulsing dot with animated opacity.
  Widget _buildDot(int dotIndex) {
    // Opacity formula: sin(controller.value * pi + dotIndex * pi/3).abs().clamp(0.3, 1.0)
    final double opacity =
        math.sin(_controller.value * math.pi + dotIndex * math.pi / 3)
            .abs()
            .clamp(0.3, 1.0);

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
