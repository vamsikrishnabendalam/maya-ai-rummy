import 'package:flutter/material.dart';

/// Defines the color palette for Maya AI Rummy.
///
/// Designed to evoke a premium, high-stakes Indian 13-card rummy atmosphere
/// featuring deep navy table gradients, warm gold accents, frosted glass panels,
/// and clear card and meld group status indicators.
class AppColors {
  const AppColors._();

  // --- Table & Felt Backgrounds ---

  /// Deep dark navy at the top of the table felt gradient.
  static const Color tableGradientTop = Color(0xFF0A1628);

  /// Slightly lighter navy at the bottom of the table felt gradient.
  static const Color tableGradientBottom = Color(0xFF162D50);

  /// Warm gold at ~8% opacity for the center radial table spotlight glow.
  static const Color tableSpotlight = Color(0x14FFB300);

  // --- Card Styling ---

  /// Crisp off-white background for physical card faces.
  static const Color cardFace = Color(0xFFFAFAFA);

  /// Subtle light grey border surrounding card outlines.
  static const Color cardBorder = Color(0xFFE0E0E0);

  /// Soft 25% black shadow beneath resting and dragged cards.
  static const Color cardShadow = Color(0x40000000);

  /// Card back primary deep indigo base.
  static const Color deckBack = Color(0xFF1A237E);

  /// Card back accent pattern indigo hue.
  static const Color deckBackAccent = Color(0xFF283593);

  // --- Card Suits ---

  /// Vibrant red for Hearts and Diamonds.
  static const Color suitRed = Color(0xFFE53935);

  /// Deep solid jet black for Clubs and Spades.
  static const Color suitBlack = Color(0xFF111111);

  // --- Gold Accents & Highlights ---

  /// Premium gold accent used for highlights, turn indicators, and primary CTAs.
  static const Color accent = Color(0xFFFFB300);

  /// Warm gold at 30% opacity for intense glow and elevation halos.
  static const Color accentGlow = Color(0x4DFFB300);

  /// Warm gold at 10% opacity for subtle container highlights and badges.
  static const Color accentSubtle = Color(0x1AFFB300);

  /// Gold text color for badges and emphasis.
  static const Color textGold = Color(0xFFFFD54F);

  // --- Glassmorphism Panels ---

  /// Frosted glass panel fill (white at ~12% opacity).
  static const Color glass = Color(0x1FFFFFFF);

  /// Frosted glass outline border (white at 15% opacity).
  static const Color glassBorder = Color(0x26FFFFFF);

  /// Subtle glass highlight / reflection sheen (white at 5% opacity).
  static const Color glassHighlight = Color(0x0DFFFFFF);

  // --- Rummy Meld & Group Statuses ---

  /// Pure sequence label and indicator badge color (green).
  static const Color groupPure = Color(0xFF43A047);

  /// Impure sequence label and indicator badge color (blue).
  static const Color groupImpure = Color(0xFF1E88E5);

  /// Set label and indicator badge color (purple).
  static const Color groupSet = Color(0xFF8E24AA);

  /// Deadwood / ungrouped card label and indicator color (red-orange).
  static const Color groupDeadwood = Color(0xFFF4511E);

  // --- Feedback & Alerts ---

  /// Danger, error, and invalid meld color.
  static const Color danger = Color(0xFFE53935);

  /// Success, confirmation, and valid declaration color.
  static const Color success = Color(0xFF43A047);

  // --- Typography & Content ---

  /// Primary white text with maximum contrast.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary muted text (white at 70% opacity).
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// Subtle hint / disabled text (white at 50% opacity).
  static const Color textMuted = Color(0x80FFFFFF);
}
