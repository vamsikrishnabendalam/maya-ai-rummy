import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive.dart';

/// Meld Status Bar positioned directly above the player hand matching the HTML reference:
/// - Left: "Your Hand:" with verified "1st Life" and "2nd Life" status pills
/// - Center: Turn status countdown timer pill
/// - Right: "Deadwood: X pts" badge in error-container / victory emerald
class RoyalLifeChecklistBar extends StatelessWidget {
  final bool hasFirstLife;
  final bool hasSecondLife;
  final int points;
  final bool isMyTurn;
  final int? turnSeconds;
  final VoidCallback? onAutoGroup;
  final VoidCallback? onDrop;
  final bool canAutoGroup;
  final bool canDrop;

  const RoyalLifeChecklistBar({
    super.key,
    required this.hasFirstLife,
    required this.hasSecondLife,
    required this.points,
    this.isMyTurn = true,
    this.turnSeconds,
    this.onAutoGroup,
    this.onDrop,
    this.canAutoGroup = false,
    this.canDrop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final double labelFont = isDesktop ? 11.0 : 8.5;
    final double pillFont = isDesktop ? 11.0 : 8.5;
    final double iconSz = isDesktop ? 14.0 : 11.0;
    final double pointsFont = isDesktop ? 12.0 : 9.5;

    return Container(
      constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 820),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 12, vertical: isDesktop ? 5 : 3),
      decoration: BoxDecoration(
        color: const Color(0xFF060F16).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF222B32).withValues(alpha: 0.8),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Left: Your Hand + 1st Life + 2nd Life
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'YOUR HAND:',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD0C5AF),
                  fontSize: labelFont,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: isDesktop ? 10 : 8),

              // 1st Life Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 6, vertical: isDesktop ? 3 : 2),
                decoration: BoxDecoration(
                  color: hasFirstLife
                      ? const Color(0xFF1C5338)
                      : const Color(0xFF141D24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFirstLife
                        ? const Color(0xFF33CA90)
                        : Colors.white12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFirstLife ? Icons.verified : Icons.radio_button_unchecked,
                      size: iconSz,
                      color: hasFirstLife
                          ? const Color(0xFF58E7AA)
                          : const Color(0xFF99907C),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '1st Life',
                      style: GoogleFonts.plusJakartaSans(
                        color: hasFirstLife
                            ? const Color(0xFF58E7AA)
                            : const Color(0xFF99907C),
                        fontSize: pillFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isDesktop ? 8 : 6),

              // 2nd Life Pill
              Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 6, vertical: isDesktop ? 3 : 2),
                decoration: BoxDecoration(
                  color: hasSecondLife
                      ? const Color(0xFF1C5338)
                      : const Color(0xFF141D24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasSecondLife
                        ? const Color(0xFF33CA90)
                        : Colors.white12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSecondLife ? Icons.verified : Icons.radio_button_unchecked,
                      size: iconSz,
                      color: hasSecondLife
                          ? const Color(0xFF58E7AA)
                          : const Color(0xFF99907C),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '2nd Life',
                      style: GoogleFonts.plusJakartaSans(
                        color: hasSecondLife
                            ? const Color(0xFF58E7AA)
                            : const Color(0xFF99907C),
                        fontSize: pillFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Center: Turn Countdown Pill
          if (isMyTurn)
            Container(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 7, vertical: isDesktop ? 3 : 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF2CA50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: isDesktop ? 13 : 10, color: const Color(0xFFF2CA50)),
                  const SizedBox(width: 3),
                  Text(
                    '${turnSeconds ?? 30}s YOUR TURN',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFF2CA50),
                      fontSize: pillFont,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

          // 3. Right: Deadwood Points Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DEADWOOD:',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD0C5AF),
                  fontSize: labelFont,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(width: isDesktop ? 7 : 5),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 9 : 7, vertical: isDesktop ? 2.5 : 1.5),
                decoration: BoxDecoration(
                  color: points == 0
                      ? const Color(0xFF1C5338)
                      : const Color(0xFF93000A).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: points == 0
                        ? const Color(0xFF33CA90)
                        : const Color(0xFFFFB4AB).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$points pts',
                  style: GoogleFonts.jetBrainsMono(
                    color: points == 0
                        ? const Color(0xFF58E7AA)
                        : const Color(0xFFFFB4AB),
                    fontSize: pointsFont,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
