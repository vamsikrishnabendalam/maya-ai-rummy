import 'package:flutter/material.dart';

/// Responsive utility class for Maya AI Rummy.
///
/// Provides screen breakpoint checks and responsive sizing helpers for
/// cards, spacing, padding, scaling, and typography across mobile portrait,
/// mobile landscape, tablet, and desktop screens.
class Responsive {
  Responsive._();

  // ---------------------------------------------------------------------------
  // Screen Dimension Helpers
  // ---------------------------------------------------------------------------

  /// Returns the screen width using [MediaQuery].
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Returns the screen height using [MediaQuery].
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ---------------------------------------------------------------------------
  // Breakpoint Methods
  // ---------------------------------------------------------------------------

  /// Whether the current screen is mobile portrait (width < 600).
  static bool isMobilePortrait(BuildContext context) =>
      screenWidth(context) < 600;

  /// Whether the current screen is mobile landscape (width >= 600 && width < 900).
  static bool isMobileLandscape(BuildContext context) {
    final width = screenWidth(context);
    return width >= 600 && width < 900;
  }

  /// Whether the current screen is a tablet (width >= 900 && width < 1200).
  static bool isTablet(BuildContext context) {
    final width = screenWidth(context);
    return width >= 900 && width < 1200;
  }

  /// Whether the current screen is a desktop (width >= 1200).
  static bool isDesktop(BuildContext context) =>
      screenWidth(context) >= 1200;

  // ---------------------------------------------------------------------------
  // Sizing Methods
  // ---------------------------------------------------------------------------

  /// Returns card width based on screen size:
  /// - 52 on mobile portrait
  /// - 60 on landscape
  /// - 68 on tablet
  /// - 72 on desktop
  static double cardWidth(BuildContext context) {
    if (isDesktop(context)) {
      return 72.0;
    }
    if (isTablet(context)) {
      return 68.0;
    }
    if (isMobileLandscape(context)) {
      return 60.0;
    }
    return 52.0;
  }

  /// Returns card height calculated as `cardWidth * 1.5`.
  static double cardHeight(BuildContext context) => cardWidth(context) * 1.5;

  /// Returns the amount of card visible horizontally when fanned:
  /// - 28 on mobile portrait
  /// - 32 on landscape
  /// - 36 on tablet / desktop
  static double cardOverlap(BuildContext context) {
    if (isDesktop(context) || isTablet(context)) {
      return 36.0;
    }
    if (isMobileLandscape(context)) {
      return 32.0;
    }
    return 28.0;
  }

  /// Returns spacing between card groups:
  /// - 12 on mobile
  /// - 16 on larger screens (tablet & desktop)
  static double groupSpacing(BuildContext context) {
    if (isTablet(context) || isDesktop(context)) {
      return 16.0;
    }
    return 12.0;
  }

  /// Returns table edge padding:
  /// - 8 on mobile
  /// - 16 on tablet
  /// - 24 on desktop
  static double tablePadding(BuildContext context) {
    if (isDesktop(context)) {
      return 24.0;
    }
    if (isTablet(context)) {
      return 16.0;
    }
    return 8.0;
  }

  /// Returns scaling factor for center cards:
  /// - 0.85 on mobile
  /// - 1.0 on tablet+
  static double centerCardScale(BuildContext context) {
    if (isTablet(context) || isDesktop(context)) {
      return 1.0;
    }
    return 0.85;
  }

  /// Returns scaled base font size:
  /// - base * 0.85 on mobile
  /// - base on tablet
  /// - base * 1.1 on desktop
  static double fontSize(BuildContext context, double base) {
    if (isDesktop(context)) {
      return base * 1.1;
    }
    if (isTablet(context)) {
      return base;
    }
    return base * 0.85;
  }
}
