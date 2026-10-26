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

  // --- Luxury Stadium & HTML Reference Palette ---
  static const Color surface = Color(0xFF0B141B);
  static const Color surfaceContainerLowest = Color(0xFF060F16);
  static const Color surfaceContainerLow = Color(0xFF141D24);
  static const Color surfaceContainer = Color(0xFF182128);
  static const Color surfaceContainerHigh = Color(0xFF222B32);
  static const Color surfaceContainerHighest = Color(0xFF2D363D);

  // Gold Primary Tokens
  static const Color primary = Color(0xFFF2CA50);
  static const Color primaryContainer = Color(0xFFD4AF37);
  static const Color onPrimary = Color(0xFF3C2F00);
  static const Color onPrimaryContainer = Color(0xFF554300);

  // Mint / Green Tertiary & Secondary Tokens
  static const Color secondary = Color(0xFF9AD3B0);
  static const Color secondaryContainer = Color(0xFF1C5338);
  static const Color onSecondaryContainer = Color(0xFF8DC5A2);
  static const Color tertiary = Color(0xFF58E7AA);
  static const Color tertiaryContainer = Color(0xFF33CA90);
  static const Color onTertiaryContainer = Color(0xFF005035);

  // Error Tokens
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Surface Text & Outline
  static const Color onSurface = Color(0xFFDAE4ED);
  static const Color onSurfaceVariant = Color(0xFFD0C5AF);
  static const Color outline = Color(0xFF99907C);
  static const Color outlineVariant = Color(0xFF4D4635);

  // Felt Luxury Stadium Backdrop
  static const Color feltGradientTop = Color(0xFF0E3A24);
  static const Color feltGradientMid = Color(0xFF082A1A);
  static const Color feltGradientBottom = Color(0xFF04160D);
  static const Color feltGoldBoundary = Color(0x59D4AF37); // rgba(212,175,55,0.35)
  static const Color feltAmbientSpotlight = Color(0x14F2CA50); // rgba(242,202,80,0.08)

  /// Primary white text with maximum contrast.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary muted text (white at 70% opacity).
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// Subtle hint / disabled text (white at 50% opacity).
  static const Color textMuted = Color(0x80FFFFFF);
}
