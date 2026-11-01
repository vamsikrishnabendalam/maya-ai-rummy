import 'package:flutter/material.dart';

/// Full-screen background displaying the Glamorous Saree Host at Gaming Table artwork
/// for the Maya AI single-player game table.
class GameTableBackground extends StatelessWidget {
  final Widget child;

  const GameTableBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Glamorous Saree Host at Gaming Table Background Image (Isolated with RepaintBoundary for 60fps drag-drop)
        RepaintBoundary(
          child: Image.asset(
            'assets/images/maya_ai_table_bg.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              // Graceful fallback to PNG if WebP is unavailable
              return Image.asset(
                'assets/images/maya_ai_table_bg.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1E0836),
                        Color(0xFF0F051D),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 2. Foreground Game Table Content (Cards, HUD, Controls)
        child,
      ],
    );
  }
}

