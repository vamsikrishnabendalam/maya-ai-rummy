import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_engine/game_engine.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../providers/game_provider.dart';
import 'card_widget.dart';

/// Modal dialog presented when an opponent (e.g. Maya AI Bot) declares a show.
///
/// Features:
/// 1. Prominent header announcing that the opponent has declared a valid show (0 pts).
/// 2. Clear breakdown of the opponent's declared melds (pure sequence, impure sequence, sets)
///    along with their discarded 14th Finish Card.
/// 3. Clear call-to-action asking the player to review, arrange, and declare their final hand for score.
/// 4. Live display of player's current deadwood penalty points, with smart recommendation
///    and one-tap "Apply Best Melds" if lower score grouping exists.
/// 5. Action buttons to either "Rearrange on Table" or "Declare Final Hand Now".
class OpponentDeclarationModal extends ConsumerWidget {
  final String declarerName;
  final HandPartitionResult botDeclarationResult;
  final Card? finishCard;
  final Card? wildJoker;
  final VoidCallback onRearrange;
  final VoidCallback onDeclareFinalHand;

  const OpponentDeclarationModal({
    super.key,
    this.declarerName = 'Maya (AI Host)',
    required this.botDeclarationResult,
    this.finishCard,
    this.wildJoker,
    required this.onRearrange,
    required this.onDeclareFinalHand,
  });

