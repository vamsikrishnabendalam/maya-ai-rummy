import 'package:flutter/material.dart' hide Card;
import 'package:game_engine/game_engine.dart';
import 'card_widget.dart';

/// Modal dialog showing the complete discard pile history.
class DiscardHistoryModal extends StatelessWidget {
  final List<Card> discardPile;
  final Card? wildJoker;

  const DiscardHistoryModal({
    Key? key,
    required this.discardPile,
    this.wildJoker,
  }) : super(key: key);

  static void show(BuildContext context, {required List<Card> discardPile, Card? wildJoker}) {
    showDialog(
      context: context,
      builder: (ctx) => DiscardHistoryModal(
        discardPile: discardPile,
        wildJoker: wildJoker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reversedPile = discardPile.reversed.toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DISCARD PILE HISTORY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${discardPile.length} card${discardPile.length == 1 ? "" : "s"} discarded so far (newest first)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: 280,
        child: reversedPile.isEmpty
            ? const Center(
                child: Text(
                  'No cards have been discarded yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              )
            : Scrollbar(
                thumbVisibility: true,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 65,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: reversedPile.length,
                  itemBuilder: (context, idx) {
                    final card = reversedPile[idx];
                    final isWild = wildJoker != null &&
                        (card.isPrintedJoker ||
                            (!wildJoker!.isPrintedJoker && card.rank == wildJoker!.rank));

                    return Stack(
                      children: [
                        CardWidget(
                          card: card,
                          isWildJoker: isWild,
                          width: 58,
                          height: 82,
                        ),
                        if (idx == 0)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TOP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}
