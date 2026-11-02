import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/models/avatar_catalog.dart';
import '../../models/table_models.dart';

/// Specification for where an opponent avatar and pod are seated across the reference canvas.
class MultiplayerSeatPosition {
  final double? left;
  final double? right;
  final double? centerX;
  final double top; // pod floating position
  final double avatarTop; // seated avatar top in chair
  final double avatarHeight; // seated avatar height
  final bool isCenter;

  const MultiplayerSeatPosition({
    this.left,
    this.right,
    this.centerX,
    required this.top,
    this.avatarTop = 130,
    this.avatarHeight = 320,
    this.isCenter = false,
  });
}

/// Extensible layer that arranges opponent player pods and seated avatars around the table based on active player capacity.
class MultiplayerOpponentsLayer extends StatelessWidget {
  final int maxPlayers;
  final List<TablePlayer> opponents;
  final String currentTurnPlayerId;
  final String dealerPlayerId;
  final int remainingTurnSeconds;
  final void Function(TablePlayer)? onOpponentTap;
  final bool isMobile;

  const MultiplayerOpponentsLayer({
    super.key,
    required this.maxPlayers,
    required this.opponents,
    required this.currentTurnPlayerId,
    required this.dealerPlayerId,
    required this.remainingTurnSeconds,
    this.onOpponentTap,
    this.isMobile = false,
  });

