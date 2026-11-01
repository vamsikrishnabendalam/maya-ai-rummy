import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/table_models.dart';

/// Specification for where an opponent pod is seated across the 1754x896 reference canvas.
class MultiplayerSeatPosition {
  final double? left;
  final double? right;
  final double? centerX;
  final double top;
  final bool isCenter;

  const MultiplayerSeatPosition({
    this.left,
    this.right,
    this.centerX,
    required this.top,
    this.isCenter = false,
  });
}

/// Extensible layer that arranges opponent player pods around the table based on max player capacity.
class MultiplayerOpponentsLayer extends StatelessWidget {
  final int maxPlayers;
  final List<TablePlayer> opponents;
  final String currentTurnPlayerId;
  final String dealerPlayerId;
  final int remainingTurnSeconds;
  final void Function(TablePlayer)? onOpponentTap;

  const MultiplayerOpponentsLayer({
    super.key,
    required this.maxPlayers,
    required this.opponents,
    required this.currentTurnPlayerId,
    required this.dealerPlayerId,
    required this.remainingTurnSeconds,
    this.onOpponentTap,
  });

  /// Seat coordinates configured for each table capacity (2, 3, 4, 5, 6 players),
  /// perfectly matched to the royal velvet armchair crests in each hall artwork.
  static List<MultiplayerSeatPosition> getPositionsForPlayerCount(int capacity) {
    switch (capacity) {
      case 2:
        return const [
          // 2-Player: Single opponent centered directly above the central royal armchair
          MultiplayerSeatPosition(centerX: 878, top: 195, isCenter: true),
        ];
      case 3:
        return const [
          // 3-Player: 2 opponents aligned precisely above the 2 royal armchair crests
          MultiplayerSeatPosition(centerX: 550, top: 195),
          MultiplayerSeatPosition(centerX: 1205, top: 195),
        ];
      case 4:
        return const [
          // 4-Player: 3 opponents arrayed directly above the 3 armchair crests
          MultiplayerSeatPosition(centerX: 115, top: 310),
          MultiplayerSeatPosition(centerX: 878, top: 245, isCenter: true),
          MultiplayerSeatPosition(centerX: 1640, top: 310),
        ];
      case 5:
        return const [
          // 5-Player: 4 opponents arrayed directly above the 4 armchair crests in royal arc
          MultiplayerSeatPosition(centerX: 85, top: 310),
          MultiplayerSeatPosition(centerX: 640, top: 245),
          MultiplayerSeatPosition(centerX: 1116, top: 245),
          MultiplayerSeatPosition(centerX: 1670, top: 310),
        ];
      case 6:
      default:
        return const [
          // 6-Player: 5 opponents arrayed directly above the 5 armchair crests
          MultiplayerSeatPosition(centerX: 80, top: 310),
          MultiplayerSeatPosition(centerX: 490, top: 255),
          MultiplayerSeatPosition(centerX: 878, top: 245, isCenter: true),
          MultiplayerSeatPosition(centerX: 1266, top: 255),
          MultiplayerSeatPosition(centerX: 1676, top: 310),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) return const SizedBox.shrink();

    final positions = getPositionsForPlayerCount(maxPlayers);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < opponents.length && i < positions.length; i++) ...[
          _buildPositionedPod(
            position: positions[i],
            player: opponents[i],
          ),
        ],
      ],
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

  const MultiplayerOpponentPod({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    required this.isDealer,
    required this.remainingTurnSeconds,
    this.onTap,
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowFactor = widget.isCurrentTurn ? _pulseController.value : 0.0;

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                if (widget.isCurrentTurn)
                  BoxShadow(
                    color: const Color(0xFFF2CA50).withValues(alpha: 0.35 + 0.25 * glowFactor),
                    blurRadius: 12 + 6 * glowFactor,
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
                    width: 18,
                    height: 18,
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
                    child: const Center(
                      child: Text(
                        'D',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF241A00),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 2. Opponent Initial / Avatar Circle
                Container(
                  width: 22,
                  height: 22,
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
                  child: Center(
                    child: Text(
                      player.displayName.isNotEmpty
                          ? player.displayName[0].toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Opponent Display Name
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    widget.isCurrentTurn ? '✨ ${player.displayName}' : player.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: widget.isCurrentTurn ? const Color(0xFFFDE68A) : Colors.white,
                      fontSize: 13,
                      fontWeight: widget.isCurrentTurn ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                if (player.isHost) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HOST',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // 4. Status or Card Count Badge
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OFFLINE',
                      style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isEliminated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'OUT',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isDropped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'DROPPED',
                      style: TextStyle(color: Color(0xFFFEF08A), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isDeclared)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'DECLARED',
                      style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  // Standard Card Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x44D4AF37), width: 0.8),
                    ),
                    child: Text(
                      '${player.cardCount} 🂠',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                // 5. Active Turn Countdown Timer Badge
                if (widget.isCurrentTurn && !isDropped && !isEliminated) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      '⏱ ${widget.remainingTurnSeconds}s',
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 10,
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

