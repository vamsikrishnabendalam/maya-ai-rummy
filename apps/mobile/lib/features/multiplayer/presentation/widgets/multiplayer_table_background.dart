import 'package:flutter/material.dart';
import '../../../../core/utils/responsive.dart';

/// Full-screen background displaying the Royal Casino Hall artwork
/// customized per multiplayer player count (2, 3, 4, 5, 6 players),
/// with responsive mobile landscape asset selection.
class MultiplayerTableBackground extends StatelessWidget {
  final int maxPlayers;
  final Widget child;

  const MultiplayerTableBackground({
    super.key,
    required this.maxPlayers,
    required this.child,
  });

  /// Maps player capacity (2, 3, 4, 5, 6) to its dedicated royal casino hall background asset.
  static String assetForMaxPlayers(int maxPlayers, {bool isMobileLandscape = false}) {
    final prefix = isMobileLandscape ? 'multiplayer_mobile_bg' : 'multiplayer_bg';
    switch (maxPlayers) {
      case 2:
        return 'assets/images/${prefix}_2p.webp';
      case 3:
        return 'assets/images/${prefix}_3p.webp';
      case 4:
        return 'assets/images/${prefix}_4p.webp';
      case 5:
        return 'assets/images/${prefix}_5p.webp';
      case 6:
      default:
        return 'assets/images/${prefix}_6p.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLandscape = Responsive.isMobileLandscape(context);
    final assetPath = assetForMaxPlayers(maxPlayers, isMobileLandscape: isMobileLandscape);
    final pngFallbackPath = assetPath.replaceAll('.webp', '.png');

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Royal Casino Hall Background Image for current player count (Isolated with RepaintBoundary)
        RepaintBoundary(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to PNG if WebP is unavailable
              return Image.asset(
                pngFallbackPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  // Elegant fallback gradient if asset is loading or missing
                  return Container(
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
                  );
                },
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
