import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography and text styles for Maya AI Rummy.
///
/// Provides specialized type scales optimized for compact mobile game tables,
/// crisp card faces, opponent status indicators, meld labels, and scores.
class AppTextStyles {
  const AppTextStyles._();

  /// Primary card rank label for standard hand and table cards (e.g. 'A', 'K', '10').
  static TextStyle get cardRank => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.5,
      );

  /// Compact card rank label used on overlapping cards or smaller hand views.
  static TextStyle get cardRankSmall => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  /// Primary suit symbol glyph (♠, ♥, ♦, ♣) on standard cards.
  static TextStyle get cardSuit => const TextStyle(
        fontSize: 24,
        height: 1.0,
      );

  /// Small suit symbol glyph for corner indicators and compact views.
  static TextStyle get cardSuitSmall => const TextStyle(
        fontSize: 12,
        height: 1.0,
      );

  /// Group tag label displayed atop melded card sequences (e.g. 'PURE', 'SET').
  static TextStyle get groupLabel => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  /// Prominent score point counter displayed in gold.
  static TextStyle get scoreValue => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.accent,
      );

  /// Label accompanying score metrics (e.g. 'POINTS', 'DEADWOOD').
  static TextStyle get scoreLabel => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  /// Current turn state indicator text (e.g. 'Your Turn', 'Maya is thinking...').
  static TextStyle get turnStatus => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.accent,
      );

  /// Opponent avatar display name header.
  static TextStyle get opponentName => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// Secondary opponent metadata (e.g. card count, meld status).
  static TextStyle get opponentDetail => const TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
      );

  /// Compact action button text (e.g. 'Sort', 'Declare', 'Drop').
  static TextStyle get buttonLabel => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  /// Micro tag / badge text for wild joker markers and status chips.
  static TextStyle get badgeText => const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
      );

  /// Section heading or modal title style.
  static TextStyle get heading => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
}
