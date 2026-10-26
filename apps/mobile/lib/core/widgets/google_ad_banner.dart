import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Non-intrusive Google Ad placement widget designed for free spaces
/// around the 16:9 Maya AI Rummy stadium table.
///
/// Features:
/// - Unobtrusive slim footprint that never overlaps or blocks game actions.
/// - AdSense publisher client: ca-pub-9175194985468127.
/// - Dark luxury styling matching the table aesthetic.
class GoogleAdBanner extends StatelessWidget {
  final double? height;
  final double? width;
  final bool isVertical;

  const GoogleAdBanner({
    super.key,
    this.height,
    this.width,
    this.isVertical = false,
  });

  const GoogleAdBanner.vertical({
    super.key,
    this.height,
    this.width = 90.0,
  }) : isVertical = true;

  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Container(
        width: width ?? 90.0,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.4),
                  width: 0.6,
                ),
              ),
              child: Text(
                'AD',
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              Icons.campaign_outlined,
              size: 20,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 6),
            Text(
              'Google Ads\nca-pub-9175194985468127',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 8,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: width,
      height: height ?? 36.0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Discreet Ad Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.4),
                width: 0.6,
              ),
            ),
            child: Text(
              'AD',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sponsored text / Google Ads placeholder
          Flexible(
            child: Text(
              'Google Ads • Play responsibly | 18+ Only | Fast & Fair Rummy Action',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Google Ad badge icon
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
