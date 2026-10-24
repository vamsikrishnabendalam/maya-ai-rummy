import 'package:flutter/material.dart';

/// Contextual status checklist displaying 1st Life, 2nd Life, Turn countdown, and Hand Points.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF070D17).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Turn Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isMyTurn
                  ? const Color(0xFF10B981).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMyTurn ? const Color(0xFF10B981) : Colors.white24,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 11,
                  color: isMyTurn ? const Color(0xFFFBBF24) : Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  isMyTurn
                      ? '${turnSeconds != null ? "$turnSeconds" : "30"}s • YOUR TURN'
                      : 'OPPONENT',
                  style: TextStyle(
                    color: isMyTurn ? const Color(0xFF6EE7B7) : Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 2. 1st Life (Pure Sequence)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: hasFirstLife ? const Color(0xFF042F2E) : const Color(0xFF3E0A16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFirstLife ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasFirstLife ? Icons.check_rounded : Icons.close_rounded,
                  size: 10,
                  color: hasFirstLife ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
                ),
                const SizedBox(width: 3),
                Text(
                  '1st Life',
                  style: TextStyle(
                    color: hasFirstLife ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // 3. 2nd Life (Second Sequence)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: hasSecondLife ? const Color(0xFF042F2E) : const Color(0xFF3F1905),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasSecondLife ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasSecondLife ? Icons.check_rounded : Icons.close_rounded,
                  size: 10,
                  color: hasSecondLife ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A),
                ),
                const SizedBox(width: 3),
                Text(
                  '2nd Life',
                  style: TextStyle(
                    color: hasSecondLife ? const Color(0xFF6EE7B7) : const Color(0xFFFDE68A),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // 4. Deadwood Points Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: points == 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: points == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pts: ',
                  style: TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$points',
                  style: TextStyle(
                    color: points == 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFBBF24),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
