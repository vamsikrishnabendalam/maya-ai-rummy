import 'package:flutter/material.dart';

/// 2.5D Oval Rummy Table with golden-mahogany wood rim, gold metallic trim,
/// emerald felt radial gradient, inner felt betting oval, and royal watermark.
class RoyalRummyOvalTable extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final bool isPortrait;
  final bool isTransparent;

  const RoyalRummyOvalTable({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.isPortrait = false,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isTransparent) {
      return Center(
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: child,
          ),
        ),
      );
    }

    // Stadium corner radius matching rounded-[4.5rem] (72px)
    final double outerRadius = isPortrait ? 72.0 : 64.0;
    final double boundaryRadius = isPortrait ? 65.0 : 58.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(outerRadius),
          // Deep Stadium Felt Luxury Gradient
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0E3A24), // from-[#0e3a24]
              Color(0xFF082A1A), // via-[#082a1a]
              Color(0xFF04160D), // to-[#04160d]
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.28),
            width: 1.5,
          ),
          boxShadow: [
            // Outer 3D Rim drop shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.95),
              blurRadius: 36,
              spreadRadius: 4,
              offset: const Offset(0, 10),
            ),
            // Vignette depth shadow
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: 0.8),
              blurRadius: 50,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center Ambient Table Spotlight
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(outerRadius),
                  gradient: const RadialGradient(
                    center: Alignment.center,
                    radius: 0.75,
                    colors: [
                      Color(0x14F2CA50), // rgba(242,202,80,0.08)
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.65],
                  ),
                ),
              ),
            ),

            // Felt Gold Boundary Inlay Line
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(boundaryRadius),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.35), // shadow-[inset_0_0_0_1px_rgba(212,175,55,0.35)]
                      width: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            // Watermark subtle branding
            Positioned(
              top: isPortrait ? 12 : 8,
              child: Opacity(
                opacity: 0.18,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '♠  MAYA AI RUMMY  ♥',
                      style: TextStyle(
                        color: Color(0xFFF2CA50),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Child Content (Opponents, Center Decks, etc.)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
