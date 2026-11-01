import 'package:flutter/material.dart';

/// Full-screen background displaying the Royal Casino Hall artwork
/// customized per multiplayer player count (2, 3, 4, 5, 6 players).
class MultiplayerTableBackground extends StatelessWidget {
  final int maxPlayers;
  final Widget child;

  const MultiplayerTableBackground({
    super.key,
    required this.maxPlayers,
    required this.child,
  });

  /// Maps player capacity (2, 3, 4, 5, 6) to its dedicated royal casino hall background asset.
  static String assetForMaxPlayers(int maxPlayers) {
    switch (maxPlayers) {
      case 2:
        return 'assets/images/multiplayer_bg_2p.png';
      case 3:
        return 'assets/images/multiplayer_bg_3p.png';
      case 4:
        return 'assets/images/multiplayer_bg_4p.png';
      case 5:
        return 'assets/images/multiplayer_bg_5p.png';
      case 6:
      default:
        return 'assets/images/multiplayer_bg_6p.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = assetForMaxPlayers(maxPlayers);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Royal Casino Hall Background Image for current player count
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
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
        ),

        // 2. Foreground Game Table Content (Cards, HUD, Controls)
        child,
      ],
    );
  }
}

