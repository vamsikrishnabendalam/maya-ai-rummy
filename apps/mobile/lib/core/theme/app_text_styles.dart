import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography and text styles for Maya AI Rummy.
///
/// Provides specialized type scales using Google Fonts:
/// - [Outfit] for luxury headlines, brand badges, and card ranks
/// - [Plus Jakarta Sans] for UI titles, body text, and meld statuses
/// - [JetBrains Mono] for timer countdowns, chips, points, and numeric stats
class AppTextStyles {
  const AppTextStyles._();

  // --- Reference HTML Typography Styles ---

  /// Primary card rank label (Outfit font, heavy black weight).
  static TextStyle get cardRank => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -0.5,
      );

  /// Compact card rank label.
  static TextStyle get cardRankSmall => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );

  /// Primary suit symbol glyph.
  static TextStyle get cardSuit => const TextStyle(
        fontSize: 22,
        height: 1.0,
      );

  /// Small suit symbol glyph for corner indicators.
  static TextStyle get cardSuitSmall => const TextStyle(
        fontSize: 12,
        height: 1.0,
      );

  /// Numeric values, pot size, points, currency (JetBrains Mono).
  static TextStyle get labelNumeric => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0.2,
      );

  /// Timer countdown font (JetBrains Mono).
  static TextStyle get labelTimer => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      );

  /// Group tag label displayed atop melded card sequences.
  static TextStyle get groupLabel => GoogleFonts.outfit(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      );

  /// Brand Title (Outfit).
  static TextStyle get brandTitle => GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
        letterSpacing: 1.2,
      );

  /// Prominent score point counter displayed in gold.
  static TextStyle get scoreValue => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      );

  /// Label accompanying score metrics (e.g. 'POINTS', 'DEADWOOD').
  static TextStyle get scoreLabel => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.5,
      );

  /// Current turn state indicator text.
  static TextStyle get turnStatus => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  /// Opponent avatar display name header.
  static TextStyle get opponentName => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  /// Secondary opponent metadata.
  static TextStyle get opponentDetail => GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      );

  /// Action button label (Drop, Sort, Discard, Declare).
  static TextStyle get buttonLabel => GoogleFonts.outfit(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      );

  /// Micro tag / badge text for wild joker markers and status chips.
  static TextStyle get badgeText => GoogleFonts.outfit(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      );

  /// Section heading or modal title style.
  static TextStyle get heading => GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurface,
      );
}