  /// Seat coordinates configured for desktop/tablet (1754x896 reference canvas).
  static List<MultiplayerSeatPosition> getPositionsForPlayerCount(int capacity) {
    switch (capacity) {
      case 2:
        return const [
          // 2-Player: Single opponent centered directly in the central royal throne
          MultiplayerSeatPosition(
            centerX: 878,
            top: 54,
            avatarTop: 105,
            avatarHeight: 350,
            isCenter: true,
          ),
        ];
      case 3:
        return const [
          // 3-Player: 2 opponents seated in the 2 royal armchairs
          MultiplayerSeatPosition(
            centerX: 550,
            top: 58,
            avatarTop: 110,
            avatarHeight: 345,
          ),
          MultiplayerSeatPosition(
            centerX: 1205,
            top: 58,
            avatarTop: 110,
            avatarHeight: 345,
          ),
        ];
      case 4:
        return const [
          // 4-Player: 3 opponents arrayed across the 3 armchairs
          MultiplayerSeatPosition(
            centerX: 160,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
          MultiplayerSeatPosition(
            centerX: 878,
            top: 85,
            avatarTop: 135,
            avatarHeight: 320,
            isCenter: true,
          ),
          MultiplayerSeatPosition(
            centerX: 1600,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
        ];
      case 5:
        return const [
          // 5-Player: 4 opponents arrayed across the 4 armchairs in royal arc
          MultiplayerSeatPosition(
            centerX: 130,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
          MultiplayerSeatPosition(
            centerX: 640,
            top: 85,
            avatarTop: 135,
            avatarHeight: 320,
          ),
          MultiplayerSeatPosition(
            centerX: 1116,
            top: 85,
            avatarTop: 135,
            avatarHeight: 320,
          ),
          MultiplayerSeatPosition(
            centerX: 1620,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
        ];
      case 6:
      default:
        return const [
          // 6-Player: 5 opponents arrayed across the 5 armchairs
          MultiplayerSeatPosition(
            centerX: 110,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
          MultiplayerSeatPosition(
            centerX: 490,
            top: 100,
            avatarTop: 150,
            avatarHeight: 310,
          ),
          MultiplayerSeatPosition(
            centerX: 878,
            top: 85,
            avatarTop: 135,
            avatarHeight: 320,
            isCenter: true,
          ),
          MultiplayerSeatPosition(
            centerX: 1266,
            top: 100,
            avatarTop: 150,
            avatarHeight: 310,
          ),
          MultiplayerSeatPosition(
            centerX: 1640,
            top: 150,
            avatarTop: 200,
            avatarHeight: 270,
          ),
        ];
    }
  }

  /// Mobile seat coordinates configured for each table capacity (2, 3, 4, 5, 6 players)
  /// tailored for the 1024x491 mobile landscape canvas with chairs in the background.
  static List<MultiplayerSeatPosition> getMobilePositionsForPlayerCount(int capacity) {
    switch (capacity) {
      case 2:
        return const [
          // 2-Player: Single opponent centered in central armchair, strictly behind the table rim
          MultiplayerSeatPosition(
            centerX: 512,
            top: 40,
            avatarTop: 82,
            avatarHeight: 140,
            isCenter: true,
          ),
        ];
      case 3:
        return const [
          // 3-Player: 2 opponents in the 2 armchairs
          MultiplayerSeatPosition(
            centerX: 330,
            top: 42,
            avatarTop: 82,
            avatarHeight: 138,
          ),
          MultiplayerSeatPosition(
            centerX: 695,
            top: 42,
            avatarTop: 82,
            avatarHeight: 138,
          ),
        ];
      case 4:
        return const [
          // 4-Player: 3 opponents arrayed across the 3 armchairs
          MultiplayerSeatPosition(
            centerX: 196,
            top: 60,
            avatarTop: 95,
            avatarHeight: 125,
          ),
          MultiplayerSeatPosition(
            centerX: 512,
            top: 40,
            avatarTop: 82,
            avatarHeight: 140,
            isCenter: true,
          ),
          MultiplayerSeatPosition(
            centerX: 828,
            top: 60,
            avatarTop: 95,
            avatarHeight: 125,
          ),
        ];
      case 5:
        return const [
          // 5-Player: 4 opponents in royal arc
          MultiplayerSeatPosition(
            centerX: 184,
            top: 62,
            avatarTop: 95,
            avatarHeight: 125,
          ),
          MultiplayerSeatPosition(
            centerX: 386,
            top: 42,
            avatarTop: 84,
            avatarHeight: 136,
          ),
          MultiplayerSeatPosition(
            centerX: 644,
            top: 42,
            avatarTop: 84,
            avatarHeight: 136,
          ),
          MultiplayerSeatPosition(
            centerX: 856,
            top: 62,
            avatarTop: 95,
            avatarHeight: 125,
          ),
        ];
      case 6:
      default:
        return const [
          // 6-Player: 5 opponents arrayed across 5 armchairs
          MultiplayerSeatPosition(
            centerX: 158,
            top: 62,
            avatarTop: 95,
            avatarHeight: 120,
          ),
          MultiplayerSeatPosition(
            centerX: 330,
            top: 45,
            avatarTop: 88,
            avatarHeight: 130,
          ),
          MultiplayerSeatPosition(
            centerX: 506,
            top: 40,
            avatarTop: 82,
            avatarHeight: 138,
            isCenter: true,
          ),
          MultiplayerSeatPosition(
            centerX: 682,
            top: 45,
            avatarTop: 88,
            avatarHeight: 130,
          ),
          MultiplayerSeatPosition(
            centerX: 860,
            top: 62,
            avatarTop: 95,
            avatarHeight: 120,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();

    final positions = isMobile
        ? getMobilePositionsForPlayerCount(maxPlayers)
        : getPositionsForPlayerCount(maxPlayers);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. First layer: Seated Avatars in their respective chairs (only for joined players!)
        for (int i = 0; i < opponents.length && i < positions.length; i++) ...[
          _buildSeatedAvatar(
            position: positions[i],
            player: opponents[i],
            isCurrentTurn: opponents[i].uid == currentTurnPlayerId,
          ),
        ],

        // 2. Second layer: Floating Status Pods above avatars' heads
        for (int i = 0; i < opponents.length && i < positions.length; i++) ...[
          _buildPositionedPod(
            position: positions[i],
            player: opponents[i],
          ),
        ],
      ],
    );
  }

  Widget _buildSeatedAvatar({
    required MultiplayerSeatPosition position,
    required TablePlayer player,
    required bool isCurrentTurn,
  }) {
    final photoURL = player.photoURL;
    final isCustom = AvatarCatalog.isCustomPhoto(photoURL);

    Widget avatarWidget;
    if (isCustom) {
      // Luxury circular badge seated in the velvet chair backrest
      ImageProvider? imgProvider;
      if (photoURL.startsWith('data:image')) {
        try {
          final b64 = photoURL.split(',').last;
          imgProvider = MemoryImage(base64Decode(b64));
        } catch (_) {}
      } else if (photoURL.startsWith('http')) {
        imgProvider = NetworkImage(photoURL);
      }

      final badgeSize = (position.avatarHeight * 0.52).clamp(
        isMobile ? 55.0 : 100.0,
        isMobile ? 90.0 : 150.0,
      );

      avatarWidget = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isCurrentTurn ? const Color(0xFFF2CA50) : const Color(0xFFD4AF37),
            width: isCurrentTurn ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrentTurn
                  ? const Color(0xFFF2CA50).withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: isCurrentTurn ? 16 : 8,
              spreadRadius: isCurrentTurn ? 2 : 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: imgProvider != null
                ? Image(
                    image: imgProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: badgeSize * 0.35,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      player.displayName.isNotEmpty ? player.displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeSize * 0.35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
      );
    } else {
      // Preset transparent cutout avatar seated in velvet chair
      final assetPath = AvatarCatalog.getFullAssetPath(photoURL);

      avatarWidget = ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.70, 0.95],
            colors: [Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          assetPath,
          height: position.avatarHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Image.asset(
            AvatarCatalog.defaultAvatar.assetPath,
            height: position.avatarHeight,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final double xAnchor = position.centerX ?? (position.left ?? 0);

    return Positioned(
      top: position.avatarTop,
      left: xAnchor,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: avatarWidget,
      ),
    );
  }

  Widget _buildPositionedPod({
    required MultiplayerSeatPosition position,
    required TablePlayer player,
  }) {
    final isCurrentTurn = player.uid == currentTurnPlayerId;
    final isDealer = player.uid == dealerPlayerId;

    final pod = MultiplayerOpponentPod(
      player: player,
      isCurrentTurn: isCurrentTurn,
      isDealer: isDealer,
      remainingTurnSeconds: remainingTurnSeconds,
      onTap: onOpponentTap != null ? () => onOpponentTap!(player) : null,
      isMobile: isMobile,
    );

    // Exact horizontal centering anchor
    if (position.centerX != null && !position.isCenter) {
      return Positioned(
        top: position.top,
        left: position.centerX,
        child: FractionalTranslation(
          translation: const Offset(-0.5, 0),
          child: pod,
        ),
      );
    }

    if (position.isCenter) {
      return Positioned(
        top: position.top,
        left: 0,
        right: 0,
        child: Center(child: pod),
      );
    }

    return Positioned(
      top: position.top,
      left: position.left,
      right: position.right,
      child: pod,
    );
  }
}

/// A luxury floating status pill representing an opponent player at the multiplayer table.
class MultiplayerOpponentPod extends StatefulWidget {
  final TablePlayer player;
  final bool isCurrentTurn;
  final bool isDealer;
  final int remainingTurnSeconds;
  final VoidCallback? onTap;
  final bool isMobile;

  const MultiplayerOpponentPod({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.isDealer,
    required this.remainingTurnSeconds,
    this.onTap,
    this.isMobile = false,
  });

  @override
  State<MultiplayerOpponentPod> createState() => _MultiplayerOpponentPodState();
}

class _MultiplayerOpponentPodState extends State<MultiplayerOpponentPod>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isDropped = player.status == 'DROPPED';
    final isEliminated = player.status == 'ELIMINATED';
    final isDeclared = player.status == 'DECLARED';
    final isOffline = !player.connected;
    final isMobile = widget.isMobile;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowFactor = widget.isCurrentTurn ? _pulseController.value : 0.0;

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 7 : 12,
              vertical: isMobile ? 3 : 5,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isCurrentTurn
                    ? [const Color(0xEE2A123F), const Color(0xEE160724)]
                    : [const Color(0xEE140A22), const Color(0xEE090412)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isCurrentTurn
                    ? Color.lerp(
                        const Color(0xFFF2CA50),
                        const Color(0xFFFFE082),
                        glowFactor,
                      )!
                    : const Color(0x55D4AF37),
                width: widget.isCurrentTurn ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: isMobile ? 5 : 8,
                  offset: const Offset(0, 2),
                ),
                if (widget.isCurrentTurn)
                  BoxShadow(
                    color: const Color(0xFFF2CA50).withValues(alpha: 0.35 + 0.25 * glowFactor),
                    blurRadius: 10 + 4 * glowFactor,
                    spreadRadius: 1 + glowFactor,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Dealer Badge 'D'
                if (widget.isDealer) ...[
                  Container(
                    width: isMobile ? 14 : 18,
                    height: isMobile ? 14 : 18,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF2CA50), Color(0xFFD4AF37)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'D',
                        style: TextStyle(
                          fontSize: isMobile ? 8.5 : 10,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF241A00),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                ],

                // 2. Opponent Initial / Avatar Circle
                Container(
                  width: isMobile ? 18 : 22,
                  height: isMobile ? 18 : 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isCurrentTurn
                          ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                          : [const Color(0xFF334155), const Color(0xFF1E293B)],
                    ),
                    border: Border.all(
                      color: widget.isCurrentTurn
                          ? const Color(0xFFF2CA50)
                          : Colors.white24,
                      width: 1.0,
                    ),
                  ),
                  child: ClipOval(
                    child: Builder(
                      builder: (context) {
                        ImageProvider? iconImg;
                        if (player.photoURL.isNotEmpty) {
                          if (AvatarCatalog.isCustomPhoto(player.photoURL)) {
                            if (player.photoURL.startsWith('data:image')) {
                              try {
                                final b64 = player.photoURL.split(',').last;
                                iconImg = MemoryImage(base64Decode(b64));
                              } catch (_) {}
                            } else if (player.photoURL.startsWith('http')) {
                              iconImg = NetworkImage(player.photoURL);
                            }
                          } else {
                            iconImg = AssetImage(AvatarCatalog.getThumbAssetPath(player.photoURL));
                          }
                        }
                        if (iconImg != null) {
                          return Image(image: iconImg, fit: BoxFit.cover);
                        }
                        return Center(
                          child: Text(
                            player.displayName.isNotEmpty
                                ? player.displayName[0].toUpperCase()
                                : 'P',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 9.5 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 4 : 6),

                // 3. Opponent Display Name
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 78 : 110),
                  child: Text(
                    widget.isCurrentTurn ? '👑 ${player.displayName}' : player.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: widget.isCurrentTurn ? const Color(0xFFFDE68A) : Colors.white,
                      fontSize: isMobile ? 10.5 : 13,
                      fontWeight: widget.isCurrentTurn ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                if (player.isHost) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'HOST',
                      style: TextStyle(
                        color: const Color(0xFFFDE68A),
                        fontSize: isMobile ? 7 : 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],

                SizedBox(width: isMobile ? 5 : 8),

                // 4. Status or Card Count Badge
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OFFLINE',
                      style: TextStyle(color: Colors.white60, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isEliminated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OUT',
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isDropped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DROPPED',
                      style: TextStyle(color: const Color(0xFFFEF08A), fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isDeclared)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DECLARED',
                      style: TextStyle(color: const Color(0xFFA7F3D0), fontSize: isMobile ? 8 : 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  // Standard Card Count Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 7, vertical: isMobile ? 1.5 : 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x44D4AF37), width: 0.8),
                    ),
                    child: Text(
                      '${player.cardCount} 🂠',
                      style: TextStyle(
                        color: const Color(0xFFE2E8F0),
                        fontSize: isMobile ? 9 : 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                // 5. Active Turn Countdown Timer Badge
                if (widget.isCurrentTurn && !isDropped && !isEliminated) ...[
                  SizedBox(width: isMobile ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      (widget.remainingTurnSeconds <= 0 ? '⏱️ ∞' : '⏱️ ${widget.remainingTurnSeconds}s'),
                      style: TextStyle(
                        color: const Color(0xFFFEF08A),
                        fontSize: isMobile ? 8.5 : 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
