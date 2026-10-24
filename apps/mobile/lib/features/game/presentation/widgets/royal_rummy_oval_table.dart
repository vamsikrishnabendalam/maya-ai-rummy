import 'package:flutter/material.dart';

/// 2.5D Oval Rummy Table with golden-mahogany wood rim, gold metallic trim,
/// emerald felt radial gradient, inner felt betting oval, and royal watermark.
class RoyalRummyOvalTable extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final bool isPortrait;

  const RoyalRummyOvalTable({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.isPortrait = false,
  });

  @override
  Widget build(BuildContext context) {
    final double tableRadius = isPortrait ? 90.0 : 160.0;
    final double innerRadius = isPortrait ? 82.0 : 150.0;
    final double feltRadius = isPortrait ? 74.0 : 142.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tableRadius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF613415), // Top golden mahogany
              Color(0xFF2C1506), // Deep shadow mahogany
              Color(0xFF4A260E), // Base rim
            ],
          ),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
            width: 2.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.95),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: const Color(0xFFFDE047).withValues(alpha: 0.25),
              blurRadius: 3,
              spreadRadius: -1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF070B12),
                Color(0xFF1C1917),
                Color(0xFF070B12),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.42),
              width: 1.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(feltRadius),
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 0.92,
                colors: [
                  Color(0xFF147550), // Center bright emerald
                  Color(0xFF0A4730), // Mid felt
                  Color(0xFF042619), // Deep edge felt
                ],
                stops: [0.0, 0.62, 1.0],
              ),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner Felt Betting Oval Ring
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(isPortrait ? 8.0 : 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(feltRadius - 10),
                        border: Border.all(
                          color: const Color(0xFFFDE68A).withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // Table Watermark Branding
                Positioned(
                  top: isPortrait ? 10 : 14,
                  child: Opacity(
                    opacity: 0.22,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '♠ ROYAL RUMMY - 13 CARDS ♥',
                          style: TextStyle(
                            color: const Color(0xFFFDE68A),
                            fontSize: isPortrait ? 9.5 : 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                            fontFamily: 'serif',
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '1st Life Pure Sequence • 2nd Life Sequence Required',
                          style: TextStyle(
                            color: const Color(0xFFA7F3D0),
                            fontSize: isPortrait ? 7 : 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Child Contents (Center Wells: Decks, Joker, Finish Slot)
                Center(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
