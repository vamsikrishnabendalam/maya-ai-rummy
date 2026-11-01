import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_engine/game_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../game/models/card_group.dart';
import '../../../game/presentation/widgets/card_widget.dart';
import '../../../game/presentation/widgets/card_back_widget.dart';
import '../../../game/presentation/widgets/discard_history_modal.dart';
import '../../../game/presentation/widgets/player_hand.dart';
import '../../../game/presentation/widgets/card_animation_layer.dart';
import '../../../game/presentation/widgets/royal_life_checklist_bar.dart';
import '../../../game/providers/game_ui_provider.dart';
import '../../models/table_models.dart';
import '../../providers/multiplayer_providers.dart';
import '../../utils/game_log_exporter.dart';
import '../widgets/multiplayer_table_background.dart';
import '../widgets/multiplayer_opponents_layer.dart';

class MultiplayerTableScreen extends ConsumerStatefulWidget {
  final String gameId;

  const MultiplayerTableScreen({Key? key, required this.gameId}) : super(key: key);

  @override
  ConsumerState<MultiplayerTableScreen> createState() => _MultiplayerTableScreenState();
}

class _MultiplayerTableScreenState extends ConsumerState<MultiplayerTableScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  bool _hasShownResultDialog = false;

  static const double _tableCardW = 68.0;
  static const double _tableCardH = 96.0;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multiplayerGameProvider.notifier).watchGame(widget.gameId);
      ref.read(multiplayerGameProvider.notifier).recordHeartbeat();
    });

    int tickCount = 0;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = ref.read(multiplayerGameProvider);
      final game = state.gameState;
      if (game == null) return;

      tickCount++;

      // Repaint ticking UI every second
      setState(() {});

      if (game.isDeclaring) {
        if (game.declarationDeadline != null && DateTime.now().isAfter(game.declarationDeadline!)) {
          ref.read(multiplayerGameProvider.notifier).checkDeclarationTimeout();
        }
      } else if (game.status == 'ROUND_OVER') {
        if (game.nextRoundStartTime != null && DateTime.now().isAfter(game.nextRoundStartTime!)) {
          ref.read(multiplayerGameProvider.notifier).startNextRound();
        }
      } else if (game.status == 'IN_PROGRESS') {
        final currentUid = ref.read(authProvider)?.uid;
        final isSeated = currentUid != null && game.players.any((p) => p.uid == currentUid);
        if (!isSeated) return;
        final isMyTurn = game.currentTurnPlayerId == currentUid;

        // Turn timeout handling
        if (game.turnDeadline != null) {
          final now = DateTime.now();
          if (isMyTurn && now.isAfter(game.turnDeadline!)) {
            ref.read(multiplayerGameProvider.notifier).handleTurnTimeout();
          } else if (!isMyTurn && now.isAfter(game.turnDeadline!.add(const Duration(seconds: 3)))) {
            ref.read(multiplayerGameProvider.notifier).forceAdvanceTurnOnTimeout();
          }
        }

        // Heartbeat every 5 ticks
        if (tickCount % 5 == 0) {
          ref.read(multiplayerGameProvider.notifier).recordHeartbeat();
        }

        // Check disconnections every 3 ticks
        if (tickCount % 3 == 0) {
          ref.read(multiplayerGameProvider.notifier).checkDisconnections();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final currentGame = ref.read(multiplayerGameProvider).gameState;
      if (currentGame == null || currentGame.gameId != widget.gameId) {
        ref.read(multiplayerGameProvider.notifier).watchGame(widget.gameId);
      }
      ref.read(multiplayerGameProvider.notifier).recordHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(multiplayerGameProvider.notifier).markDisconnected();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    ref.read(multiplayerGameProvider.notifier).markDisconnected();
    super.dispose();
  }

  void _showScoreboardModal(BuildContext context, MultiplayerGameState game) {
    final currentUid = ref.read(authProvider)?.uid;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: AppColors.accent, size: 24),
            const SizedBox(width: 8),
            const Text(
              'TABLE SCOREBOARD',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF081220),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                '${game.playerCount} PLAYERS',
                style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF081220),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('PLAYER', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('CARDS', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('SCORE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Player Rows
              ...game.players.map((p) {
                final isMe = p.uid == currentUid;
                final isCurrentTurn = p.uid == game.currentTurnPlayerId;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.accent.withValues(alpha: 0.12) : const Color(0xFF14243B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrentTurn ? AppColors.accent : (isMe ? AppColors.accent.withValues(alpha: 0.4) : Colors.white10),
                      width: isCurrentTurn ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Player Name & Badges
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isCurrentTurn ? AppColors.accent : Colors.white24,
                              child: Text(
                                p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : 'P',
                                style: TextStyle(color: isCurrentTurn ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${p.displayName}${isMe ? " (You)" : ""}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isMe ? AppColors.accent : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (p.isHost)
                                    const Text('HOST', style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold))
                                  else if (p.uid == game.dealerPlayerId)
                                    const Text('DEALER', style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Card Count
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            '${p.cardCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Score
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            '${p.score} pts',
                            style: TextStyle(
                              color: p.score == 0 ? Colors.greenAccent : Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Status Badge
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.status == 'DROPPED'
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : (isCurrentTurn ? Colors.amber.withValues(alpha: 0.2) : Colors.black26),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: p.status == 'DROPPED'
                                    ? Colors.orangeAccent
                                    : (isCurrentTurn ? Colors.amber : Colors.white24),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              p.status == 'DROPPED'
                                  ? 'DROPPED (${p.score} PTS)'
                                  : (isCurrentTurn
                                      ? (p.misses > 0 ? 'PLAYING (${p.misses}/3 MISS)' : 'PLAYING')
                                      : (p.misses > 0 ? '${p.status} (${p.misses}/3 MISS)' : p.status)),
                              style: TextStyle(
                                color: p.status == 'DROPPED'
                                    ? Colors.orangeAccent
                                    : (isCurrentTurn ? Colors.amberAccent : Colors.white70),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          Builder(
            builder: (actionCtx) {
              final canExport = game.isDeclaring || game.isGameOver;
              return OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: canExport ? AppColors.accent : Colors.white24),
                  foregroundColor: canExport ? AppColors.accent : Colors.white38,
                ),
                icon: Icon(canExport ? Icons.download_rounded : Icons.lock_outline_rounded, size: 16),
                label: Text(
                  canExport ? 'Export Audit Log' : 'Audit Log (Locked During Play)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: canExport
                    ? () async {
                        final fileName = await GameLogExporter.downloadGameLogJson(game);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF1E3A2E),
                              content: Text('Fair-play log downloaded: $fileName (copied to clipboard)'),
                            ),
                          );
                        }
                      }
                    : () {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF2E1A1A),
                            content: Text('Fair-Play Protection: Audit logs are locked during active gameplay to prevent card inspection. Unlocks after declaration or round completion.'),
                          ),
                        );
                      },
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDropConfirmationDialog(BuildContext context, MultiplayerGameState game, int penalty, bool isFirstDrop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Drop Hand?',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isFirstDrop ? 'First Drop Penalty: $penalty PTS' : 'Middle Drop Penalty: $penalty PTS',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to drop out of this round? You will receive $penalty penalty points and sit out until the next round begins.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(multiplayerGameProvider.notifier).dropGame();
            },
            child: const Text('CONFIRM DROP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeclarationDialog() {
    final gameNotifier = ref.read(multiplayerGameProvider.notifier);
    final tableState = ref.read(multiplayerGameProvider);

    if (tableState.selectedCards.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Multiple cards are selected. Please select only 1 card to discard for your declaration!')),
      );
      return;
    }

    if (tableState.selectedCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select 1 card to discard for your declaration!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.accent)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Declare Hand', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to discard ${tableState.selectedCard} and submit your declaration?\n\n'
          'âš ï¸ Wrong show carries an 80-point maximum penalty.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await gameNotifier.declareHand();
              if (res != null && mounted) {
                // Wrong show triggers immediate penalty dialog
                if (res['isValid'] == false) {
                  _showResultDialog(res);
                }
              }
            },
            child: const Text('SUBMIT DECLARATION', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final bool isAborted = result['isAborted'] == true;
    final bool isValid = result['isValid'] == true;
    final results = (result['finalResults'] as List<dynamic>?) ?? [];

    IconData titleIcon = isValid ? Icons.emoji_events : Icons.warning_amber_rounded;
    Color titleColor = isValid ? Colors.amber : Colors.redAccent;
    String titleText = isValid ? 'GAME WON!' : 'WRONG SHOW';

    if (isAborted) {
      titleIcon = Icons.stop_circle_outlined;
      titleColor = Colors.orangeAccent;
      titleText = 'GAME ENDED BY HOST';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: titleColor, width: 2),
        ),
        title: Row(
          children: [
            Icon(titleIcon, color: titleColor, size: 28),
            const SizedBox(width: 10),
            Text(
              titleText,
              style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['message'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 14),
            if (results.isNotEmpty) ...[
              const Text('FINAL SCORES:', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...results.map((r) {
                final isWinner = r is Map ? (r['isWinner'] == true) : (r.isWinner == true);
                final displayName = r is Map ? r['displayName'] : r.displayName;
                final score = r is Map ? r['score'] : r.score;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$displayName',
                            style: TextStyle(
                              color: isWinner ? Colors.greenAccent : Colors.white70,
                              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isWinner) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              '(WINNER)',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$score pts',
                        style: TextStyle(
                          color: isWinner ? Colors.greenAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent),
              foregroundColor: AppColors.accent,
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download Audit Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final game = ref.read(multiplayerGameProvider).gameState;
              if (game != null) {
                final fileName = await GameLogExporter.downloadGameLogJson(game);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E3A2E),
                      content: Text('Downloaded: $fileName (copied to clipboard)'),
                    ),
                  );
                }
              }
            },
          ),
          if (!isValid && !isAborted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/multiplayer');
              },
              child: const Text('Return to Lobby', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/');
              },
              child: const Text('Home Screen', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundOverOverlay(MultiplayerGameState game, String myUid, MultiplayerGameNotifier notifier) {
    final isHost = game.players.any((p) => p.uid == myUid && p.isHost);
    final lastRound = game.roundHistory.isNotEmpty ? game.roundHistory.last : null;
    final winnerName = lastRound != null ? (lastRound['winnerName'] ?? 'Round Winner') : 'Round Winner';
    final isPool = game.gameMode == 'Pool 101' || game.gameMode == 'Pool 201';
    final elimLimit = game.gameMode == 'Pool 101' ? 101 : 201;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E36),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.style_rounded, color: AppColors.accent, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROUND ${game.currentRound} CONCLUDED',
                          style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        Text(
                          '$winnerName won this round with 0 pts',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              const Text(
                'TOURNAMENT STANDINGS',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              ...game.players.map((p) {
                final isElim = p.status == 'ELIMINATED';
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isElim ? Colors.red.withValues(alpha: 0.12) : const Color(0xFF142948),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isElim ? Colors.redAccent.withValues(alpha: 0.4) : Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.displayName,
                            style: TextStyle(
                              color: isElim ? Colors.redAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (p.uid == myUid) ...[
                            const SizedBox(width: 4),
                            const Text('(You)', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (isElim)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPool ? 'ELIMINATED (≥$elimLimit)' : 'OUT',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          Text(
                            '${p.score} pts',
                            style: TextStyle(
                              color: isElim ? Colors.redAccent : AppColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Audit Log', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final fileName = await GameLogExporter.downloadGameLogJson(game);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E3A2E),
                            content: Text('Downloaded: $fileName (copied to clipboard)'),
                          ),
                        );
                      }
                    },
                  ),
                  Builder(
                    builder: (btnCtx) {
                      int remainingSecs = 0;
                      if (game.nextRoundStartTime != null) {
                        remainingSecs = game.nextRoundStartTime!.difference(DateTime.now()).inSeconds.clamp(0, 10);
                      }
                      if (isHost || remainingSecs <= 0) {
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            remainingSecs > 0 ? 'Deal Round ${game.currentRound + 1} (${remainingSecs}s)' : 'Deal Round ${game.currentRound + 1} Now',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: () => notifier.startNextRound(),
                        );
                      } else {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dealing in ${remainingSecs}s...',
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndGameConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132238),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('End Tournament / Game?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'As the table owner, ending the tournament will immediately conclude the match for all players and calculate final standings based on current scores.\n\nAre you sure you want to end this game now?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(multiplayerGameProvider.notifier).endGameByHost();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tournament concluded by table owner.'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to end game: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('END GAME NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclarationBanner(MultiplayerGameState game, String myUid) {
    final isDeclarer = game.declaringPlayerId == myUid;
    final declarerName = game.declaringPlayerName ?? 'Opponent';
    final hasSubmitted = game.submittedPlayerUids.contains(myUid);
    final myPlayer = game.players.firstWhere((p) => p.uid == myUid,
        orElse: () => TablePlayer(uid: myUid, displayName: 'Player', photoURL: '', seatIndex: 0));
    final isDroppedOrElim = myPlayer.status == 'DROPPED' || myPlayer.status == 'ELIMINATED';

    int remainingSeconds = 0;
    if (game.declarationDeadline != null) {
      remainingSeconds = game.declarationDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 30);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDeclarer
              ? [const Color(0xFF1B4332), const Color(0xFF081C15)]
              : (isDroppedOrElim
                  ? [const Color(0xFF2C1E14), const Color(0xFF140C08)]
                  : [const Color(0xFF5A2A00), const Color(0xFF2E1500)]),
        ),
        border: Border(
          bottom: BorderSide(
            color: isDeclarer ? AppColors.accent : (isDroppedOrElim ? Colors.orangeAccent : Colors.amberAccent),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDeclarer
                ? Icons.emoji_events_rounded
                : (isDroppedOrElim ? Icons.exit_to_app_rounded : Icons.notification_important_rounded),
            color: isDeclarer ? AppColors.accent : (isDroppedOrElim ? Colors.orangeAccent : Colors.amberAccent),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isDeclarer
                      ? 'YOU DECLARED A VALID SHOW (0 PTS)!'
                      : (isDroppedOrElim
                          ? (myPlayer.status == 'DROPPED'
                              ? 'YOU DROPPED FROM THIS ROUND (${myPlayer.score} PTS)'
                              : 'YOU WERE ELIMINATED (${myPlayer.score} PTS)')
                          : '🔔 $declarerName HAS DECLARED!'),
                  style: TextStyle(
                    color: isDeclarer ? AppColors.accent : (isDroppedOrElim ? Colors.orangeAccent : Colors.amberAccent),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDeclarer
                      ? 'Waiting for opponents to arrange and submit their hands...'
                      : (isDroppedOrElim
                          ? 'Your drop penalty is locked in at ${myPlayer.score} pts. Waiting for round to conclude...'
                          : (hasSubmitted
                              ? '✅ Your hand is submitted! Waiting for other players...'
                              : 'Arrange your cards to minimize penalty points, then tap "SUBMIT FINAL HAND".')),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isDroppedOrElim)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: remainingSeconds <= 10 ? Colors.redAccent : AppColors.accent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: remainingSeconds <= 10 ? Colors.redAccent : AppColors.accent,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${remainingSeconds}s',
                    style: TextStyle(
                      color: remainingSeconds <= 10 ? Colors.redAccent : AppColors.accent,
                      fontSize: 13,
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

  String _computeMultiplayerToast({
    required MultiplayerGameState game,
    required bool isMyTurn,
    required bool isDrawPhase,
    required bool isDiscardPhase,
    required bool isSelectedCard,
    required bool isSelectedCardFromOpen,
    required bool isDropped,
  }) {
    if (game.isDeclaring) {
      return '${game.declaringPlayerName ?? "Opponent"} has declared! Review cards.';
    }
    if (isDropped) {
      return 'You dropped from this round. Waiting for next deal...';
    }
    if (isMyTurn) {
      if (isDrawPhase) {
        return 'Your Turn! Tap Closed Deck or Open Pile to draw.';
      }
      if (isDiscardPhase) {
        if (isSelectedCard) {
          if (isSelectedCardFromOpen) {
            return 'Card drawn from open pile cannot be discarded!';
          }
          return 'Card selected! Tap Discard or drop in Finish Slot.';
        }
        return 'Drew 14th card! Select 1 card to Discard or Declare.';
      }
    }
    final currentTurnPlayer = game.players.firstWhere(
      (p) => p.uid == game.currentTurnPlayerId,
      orElse: () => TablePlayer(uid: '', displayName: 'Opponent', photoURL: '', seatIndex: 0),
    );
    return "${currentTurnPlayer.displayName}'s turn...";
  }

  Widget _buildMultiplayerToastPill(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitOpponentsBar(List<TablePlayer> opponents, MultiplayerGameState game) {
    if (opponents.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: opponents.map((opp) {
          final isTurn = opp.uid == game.currentTurnPlayerId;
          final isOppDropped = opp.status == 'DROPPED';
          final isOppEliminated = opp.status == 'ELIMINATED';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: isTurn
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                  : const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTurn
                    ? const Color(0xFFFBBF24)
                    : (isOppDropped
                        ? Colors.orangeAccent
                        : (isOppEliminated ? Colors.redAccent : Colors.white12)),
                width: isTurn ? 1.5 : 1,
              ),
              boxShadow: isTurn
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isTurn ? const Color(0xFFFBBF24) : Colors.white24,
                      child: Text(
                        opp.displayName.isNotEmpty ? opp.displayName[0].toUpperCase() : 'P',
                        style: TextStyle(
                          color: isTurn ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '${opp.cardCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 55),
                      child: Text(
                        opp.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      isTurn ? 'Turn...' : '${opp.score} pts',
                      style: TextStyle(
                        color: isTurn ? const Color(0xFFFBBF24) : AppColors.textMuted,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final tableState = ref.watch(multiplayerGameProvider);
    final game = tableState.gameState;
    final notifier = ref.read(multiplayerGameProvider.notifier);

    // Realtime game completion listener: triggers final scoreboard dialog for all connected players
    ref.listen<MultiplayerGameTableState>(multiplayerGameProvider, (prev, next) {
      final g = next.gameState;
      final prevG = prev?.gameState;
      if (g != null && prevG != null && g.currentRound > prevG.currentRound) {
        _hasShownResultDialog = false;
      }
      if (g != null && g.isGameOver && !_hasShownResultDialog) {
        _hasShownResultDialog = true;
        final wasAbortedByHost = g.actionLog.any((a) => a['type'] == 'HOST_ENDED_GAME');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showResultDialog({
              'isValid': !wasAbortedByHost,
              'isAborted': wasAbortedByHost,
              'message': wasAbortedByHost
                  ? 'The table host ended the match before completion. Match cancelled with 0 points for all players.'
                  : '${g.declaringPlayerName ?? "Winner"} won the match with 0 points!',
              'finalResults': g.finalResults.map((r) => r.toJson()).toList(),
            });
          }
        });
      }
    });

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF081220),
        body: Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => context.go('/multiplayer'),
            child: const Text('Please Sign In'),
          ),
        ),
      );
    }

    if (game == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF081220),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 14),
              Text('Connecting to Multiplayer Table...', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final isSeated = game.players.any((p) => p.uid == user.uid);
    if (!isSeated) {
      return Scaffold(
        backgroundColor: const Color(0xFF081220),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: const Color(0xFF101F36),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Not a Seated Player',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This match (#${game.roomCode}) is currently in progress with ${game.playerCount} players. You are not a seated participant in this match.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                  onPressed: () => context.go('/multiplayer'),
                  child: const Text('Back to Tables'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final myPlayer = game.players.firstWhere((p) => p.uid == user.uid, orElse: () => TablePlayer(uid: user.uid, displayName: 'Player', photoURL: '', seatIndex: 0));
    final isDropped = myPlayer.status == 'DROPPED';
    final isMyTurn = !isDropped && game.isMyTurn(user.uid);
    final isDrawPhase = game.isDrawPhase;
    final isDiscardPhase = game.isDiscardPhase;
    final myUid = user.uid;

    final opponents = game.players.where((p) => p.uid != myUid).toList();

    final isSelectedCardFromOpen = tableState.selectedCard != null &&
        game.cardDrawnFromOpenThisTurn != null &&
        tableState.selectedCard == game.cardDrawnFromOpenThisTurn;

    final canDiscard = isMyTurn &&
        isDiscardPhase &&
        tableState.selectedCard != null &&
        !isSelectedCardFromOpen &&
        !game.isDeclaring;
    final canDeclare = isMyTurn &&
        isDiscardPhase &&
        tableState.selectedCard != null &&
        !game.isDeclaring;

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isFirstDrop = game.turnNumber <= 1 && !tableState.hasDrawnThisTurn;
    final dropPenalty = isFirstDrop ? game.firstDropPenalty : game.middleDropPenalty;
    final canDrop = !game.isDeclaring && isMyTurn && isDrawPhase && !isDropped;

    final toastMessage = _computeMultiplayerToast(
      game: game,
      isMyTurn: isMyTurn,
      isDrawPhase: isDrawPhase,
      isDiscardPhase: isDiscardPhase,
      isSelectedCard: tableState.selectedCard != null,
      isSelectedCardFromOpen: isSelectedCardFromOpen,
      isDropped: isDropped,
    );

    final int remainingTurnSeconds = game.turnDeadline != null
        ? game.turnDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 99)
        : 30;

    final Card? wildJoker = (game.hasPlayerOpenedJoker(user.uid) || !game.isClosedJoker) ? game.openJoker : null;

    final mayaAiMultiplayerCanvas = Center(
      child: AspectRatio(
        aspectRatio: 1754 / 896,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1754,
            height: 896,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. LAYER 1: 3D PERSPECTIVE WARPED TABLE SURFACE (THE FLAT CARDS)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(-1.15)
                        ..translate(0.0, 200.0),
                      child: SizedBox(
                        width: 1754,
                        height: 896,
                        child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 395,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Closed Deck Stack with Perpendicular Wild Joker Tucked Underneath
                                  _buildPerspectiveClosedDeckWithTuckedJoker(
                                    context: context,
                                    count: game.closedDeckRemaining,
                                    wildJoker: game.openJoker,
                                    isClosedJoker: game.isClosedJoker,
                                    isJokerOpened: game.hasPlayerOpenedJoker(user.uid),
                                    hasLife: notifier.hasFirstLife,
                                    onOpenClosedJoker: () {
                                      if (notifier.hasFirstLife) {
                                        notifier.openClosedJoker();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Form a Pure Sequence (Life) of 3+ cards to view the Joker.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    canDraw: !game.isDeclaring && isMyTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromClosed(),
                                  ),

                                  const SizedBox(width: 32),

                                  // 2. Open Discard Pile (Showing up to 5 overlapping cards + Drag & Drop Discard Target)
                                  _buildPerspectiveOpenPile(
                                    context: context,
                                    discardPile: game.openPile,
                                    wildJoker: wildJoker,
                                    canDraw: !game.isDeclaring && isMyTurn && isDrawPhase,
                                    onDraw: () => notifier.drawFromOpen(),
                                    canDiscard: isMyTurn && isDiscardPhase && !game.isDeclaring,
                                    onDiscardCard: (card) {
                                      if (game.isDeclaring) return;
                                      if (!isMyTurn || !isDiscardPhase) return;
                                      if (card == game.cardDrawnFromOpenThisTurn) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Cannot discard the card drawn from the open pile.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      notifier.discardCard(card);
                                    },
                                    onShowHistory: () {
                                      if (game.openPile.isNotEmpty) {
                                        DiscardHistoryModal.show(
                                          context,
                                          discardPile: game.openPile,
                                          wildJoker: wildJoker,
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(width: 32),

                                  // 3. Finish / Declare Slot
                                  _buildPerspectiveFinishSlot(
                                    context: context,
                                    isActivated: canDeclare ||
                                        (isMyTurn && isDiscardPhase && ref.watch(gameUIProvider).isDragging),
                                    canAcceptDrop: isMyTurn && isDiscardPhase && !game.isDeclaring,
                                    canDeclare: canDeclare,
                                    onDeclare: canDeclare ? _showDeclarationDialog : null,
                                    onCardDeclared: canDeclare
                                        ? (card) {
                                            notifier.selectCard(card);
                                            _showDeclarationDialog();
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

                // 2. LAYER 2: MULTIPLAYER OPPONENTS LAYER (Armchair seated opponent in 2P, extensible to 3-6P)
                Positioned.fill(
                  child: MultiplayerOpponentsLayer(
                    maxPlayers: game.playerCount,
                    opponents: opponents,
                    currentTurnPlayerId: game.currentTurnPlayerId,
                    dealerPlayerId: game.dealerPlayerId,
                    remainingTurnSeconds: remainingTurnSeconds,
                    onOpponentTap: myPlayer.isHost && game.status == 'IN_PROGRESS'
                        ? (p) => _showKickPlayerFromGameDialog(context, p)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09141A),
      body: MultiplayerTableBackground(
        maxPlayers: game.playerCount,
        child: Stack(
          children: [
            // 1. Center 3D Table Surface & Opponents
            Positioned.fill(
              child: mayaAiMultiplayerCanvas,
            ),

            // 2. Top HUD Navigation & Control Bar (Pinned to literal top: 0 of screen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHudBar(
                context,
                game: game,
                tableState: tableState,
                notifier: notifier,
                user: user,
                toastMessage: toastMessage,
                isMyTurn: isMyTurn,
                wildJoker: wildJoker,
                myUid: myUid,
              ),
            ),

            // 3. Declaration Banner (when a player declares)
            if (game.isDeclaring)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: _buildDeclarationBanner(game, myUid),
              ),

            // 4. Player 13-Card Hand Tray (Pinned to literal bottom: 2 of screen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 1440 : (Responsive.isTablet(context) ? 1120 : 960),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RepaintBoundary(
                        child: PlayerHand(
                          cardGroups: tableState.cardGroups,
                        wildJokerCard: wildJoker,
                        selectedCard: tableState.selectedCard,
                        selectedCards: tableState.selectedCards,
                        isDiscardPhase: !game.isDeclaring && isMyTurn && isDiscardPhase,
                        onCardTap: (card) => notifier.selectCard(card),
                        onCardMoved: (card, fromGroupId, toGroupId) {
                          notifier.moveCardBetweenGroups(
                            card,
                            fromGroupId,
                            toGroupId,
                            tableState.cardGroups
                                .firstWhere((g) => g.id == toGroupId,
                                    orElse: () => tableState.cardGroups.first)
                                .cards
                                .length,
                          );
                        },
                        onCardMovedToIndex: (card, fromGroupId, toGroupId, insertIndex) {
                          notifier.moveCardBetweenGroups(card, fromGroupId, toGroupId, insertIndex);
                        },
                        onCardReordered: (groupId, oldIndex, newIndex) {
                          notifier.moveCardWithinGroup(groupId, oldIndex, newIndex);
                        },
                        onCardMovedToNewGroup: (card, fromGroupId) {
                          notifier.moveCardToNewGroup(card, fromGroupId);
                        },
                        onCardDragStarted: (card, groupId) {
                          ref.read(gameUIProvider.notifier).startDrag(card, groupId);
                        },
                        onDragEnded: () {
                          ref.read(gameUIProvider.notifier).endDrag();
                        },
                        onDiscard: (card) {
                          if (game.isDeclaring) return;
                          if (!isMyTurn || !isDiscardPhase) return;
                          if (card == game.cardDrawnFromOpenThisTurn) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot discard the card drawn from the open pile.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          notifier.discardCard(card);
                        },
                      ),
                    ),
                      const SizedBox(height: 2),
                      RoyalLifeChecklistBar(
                        hasFirstLife: notifier.hasFirstLife,
                        hasSecondLife: notifier.hasSecondLife,
                        points: tableState.currentScore,
                        isMyTurn: isMyTurn,
                        turnSeconds: remainingTurnSeconds,
                        instructionText: toastMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Left Action Controls: Drop, Sort Hand, AI Group
            Positioned(
              left: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildLeftThumbControls(
                context,
                canDrop: canDrop,
                dropPenalty: dropPenalty,
                isFirstDrop: isFirstDrop,
                game: game,
                notifier: notifier,
                isDesktop: isDesktop,
              ),
            ),

            // 6. Right Action Controls: Group, Discard, Declare Hand
            Positioned(
              right: isDesktop ? 48 : 16,
              bottom: 8,
              child: _buildRightThumbControls(
                context,
                notifier: notifier,
                tableState: tableState,
                game: game,
                user: user,
                canDiscard: canDiscard,
                canDeclare: canDeclare,
                isMyTurn: isMyTurn,
                isDiscardPhase: isDiscardPhase,
                isDesktop: isDesktop,
              ),
            ),

            // 7. Round Over Overlay (if round completed)
            if (game.isRoundOver)
              _buildRoundOverOverlay(game, myUid, notifier),

            // 8. Card Animation Layer (Deals & discards flight)
            const Positioned.fill(
              child: CardAnimationLayer(),
            ),
          ],
        ),
      ),
    );
  }

  /// Closed Deck Stack with Perpendicular Wild Joker tucked horizontally underneath
  Widget _buildPerspectiveClosedDeckWithTuckedJoker({
    required BuildContext context,
    required int count,
    required Card? wildJoker,
    required bool isClosedJoker,
    required bool isJokerOpened,
    required bool hasLife,
    required VoidCallback onOpenClosedJoker,
    required bool canDraw,
    required VoidCallback onDraw,
  }) {
    final bool showJokerFace = !isClosedJoker || isJokerOpened;
    const double jokerW = 65.0;
    const double jokerH = 91.0;

    return SizedBox(
      width: _tableCardW + 42.0,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // 1. Perpendicular Wild Joker tucked under closed deck
          Positioned(
            left: 8,
            top: (_tableCardH - jokerW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: jokerW,
                height: jokerH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 8,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: (showJokerFace && wildJoker != null)
                    ? CardWidget(
                        card: wildJoker,
                        isWildJoker: false,
                        width: jokerW,
                        height: jokerH,
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CardBackWidget(
                            width: jokerW,
                            height: jokerH,
                            showPulse: false,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.shade700,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: Colors.amber.shade200,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // 2. Physical 3D paper stack effect: layered card rims
          Positioned(
            right: 4.5,
            top: 4.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6D5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x445D4037), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2.5,
            top: 2.5,
            child: Container(
              width: _tableCardW,
              height: _tableCardH,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F0E4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x335D4037), width: 0.8),
              ),
            ),
          ),

          // 3. Top Interactive Closed Deck Card
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: canDraw ? onDraw : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: canDraw
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                          : Colors.black.withValues(alpha: 0.65),
                      blurRadius: canDraw ? 14 : 7,
                      spreadRadius: canDraw ? 2.5 : 0,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: CardBackWidget(
                  width: _tableCardW,
                  height: _tableCardH,
                  showPulse: canDraw,
                ),
              ),
            ),
          ),

          // 4. Deck Count Chip Badge
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1E12), Color(0xFF140D07)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2CA50), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFDE68A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open Discard Pile showing up to 5 overlapping cards + Drag & Drop Discard Target
  Widget _buildPerspectiveOpenPile({
    required BuildContext context,
    required List<Card> discardPile,
    required Card? wildJoker,
    required bool canDraw,
    required VoidCallback onDraw,
    required bool canDiscard,
    required void Function(Card)? onDiscardCard,
    required VoidCallback onShowHistory,
  }) {
    final visibleDiscards = discardPile.length <= 5
        ? discardPile
        : discardPile.sublist(discardPile.length - 5);
    final count = visibleDiscards.length;
    final double stepX = _tableCardW * 0.46;
    final totalWidth = count <= 1 ? _tableCardW : (_tableCardW + (count - 1) * stepX);

    final pileWidget = SizedBox(
      width: totalWidth,
      height: _tableCardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count == 0)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: _tableCardW,
                height: _tableCardH,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'EMPTY',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ),

          for (var i = 0; i < count; i++) ...[
            Positioned(
              left: i * stepX,
              top: 0,
              child: GestureDetector(
                onTap: (i == count - 1 && canDraw) ? onDraw : null,
                child: Container(
                  width: _tableCardW,
                  height: _tableCardH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (i == count - 1 && canDraw)
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                            : Colors.black.withValues(alpha: 0.5),
                        blurRadius: (i == count - 1 && canDraw) ? 12 : 5,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: CardWidget(
                    card: visibleDiscards[i],
                    isWildJoker: JokerUtils.isWildJoker(visibleDiscards[i], wildJoker),
                    width: _tableCardW,
                    height: _tableCardH,
                  ),
                ),
              ),
            ),
          ],

          if (count > 0)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onShowHistory,
                child: Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFBBF24), width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: Color(0xFFFDE68A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) => canDiscard,
      onAcceptWithDetails: (details) {
        if (details.data is CardDragData) {
          onDiscardCard?.call((details.data as CardDragData).card);
        } else if (details.data is Card) {
          onDiscardCard?.call(details.data as Card);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.75),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: pileWidget,
        );
      },
    );
  }

  /// Finish / Declare Slot with Drag & Drop declaration support
  Widget _buildPerspectiveFinishSlot({
    required BuildContext context,
    required bool isActivated,
    required bool canAcceptDrop,
    required bool canDeclare,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    Widget buildSlotContainer(bool isHovering) {
      final active = isActivated || isHovering || canDeclare;
      return GestureDetector(
        onTap: canDeclare ? onDeclare : null,
        child: Container(
          width: _tableCardW,
          height: _tableCardH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: active
                  ? [
                      const Color(0x44F59E0B),
                      const Color(0x22FBBF24),
                    ]
                  : [
                      const Color(0x33120424),
                      const Color(0x220A0214),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFFFBBF24) : const Color(0x55F59E0B),
              width: active ? 2.2 : 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withValues(alpha: isHovering ? 0.8 : 0.55),
                      blurRadius: isHovering ? 20 : 14,
                      spreadRadius: isHovering ? 3.5 : 2.5,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: active ? const Color(0xFFFBBF24) : const Color(0xFFFBBF24).withValues(alpha: 0.6),
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                'FINISH',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: active ? const Color(0xFFFDE68A) : Colors.white70,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '14th Card',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFFFDE68A).withValues(alpha: 0.8) : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onCardDeclared != null) {
      return DragTarget<Object>(
        onWillAcceptWithDetails: (_) => canAcceptDrop,
        onAcceptWithDetails: (details) {
          if (details.data is CardDragData) {
            onCardDeclared((details.data as CardDragData).card);
          } else if (details.data is Card) {
            onCardDeclared(details.data as Card);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.8),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: buildSlotContainer(isHovering),
          );
        },
      );
    }

    return buildSlotContainer(false);
  }

  Widget _buildTopHudBar(
    BuildContext context, {
    required MultiplayerGameState game,
    required MultiplayerGameTableState tableState,
    required MultiplayerGameNotifier notifier,
    required dynamic user,
    required String toastMessage,
    required bool isMyTurn,
    required Card? wildJoker,
    required String myUid,
  }) {
    final size = MediaQuery.of(context).size;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isTablet = Responsive.isTablet(context) || (size.width >= 768 && size.width < 1024);
    final isLockedJoker = game.isClosedJoker && !game.hasPlayerOpenedJoker(user.uid);
    final isHost = game.players.any((p) => p.uid == myUid && p.isHost);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isDesktop ? 6 : 4),
        bottom: isDesktop ? 8 : 5,
        left: isDesktop ? 18 : 8,
        right: isDesktop ? 18 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF09141A), Color(0xFF040A0D)],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Title, Game mode badges, Room Code, Mini Joker
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MAYA AI RUMMY',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF2CA50),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 8 : 5,
                      vertical: isDesktop ? 3.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2CA50).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${game.playerCount}-MAX',
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF2CA50),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 8 : 5,
                      vertical: isDesktop ? 3.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '#${game.roomCode}',
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 6 : 4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 8 : 5,
                      vertical: isDesktop ? 3.5 : 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222B32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      game.gameMode.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: isDesktop ? 10.0 : 8.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD0C5AF),
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),
                  _buildMiniWildJokerPill(wildJoker, isLockedJoker, isDesktop: isDesktop),
                ],
              ),

              // Right: Drop Rules, Scoreboard, Logs, Players (Host), Exit
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDesktop || size.width >= 1100) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 9 : 6,
                        vertical: isDesktop ? 5 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF182128),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '1st: ${game.firstDropPenalty}p • Mid: ${game.middleDropPenalty}p',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: isDesktop ? 10.5 : 9.0,
                          color: const Color(0xFF86EFAC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 8 : 5),
                  ],

                  // Scoreboard
                  InkWell(
                    onTap: () => _showScoreboardModal(context, game),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E2413), Color(0xFF181F26)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF2CA50).withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_chart_rounded, size: isDesktop ? 14 : 11.5, color: const Color(0xFFF2CA50)),
                          const SizedBox(width: 4),
                          Text(
                            'Scoreboard',
                            style: GoogleFonts.cinzel(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),

                  // Logs
                  InkWell(
                    onTap: () async {
                      final fileName = await GameLogExporter.downloadGameLogJson(game);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E3A2E),
                            content: Text('Fair-play log downloaded: $fileName (copied to clipboard)'),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_edu_rounded, size: isDesktop ? 14 : 11.5, color: const Color(0xFF93C5FD)),
                          const SizedBox(width: 4),
                          Text(
                            'Logs',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDBEAFE),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 5),

                  // Host Player Management
                  if (isHost && !game.isCompleted) ...[
                    InkWell(
                      onTap: () => _showManagePlayersModal(context, game, myUid),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 10 : 7,
                          vertical: isDesktop ? 5.5 : 3.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E2413), Color(0xFF181F26)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF2CA50).withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.manage_accounts_rounded, size: isDesktop ? 14 : 11.5, color: const Color(0xFFF2CA50)),
                            const SizedBox(width: 4),
                            Text(
                              'Players',
                              style: GoogleFonts.cinzel(
                                fontSize: isDesktop ? 11.5 : 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF2CA50),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 8 : 5),
                  ],

                  // Exit
                  InkWell(
                    onTap: () => _handleExitGame(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 10 : 7,
                        vertical: isDesktop ? 5.5 : 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3F1417), Color(0xFF1A0A0C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout_rounded, size: isDesktop ? 14 : 11.5, color: const Color(0xFFF87171)),
                          const SizedBox(width: 4),
                          Text(
                            'Exit',
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 11.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFCA5A5),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Exactly Center-Screen Toast Guidance Pill
          Center(
            child: _buildToastPill(toastMessage, isDesktop: isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftThumbControls(
    BuildContext context, {
    required bool canDrop,
    required int dropPenalty,
    required bool isFirstDrop,
    required MultiplayerGameState game,
    required MultiplayerGameNotifier notifier,
    bool isDesktop = false,
  }) {
    final double padH = isDesktop ? 18.0 : 10.0;
    final double padV = isDesktop ? 11.0 : 7.0;
    final double iconSize = isDesktop ? 19.0 : 14.0;
    final double fontSize = isDesktop ? 14.0 : 10.5;
    final double gap = isDesktop ? 9.0 : 6.0;

    return Padding(
      padding: EdgeInsets.only(right: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drop Button
          InkWell(
            onTap: canDrop ? () => _showDropConfirmationDialog(context, game, dropPenalty, isFirstDrop) : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: canDrop
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                      )
                    : null,
                color: canDrop ? null : const Color(0xFF1B2228),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canDrop ? const Color(0xFFFCA5A5) : const Color(0x66D4AF37),
                  width: canDrop ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: canDrop ? const Color(0xFFDC2626).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.4),
                    blurRadius: canDrop ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, size: iconSize, color: canDrop ? const Color(0xFFFFF1F2) : const Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                  Text(
                    'Drop ($dropPenalty)',
                    style: GoogleFonts.outfit(
                      color: canDrop ? const Color(0xFFFFF1F2) : const Color(0xFF94A3B8),
                      fontSize: fontSize,
                      fontWeight: canDrop ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // Sort Button
          InkWell(
            onTap: () => notifier.sortHandAscending(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF15803D), Color(0xFF0E4B24)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_vert_rounded, size: iconSize, color: const Color(0xFFDCFCE7)),
                  const SizedBox(width: 5),
                  Text(
                    'Sort Hand',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFDCFCE7),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: gap),

          // AI Group Button
          InkWell(
            onTap: () => notifier.autoGroupHand(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2CA50), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.7),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: iconSize, color: const Color(0xFFFDE68A)),
                  const SizedBox(width: 5),
                  Text(
                    'AI Group',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFDE68A),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightThumbControls(
    BuildContext context, {
    required MultiplayerGameNotifier notifier,
    required MultiplayerGameTableState tableState,
    required MultiplayerGameState game,
    required dynamic user,
    required bool canDiscard,
    required bool canDeclare,
    required bool isMyTurn,
    required bool isDiscardPhase,
    bool isDesktop = false,
  }) {
    final double padH = isDesktop ? 18.0 : 10.0;
    final double padV = isDesktop ? 11.0 : 7.0;
    final double iconSize = isDesktop ? 19.0 : 14.0;
    final double fontSize = isDesktop ? 14.0 : 10.5;
    final double declarePadH = isDesktop ? 26.0 : 16.0;
    final double gap = isDesktop ? 9.0 : 6.0;

    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 10 : 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group Button
              InkWell(
                onTap: () => notifier.groupSelectedCards(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF93C5FD), width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded, size: iconSize, color: const Color(0xFFEFF6FF)),
                      const SizedBox(width: 5),
                      Text(
                        tableState.selectedCards.length >= 2
                            ? 'Group (${tableState.selectedCards.length})'
                            : 'Group',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFEFF6FF),
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 8 : 5),

              // Discard Button with DragTarget
              DragTarget<Object>(
                onWillAcceptWithDetails: (_) => isMyTurn && isDiscardPhase && !game.isDeclaring,
                onAcceptWithDetails: (details) {
                  Card? droppedCard;
                  if (details.data is CardDragData) {
                    droppedCard = (details.data as CardDragData).card;
                  } else if (details.data is Card) {
                    droppedCard = details.data as Card;
                  }
                  if (droppedCard != null) {
                    notifier.discardCard(droppedCard);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  final active = canDiscard || isHovering;
                  return InkWell(
                    onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 20 : 12,
                        vertical: padV,
                      ),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                            : null,
                        color: active ? null : const Color(0xFF1B2228),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHovering
                              ? const Color(0xFFFFFBEB)
                              : (active ? const Color(0xFFFDE68A) : const Color(0x66D4AF37)),
                          width: active ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: active
                                ? const Color(0xFFF59E0B).withValues(alpha: isHovering ? 0.95 : 0.7)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: active ? (isHovering ? 14 : 10) : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: iconSize,
                            color: active ? const Color(0xFF1F1200) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHovering ? 'Drop to Discard' : 'Discard',
                            style: GoogleFonts.outfit(
                              color: active ? const Color(0xFF1F1200) : const Color(0xFF94A3B8),
                              fontSize: fontSize,
                              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: gap),

          // Declare Hand (or Submit Show) Full Width Button with DragTarget
          Builder(
            builder: (ctx) {
              if (game.isDeclaring) {
                if (game.declaringPlayerId == user.uid) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: declarePadH, vertical: padV + 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Center(
                      child: Text('0 PTS (Declared)', style: GoogleFonts.outfit(color: AppColors.accent, fontSize: fontSize, fontWeight: FontWeight.bold)),
                    ),
                  );
                }
                final isSubmitted = game.submittedPlayerUids.contains(user.uid);
                return InkWell(
                  onTap: isSubmitted ? null : () => notifier.submitFinalHand(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: declarePadH, vertical: padV + 2),
                    decoration: BoxDecoration(
                      gradient: isSubmitted ? null : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF14B8A6)]),
                      color: isSubmitted ? Colors.white12 : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSubmitted ? Colors.white24 : const Color(0xFFA7F3D0)),
                    ),
                    child: Center(
                      child: Text(
                        isSubmitted ? 'Submitted' : 'Submit Hand',
                        style: GoogleFonts.outfit(
                          color: isSubmitted ? Colors.white54 : Colors.black,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return DragTarget<Object>(
                onWillAcceptWithDetails: (_) => isMyTurn && isDiscardPhase && !game.isDeclaring,
                onAcceptWithDetails: (details) {
                  Card? droppedCard;
                  if (details.data is CardDragData) {
                    droppedCard = (details.data as CardDragData).card;
                  } else if (details.data is Card) {
                    droppedCard = details.data as Card;
                  }
                  if (droppedCard != null) {
                    notifier.selectCard(droppedCard);
                    _showDeclarationDialog();
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  final active = canDeclare || isHovering;
                  return InkWell(
                    onTap: canDeclare ? _showDeclarationDialog : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: declarePadH, vertical: padV + 2),
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
                              )
                            : null,
                        color: active ? null : const Color(0xFF1B2228),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? const Color(0xFFFEF08A) : const Color(0x66D4AF37),
                          width: active ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: active
                                ? const Color(0xFFF59E0B).withValues(alpha: isHovering ? 0.95 : 0.7)
                                : Colors.black.withValues(alpha: 0.4),
                            blurRadius: active ? (isHovering ? 16 : 12) : 4,
                            offset: const Offset(0, 3),
                          ),
                          if (active)
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: iconSize + 2,
                            color: active ? const Color(0xFF241A00) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Declare Hand',
                            style: GoogleFonts.outfit(
                              color: active ? const Color(0xFF241A00) : const Color(0xFF94A3B8),
                              fontSize: fontSize,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToastPill(String message, {bool isDesktop = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18.0 : 12.0,
        vertical: isDesktop ? 6.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141D24).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: isDesktop ? 14 : 11,
            color: const Color(0xFFF2CA50),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 12.5 : 10.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFAF7F2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniWildJokerPill(Card? wildJoker, bool isLocked, {bool isDesktop = false}) {
    String rankStr = '7';
    String suitStr = '♠';
    bool isRed = false;

    if (wildJoker != null) {
      if (wildJoker.isPrintedJoker) {
        rankStr = 'JKR';
        suitStr = '★';
      } else {
        switch (wildJoker.rank) {
          case Rank.ace: rankStr = 'A'; break;
          case Rank.king: rankStr = 'K'; break;
          case Rank.queen: rankStr = 'Q'; break;
          case Rank.jack: rankStr = 'J'; break;
          case Rank.ten: rankStr = '10'; break;
          case Rank.nine: rankStr = '9'; break;
          case Rank.eight: rankStr = '8'; break;
          case Rank.seven: rankStr = '7'; break;
          case Rank.six: rankStr = '6'; break;
          case Rank.five: rankStr = '5'; break;
          case Rank.four: rankStr = '4'; break;
          case Rank.three: rankStr = '3'; break;
          case Rank.two: rankStr = '2'; break;
          default: rankStr = '7'; break;
        }
        switch (wildJoker.suit) {
          case Suit.hearts: suitStr = '♥'; isRed = true; break;
          case Suit.diamonds: suitStr = '♦'; isRed = true; break;
          case Suit.clubs: suitStr = '♣'; isRed = false; break;
          case Suit.spades: suitStr = '♠'; isRed = false; break;
          default: suitStr = '♠'; isRed = false; break;
        }
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 11 : 8,
        vertical: isDesktop ? 4.5 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF222B32).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'JOKER',
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 10.5 : 8.5,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD0C5AF),
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: isDesktop ? 7 : 5),
          if (isLocked || wildJoker == null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 6 : 4,
                vertical: isDesktop ? 2 : 1,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF141D24),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: isDesktop ? 11 : 8.5, color: const Color(0xFFF2CA50)),
                  const SizedBox(width: 2),
                  Text(
                    'LOCKED',
                    style: TextStyle(
                      fontSize: isDesktop ? 9.5 : 7.5,
                      color: const Color(0xFFF2CA50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 6 : 4,
                vertical: isDesktop ? 2 : 1,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 2),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rankStr,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 12 : 10,
                      fontWeight: FontWeight.w900,
                      color: isRed ? const Color(0xFFB91C1C) : const Color(0xFF141D24),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Text(
                    suitStr,
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 9,
                      color: isRed ? const Color(0xFFB91C1C) : const Color(0xFF141D24),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(width: isDesktop ? 6 : 4),
          Icon(
            Icons.workspace_premium_rounded,
            size: isDesktop ? 16 : 13,
            color: const Color(0xFFF2CA50),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExitGame(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141E18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Leave Table?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to leave this multiplayer table? If the match is in progress, you will receive a drop penalty.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, left: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay & Play', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      context.go('/multiplayer');
    }
  }


  void _showKickPlayerFromGameDialog(BuildContext context, TablePlayer targetPlayer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Remove from Game?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${targetPlayer.displayName}" from the game?\n\nThey will be eliminated with an 80-point penalty and the turn will advance to the next player.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(multiplayerGameProvider.notifier).removePlayerByHost(targetPlayer.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed ${targetPlayer.displayName} from the game.'), backgroundColor: Colors.orangeAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove player: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('REMOVE PLAYER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showManagePlayersModal(BuildContext context, MultiplayerGameState game, String myUid) {
    final isHost = game.players.any((p) => p.uid == myUid && p.isHost);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1E36),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.manage_accounts_rounded, color: AppColors.accent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Table Players',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            ...game.players.map((p) {
              final isCurrent = p.uid == myUid;
              final isTurn = p.uid == game.currentTurnPlayerId;
              final canKick = isHost && !p.isHost && p.status == 'ACTIVE' && game.status == 'IN_PROGRESS';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isTurn ? AppColors.accent : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: p.isHost ? Colors.amber.withValues(alpha: 0.2) : AppColors.accent.withValues(alpha: 0.2),
                      child: Icon(
                        p.isHost ? Icons.workspace_premium : Icons.person,
                        color: p.isHost ? Colors.amber : AppColors.accent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                p.displayName + (isCurrent ? ' (You)' : ''),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (p.isHost) ...[
                                const SizedBox(width: 6),
                                const Text('HOST', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                              if (isTurn) ...[
                                const SizedBox(width: 6),
                                const Text('• TURN', style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          Text(
                            'Status: ${p.status} | Score: ${p.score} pts',
                            style: TextStyle(color: p.status == 'ACTIVE' ? Colors.white54 : Colors.redAccent, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (canKick)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.person_remove_rounded, size: 14),
                        label: const Text('REMOVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showKickPlayerFromGameDialog(context, p);
                        },
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