  static Future<void> show({
    required BuildContext context,
    String declarerName = 'Maya (AI Host)',
    required HandPartitionResult botDeclarationResult,
    Card? finishCard,
    Card? wildJoker,
    required VoidCallback onRearrange,
    required VoidCallback onDeclareFinalHand,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OpponentDeclarationModal(
        declarerName: declarerName,
        botDeclarationResult: botDeclarationResult,
        finishCard: finishCard,
        wildJoker: wildJoker,
        onRearrange: onRearrange,
        onDeclareFinalHand: onDeclareFinalHand,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isTablet =
        Responsive.isTablet(context) || (size.width >= 768 && size.width < 1024);

    final tableState = ref.watch(gameTableProvider);
    final notifier = ref.read(gameTableProvider.notifier);

    final currentScore = tableState.currentScore;
    final allCards = notifier.allGroupedCards();
    final optimalPartition = HandPartitioner.findBestPartition(
      allCards,
      notifier.wildJokerCard,
    );
    final optimalScore = optimalPartition.penaltyScore;
    final canOptimize = optimalScore < currentScore;

    final double cardWidth = isDesktop ? 36.0 : (isTablet ? 32.0 : 28.0);
    final double cardHeight = isDesktop ? 52.0 : (isTablet ? 46.0 : 40.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : (isTablet ? 24 : 14),
        vertical: 16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 680 : 540,
            maxHeight: size.height * 0.90,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF14241C),
                  Color(0xFF0F1B15),
                  Color(0xFF09120E),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Trophy, Title & Close Button
                  _buildHeader(context, isDesktop),

                  // 2. Scrollable Body: Opponent Melds + Player Declaration Prompt
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 22 : 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Opponent Hand Section
                          _buildOpponentHandSection(
                            isDesktop: isDesktop,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),

                          const SizedBox(height: 14),

                          // Player Prompt & Score Section
                          _buildPlayerPromptSection(
                            context: context,
                            ref: ref,
                            isDesktop: isDesktop,
                            currentScore: currentScore,
                            optimalScore: optimalScore,
                            canOptimize: canOptimize,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Action Buttons: Rearrange vs Declare Now
                  _buildBottomActions(
                    context: context,
                    isDesktop: isDesktop,
                    currentScore: currentScore,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 14 : 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0x66000000),
        border: Border(
          bottom: BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF08A), Color(0xFFD4AF37), Color(0xFFB45309)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFF241A00),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$declarerName Declared Show!',
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 17 : 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFEF08A),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF4ADE80),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'VALID SHOW • 0 PTS',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4ADE80),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: onRearrange,
            tooltip: 'Close to rearrange cards',
          ),
        ],
      ),
    );
  }

  // --- Opponent Hand Section ---
  Widget _buildOpponentHandSection({
    required bool isDesktop,
    required double cardWidth,
    required double cardHeight,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 14 : 10),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33D4AF37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.style_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "OPPONENT'S WINNING DECLARATION",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '0 Deadwood PTS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4ADE80),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Declared Groups
          Column(
            children: botDeclarationResult.groups.map((group) {
              final Color badgeColor;
              final IconData badgeIcon;
              if (group.type == HandGroupType.pureSequence) {
                badgeColor = const Color(0xFF4ADE80);
                badgeIcon = Icons.verified_rounded;
              } else if (group.type == HandGroupType.impureSequence) {
                badgeColor = const Color(0xFF38BDF8);
                badgeIcon = Icons.auto_awesome;
              } else if (group.type == HandGroupType.validSet) {
                badgeColor = const Color(0xFFA855F7);
                badgeIcon = Icons.widgets_rounded;
              } else {
                badgeColor = const Color(0xFFF87171);
                badgeIcon = Icons.warning_amber_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x40000000),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    // Group Badge Column
                    SizedBox(
                      width: isDesktop ? 120 : 95,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  group.label,
                                  style: GoogleFonts.outfit(
                                    fontSize: isDesktop ? 10.5 : 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${group.cards.length} cards',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Cards row
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: group.cards.map((c) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: CardWidget(
                                card: c,
                                isWildJoker: JokerUtils.isWildJoker(c, wildJoker),
                                width: cardWidth,
                                height: cardHeight,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Finish Card tile (if present)
          if (finishCard != null) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33D4AF37),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x80D4AF37)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: isDesktop ? 120 : 105,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_circle_rounded,
                              size: 13,
                              color: Color(0xFFFEF08A),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'FINISH CARD',
                                style: GoogleFonts.outfit(
                                  fontSize: isDesktop ? 10.5 : 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFEF08A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '14th Discard',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  CardWidget(
                    card: finishCard!,
                    isWildJoker: JokerUtils.isWildJoker(finishCard!, wildJoker),
                    width: cardWidth,
                    height: cardHeight,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Discarded to Finish slot to complete show declaration.',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Player Prompt & Scoring Section ---
  Widget _buildPlayerPromptSection({
    required BuildContext context,
    required WidgetRef ref,
    required bool isDesktop,
    required int currentScore,
    required int optimalScore,
    required bool canOptimize,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 14 : 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.7),
            const Color(0xFF0F172A).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_rounded,
                size: 17,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 6),
              Text(
                'YOUR FINAL HAND DECLARATION',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Maya has declared her hand. Arrange your remaining 13 cards to minimize penalty points, then declare your final hand for scoring.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: const Color(0xFFCBD5E1),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Penalty Score Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x4D000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: currentScore == 0
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Current Deadwood Penalty:',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        currentScore == 0 ? '0 Points (Zero Penalty)' : '$currentScore Points',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: currentScore == 0
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canOptimize) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      ref.read(gameTableProvider.notifier).autoGroupHand();
                    },
                    label: Text(
                      'Auto-Group ($optimalScore pts)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (canOptimize) ...[
            const SizedBox(height: 6),
            Text(
              '💡 Smart Tip: Rearranging cards or clicking "Auto-Group" above will lower your penalty from $currentScore pts to $optimalScore pts (-${currentScore - optimalScore} pts).',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: const Color(0xFF34D399),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Bottom Action Buttons ---
  Widget _buildBottomActions({
    required BuildContext context,
    required bool isDesktop,
    required int currentScore,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 14 : 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0x66000000),
        border: Border(
          top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // 1. Rearrange Hand Button
          Expanded(
            flex: 4,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.tune_rounded, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 13 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onRearrange,
              label: Text(
                'Rearrange Hand',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 13 : 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Declare Final Hand Button
          Expanded(
            flex: 6,
            child: InkWell(
              onTap: onDeclareFinalHand,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isDesktop ? 13 : 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFD97706),
                      Color(0xFFB45309),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFEF08A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: Color(0xFF241A00),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Declare Final Hand ($currentScore pts)',
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 13.5 : 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF241A00),
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
