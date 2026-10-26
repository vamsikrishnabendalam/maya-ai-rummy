import 'dart:async';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/table_models.dart';
import '../../providers/multiplayer_providers.dart';
import '../../../game/presentation/widgets/player_hand.dart';
import '../../../game/presentation/widgets/card_animation_layer.dart';
import '../../../game/presentation/widgets/royal_rummy_oval_table.dart';
import '../../../game/presentation/widgets/royal_life_checklist_bar.dart';
import '../../../game/presentation/widgets/center_table.dart';
import '../../../../core/utils/responsive.dart';
import '../../utils/game_log_exporter.dart';

class MultiplayerTableScreen extends ConsumerStatefulWidget {
  final String gameId;

  const MultiplayerTableScreen({Key? key, required this.gameId}) : super(key: key);

  @override
  ConsumerState<MultiplayerTableScreen> createState() => _MultiplayerTableScreenState();
}

class _MultiplayerTableScreenState extends ConsumerState<MultiplayerTableScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  bool _hasShownResultDialog = false;

  static String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

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
    final isMobileLandscape = isLandscape && !isDesktop;
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

    return Scaffold(
      backgroundColor: const Color(0xFF05080F),
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            // --- 1. Top Navigation Bar ---
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 18 : 12,
                vertical: isDesktop ? 8 : 6,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF070D17),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/multiplayer'),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : 8,
                        vertical: isDesktop ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new, color: Colors.white, size: isDesktop ? 14 : 12),
                          const SizedBox(width: 4),
                          Text('Lobby', style: TextStyle(color: Colors.white, fontSize: isDesktop ? 13 : 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),

                  // Brand Title
                  Text(
                    'MAYA AI RUMMY',
                    style: TextStyle(
                      fontSize: isDesktop ? 15 : 12,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFF2CA50),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 10 : 8),

                  // Room Code Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 11 : 8,
                      vertical: isDesktop ? 5 : 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: const Color(0xFFF59E0B), size: isDesktop ? 15 : 13),
                        const SizedBox(width: 4),
                        Text(
                          '#${game.roomCode}',
                          style: TextStyle(
                            color: const Color(0xFFFDE68A),
                            fontSize: isDesktop ? 12 : 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isDesktop ? 8 : 6),

                  // Drop Rules Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 10 : 7,
                      vertical: isDesktop ? 5 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'DROP: ${game.firstDropPenalty}/${game.middleDropPenalty}/${game.maxPenalty}',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: isDesktop ? 11 : 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // In Landscape: Live Toast Guidance Pill
                  if (isLandscape) ...[
                    const Spacer(),
                    _buildMultiplayerToastPill(toastMessage),
                  ],

                  const Spacer(),

                  // Host Management & End Game Buttons
                  if (game.players.any((p) => p.uid == myUid && p.isHost) && !game.isCompleted) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24, width: 1),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 12 : 8,
                          vertical: isDesktop ? 7 : 4,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(Icons.manage_accounts_rounded, color: AppColors.accent, size: isDesktop ? 16 : 14),
                      label: Text('PLAYERS', style: TextStyle(fontSize: isDesktop ? 11.5 : 10, fontWeight: FontWeight.bold)),
                      onPressed: () => _showManagePlayersModal(context, game, myUid),
                    ),
                    SizedBox(width: isDesktop ? 8 : 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E1414),
                        foregroundColor: const Color(0xFFFF8A80),
                        side: const BorderSide(color: Color(0xFFD32F2F), width: 1),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 12 : 8,
                          vertical: isDesktop ? 7 : 4,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(Icons.cancel_outlined, color: const Color(0xFFFF8A80), size: isDesktop ? 16 : 14),
                      label: Text('END', style: TextStyle(fontSize: isDesktop ? 11.5 : 10, fontWeight: FontWeight.bold)),
                      onPressed: () => _showEndGameConfirmationDialog(context),
                    ),
                    SizedBox(width: isDesktop ? 8 : 6),
                  ],

                  // Scoreboard Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF142E54),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : 8,
                        vertical: isDesktop ? 7 : 4,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(Icons.leaderboard_rounded, color: AppColors.accent, size: isDesktop ? 17 : 16),
                    label: Text('SCOREBOARD', style: TextStyle(fontSize: isDesktop ? 11.5 : 10, fontWeight: FontWeight.bold)),
                    onPressed: () => _showScoreboardModal(context, game),
                  ),
                  SizedBox(width: isDesktop ? 10 : 6),

                  // Available Coins Pill (User Virtual Coins)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 12 : 8,
                      vertical: isDesktop ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF182128),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF2CA50).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
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
                          '🪙',
                          style: TextStyle(fontSize: isDesktop ? 15 : 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCoins(user.coins),
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF2CA50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // In Portrait: Toast Guidance Banner & Opponents Bar
            if (!isLandscape) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _buildMultiplayerToastPill(toastMessage),
              ),
              _buildPortraitOpponentsBar(opponents, game),
            ],

            // Declaration Banner (when a player declares)
            if (game.isDeclaring) _buildDeclarationBanner(game, myUid),

            // --- 2. Main Arena (Royal 2.5D Oval Table, Opponents Orbit, Center Decks, Thumb-Zones) ---
            Expanded(
              child: Stack(
                children: [
                  // Royal Rummy 2.5D Oval Table
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 40.0 : 8.0,
                        vertical: 2.0,
                      ),
                      child: RoyalRummyOvalTable(
                        isPortrait: !isLandscape,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Center Table Elements: Closed Deck + perpendicular Wild Joker, Open Deck Pile + Discard History, Finish Slot
                            CenterTable(
                              closedDeckCount: game.closedDeckRemaining,
                              openPile: game.openPile,
                              wildJoker: game.openJoker,
                              isClosedJoker: game.isClosedJoker,
                              isJokerOpened: game.hasPlayerOpenedJoker(user.uid),
                              hasLife: notifier.hasFirstLife,
                              isCompact: isMobileLandscape || (!isLandscape && MediaQuery.of(context).size.height < 720),
                              potAmount: '🪙 ${(game.players.length * 100).clamp(100, 99900)}',
                              pointValue: '${game.firstDropPenalty} pts',
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
                              onDrawClosed: () => notifier.drawFromClosed(),
                              onDrawOpen: () => notifier.drawFromOpen(),
                              canDeclare: canDeclare,
                              onDeclare: canDeclare ? _showDeclarationDialog : null,
                            ),

                            // In Landscape: Opponents Seating Layout around table orbit
                            if (isLandscape)
                              _buildOpponentsOrbit(opponents, game, isHost: myPlayer.isHost),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Landscape Left Thumb-Zone: Drop, Auto Group
                  if (isMobileLandscape)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drop Button
                            InkWell(
                              onTap: canDrop
                                  ? () => _showDropConfirmationDialog(context, game, dropPenalty, isFirstDrop)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: canDrop
                                      ? const Color(0xFF3E0A16).withValues(alpha: 0.95)
                                      : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: canDrop ? const Color(0xFFF43F5E) : Colors.white12,
                                  ),
                                  boxShadow: canDrop
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                            blurRadius: 8,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 16,
                                      color: canDrop ? const Color(0xFFFDA4AF) : Colors.white24,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Drop',
                                      style: TextStyle(
                                        color: canDrop ? const Color(0xFFFDA4AF) : Colors.white30,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '$dropPenalty pt',
                                      style: TextStyle(
                                        color: canDrop
                                            ? const Color(0xFFFDA4AF).withValues(alpha: 0.7)
                                            : Colors.white24,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Auto Group Button
                            InkWell(
                              onTap: () => notifier.autoGroupHand(),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF042F2E).withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF00E5FF)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16, color: Color(0xFF00E5FF)),
                                    SizedBox(height: 2),
                                    Text(
                                      'Auto',
                                      style: TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      'Group',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Landscape Right Thumb-Zone: Group Multi-Select, Discard, Declare
                  if (isMobileLandscape)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Multi Group Button (if selected cards >= 2 or selected card != null)
                            if (tableState.selectedCards.length >= 2 || tableState.selectedCard != null) ...[
                              InkWell(
                                onTap: () {
                                  if (tableState.selectedCards.length >= 2) {
                                    notifier.groupSelectedCards(tableState.selectedCards.toList());
                                  } else if (tableState.selectedCard != null) {
                                    notifier.groupSelectedCards([tableState.selectedCard!]);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.accent),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.folder_shared_rounded, size: 15, color: AppColors.accent),
                                      const SizedBox(height: 2),
                                      Text(
                                        tableState.selectedCards.length >= 2
                                            ? 'Group (${tableState.selectedCards.length})'
                                            : 'New Grp',
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Discard Button
                            InkWell(
                              onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: canDiscard
                                      ? const LinearGradient(
                                          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                        )
                                      : null,
                                  color: canDiscard ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: canDiscard ? const Color(0xFFFDE68A) : Colors.white12,
                                  ),
                                  boxShadow: canDiscard
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                            blurRadius: 10,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      size: 16,
                                      color: canDiscard ? Colors.black : Colors.white24,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isSelectedCardFromOpen ? 'Open' : 'Discard',
                                      style: TextStyle(
                                        color: canDiscard ? Colors.black : Colors.white30,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (tableState.selectedCard != null && !isSelectedCardFromOpen)
                                      Text(
                                        tableState.selectedCard!.label,
                                        style: TextStyle(
                                          color: canDiscard ? Colors.black87 : Colors.white24,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Declare / Show Button
                            InkWell(
                              onTap: canDeclare ? _showDeclarationDialog : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: canDeclare
                                      ? const LinearGradient(
                                          colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                                        )
                                      : null,
                                  color: canDeclare ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: canDeclare ? const Color(0xFFA7F3D0) : Colors.white12,
                                  ),
                                  boxShadow: canDeclare
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                            blurRadius: 12,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      size: 16,
                                      color: canDeclare ? Colors.black : Colors.white24,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Declare',
                                      style: TextStyle(
                                        color: canDeclare ? Colors.black : Colors.white30,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),


                  // Round Over Standings Overlay (Pool Rummy multi-round auto-progression)
                  if (game.isRoundOver)
                    _buildRoundOverOverlay(game, myUid, notifier),
                ],
              ),
            ),

            // Status message notice (if any)
            if (tableState.statusMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(tableState.statusMessage!, style: const TextStyle(color: Colors.amber, fontSize: 11)),
              ),

            if (isDropped)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'You dropped from this round (${myPlayer.score} PTS penalty). Waiting for next deal...',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else if (myPlayer.status == 'ELIMINATED')
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'You were removed from this round by the table host (${myPlayer.score} PTS penalty).',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // --- 3. Action Grid on Top of Player Cards (Drop, Sort, Auto Group, Discard, Declare) ---
            if (!isLandscape || isDesktop)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 960 : double.infinity),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 16 : 10,
                      vertical: isDesktop ? 6 : 3,
                    ),
                    child: Row(
                      children: [
                        // Drop Button (or Sort during declaration)
                        Expanded(
                          child: InkWell(
                            onTap: game.isDeclaring
                                ? () => notifier.autoSortHand()
                                : (canDrop ? () => _showDropConfirmationDialog(context, game, dropPenalty, isFirstDrop) : null),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                              decoration: BoxDecoration(
                                color: game.isDeclaring
                                    ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                    : (canDrop ? const Color(0xFF3E0A16) : const Color(0xFF0F172A).withValues(alpha: 0.6)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: game.isDeclaring
                                      ? Colors.white24
                                      : (canDrop ? const Color(0xFFF43F5E) : Colors.white12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    game.isDeclaring ? Icons.sort_rounded : Icons.flag_rounded,
                                    size: isDesktop ? 17 : 13,
                                    color: game.isDeclaring
                                        ? Colors.white70
                                        : (canDrop ? const Color(0xFFFDA4AF) : Colors.white24),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    game.isDeclaring ? 'Sort' : 'Drop ($dropPenalty)',
                                    style: TextStyle(
                                      color: game.isDeclaring
                                          ? Colors.white70
                                          : (canDrop ? const Color(0xFFFDA4AF) : Colors.white30),
                                      fontSize: isDesktop ? 13 : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),

                        // Dedicated Sort Button on Desktop (when not declaring)
                        if (isDesktop && !game.isDeclaring) ...[
                          Expanded(
                            child: InkWell(
                              onTap: () => notifier.autoSortHand(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sort_rounded, size: 17, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sort',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],

                        // Auto Group Button
                        Expanded(
                          child: InkWell(
                            onTap: () => notifier.autoGroupHand(),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF042F2E),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF00E5FF)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, size: isDesktop ? 17 : 13, color: const Color(0xFF00E5FF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Auto Group',
                                    style: TextStyle(
                                      color: const Color(0xFF00E5FF),
                                      fontSize: isDesktop ? 13 : 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),

                        // Manual Group or Discard
                        if (tableState.selectedCards.length >= 2 || (tableState.selectedCard != null && !canDiscard))
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (tableState.selectedCards.length >= 2) {
                                  notifier.groupSelectedCards(tableState.selectedCards.toList());
                                } else if (tableState.selectedCard != null) {
                                  notifier.groupSelectedCards([tableState.selectedCard!]);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.accent),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_shared_rounded, size: isDesktop ? 17 : 13, color: AppColors.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      tableState.selectedCards.length >= 2
                                          ? 'Group (${tableState.selectedCards.length})'
                                          : 'Group',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: isDesktop ? 13 : 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: InkWell(
                              onTap: canDiscard ? () => notifier.discardSelectedCard() : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                                decoration: BoxDecoration(
                                  gradient: canDiscard
                                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)])
                                      : null,
                                  color: canDiscard ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: canDiscard ? const Color(0xFFFDE68A) : Colors.white12),
                                  boxShadow: canDiscard && isDesktop
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: isDesktop ? 17 : 13, color: canDiscard ? Colors.black : Colors.white24),
                                    const SizedBox(width: 4),
                                    Text(
                                      canDiscard && tableState.selectedCard != null
                                          ? 'Discard (${tableState.selectedCard!.label})'
                                          : 'Discard',
                                      style: TextStyle(
                                        color: canDiscard ? Colors.black : Colors.white30,
                                        fontSize: isDesktop ? 13 : 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 5),

                        // Declare / Submit Button
                        Expanded(
                          child: Builder(
                            builder: (_) {
                              if (game.isDeclaring) {
                                if (game.declaringPlayerId == user.uid) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.accent),
                                    ),
                                    child: const Center(
                                      child: Text('0 PTS', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                }
                                final isSubmitted = game.submittedPlayerUids.contains(user.uid);
                                return InkWell(
                                  onTap: isSubmitted ? null : () => notifier.submitFinalHand(),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                                    decoration: BoxDecoration(
                                      gradient: isSubmitted ? null : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF14B8A6)]),
                                      color: isSubmitted ? Colors.white12 : null,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSubmitted ? Colors.white24 : const Color(0xFFA7F3D0)),
                                      boxShadow: !isSubmitted && isDesktop
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                                blurRadius: 10,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        isSubmitted ? 'Submitted' : 'Submit Hand',
                                        style: TextStyle(
                                          color: isSubmitted ? Colors.white54 : Colors.black,
                                          fontSize: isDesktop ? 13 : 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return InkWell(
                                onTap: canDeclare ? _showDeclarationDialog : null,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 11 : 6),
                                  decoration: BoxDecoration(
                                    gradient: canDeclare
                                        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF14B8A6)])
                                        : null,
                                    color: canDeclare ? null : const Color(0xFF0F172A).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: canDeclare ? const Color(0xFFA7F3D0) : Colors.white12),
                                    boxShadow: canDeclare && isDesktop
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.emoji_events_rounded, size: isDesktop ? 18 : 13, color: canDeclare ? Colors.black : Colors.white24),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Declare',
                                        style: TextStyle(
                                          color: canDeclare ? Colors.black : Colors.white30,
                                          fontSize: isDesktop ? 13.5 : 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // --- 4. Royal Life Checklist & Deadwood Points Bar ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: RoyalLifeChecklistBar(
                hasFirstLife: notifier.hasFirstLife,
                hasSecondLife: notifier.hasSecondLife,
                points: tableState.currentScore,
                isMyTurn: isMyTurn,
                turnSeconds: remainingTurnSeconds,
              ),
            ),

            // --- 5. Touch-Friendly Player Hand with Royal Ribbons ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF04100B),
                border: Border(top: BorderSide(color: Color(0xFF143E2B))),
              ),
              child: PlayerHand(
                cardGroups: tableState.cardGroups,
                wildJokerCard: game.hasPlayerOpenedJoker(user.uid) ? game.openJoker : null,
                selectedCard: tableState.selectedCard,
                selectedCards: tableState.selectedCards,
                isDiscardPhase: !game.isDeclaring && isMyTurn && isDiscardPhase,
                onCardTap: (card) => notifier.selectCard(card),
                onCardMoved: (card, fromId, toId) => notifier.moveCardBetweenGroups(card, fromId, toId, 999),
                onCardMovedToIndex: (card, fromId, toId, targetIndex) => notifier.moveCardBetweenGroups(card, fromId, toId, targetIndex),
                onCardReordered: (groupId, oldIndex, newIndex) => notifier.moveCardWithinGroup(groupId, oldIndex, newIndex),
                onCardMovedToNewGroup: (card, fromId) => notifier.moveCardToNewGroup(card, fromId),
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
                  notifier.selectCard(card);
                  notifier.discardSelectedCard();
                },
              ),
            ),
          ],
        ),
      ),
      const Positioned.fill(
        child: CardAnimationLayer(),
      ),
    ],
  ),
);
  }

  /// Builds orbital positioning for 1 to 5 opponents around the table
  Widget _buildOpponentsOrbit(List<TablePlayer> opponents, MultiplayerGameState game, {bool isHost = false}) {
    if (opponents.isEmpty) return const SizedBox.shrink();

    final alignments = <Alignment>[];
    if (opponents.length == 1) {
      alignments.add(const Alignment(0.0, -0.75));
    } else if (opponents.length == 2) {
      alignments.add(const Alignment(-0.6, -0.65));
      alignments.add(const Alignment(0.6, -0.65));
    } else if (opponents.length == 3) {
      alignments.add(const Alignment(-0.8, -0.2));
      alignments.add(const Alignment(0.0, -0.75));
      alignments.add(const Alignment(0.8, -0.2));
    } else if (opponents.length == 4) {
      alignments.add(const Alignment(-0.85, 0.0));
      alignments.add(const Alignment(-0.45, -0.7));
      alignments.add(const Alignment(0.45, -0.7));
      alignments.add(const Alignment(0.85, 0.0));
    } else {
      alignments.add(const Alignment(-0.85, 0.15));
      alignments.add(const Alignment(-0.7, -0.55));
      alignments.add(const Alignment(0.0, -0.8));
      alignments.add(const Alignment(0.7, -0.55));
      alignments.add(const Alignment(0.85, 0.15));
    }

    final int remainingTurnSeconds = game.turnDeadline != null
        ? game.turnDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 99)
        : 30;

    return Stack(
      children: List.generate(opponents.length, (i) {
        final p = opponents[i];
        final isTheirTurn = p.uid == game.currentTurnPlayerId;
        final alignment = alignments[i % alignments.length];

        final isEliminated = p.status == 'ELIMINATED';
        final isDropped = p.status == 'DROPPED';
        final isDisconnected = !p.connected && !isEliminated && !isDropped;
        final elapsed = p.disconnectedAt != null ? DateTime.now().difference(p.disconnectedAt!).inSeconds : 0;
        final remainingReconnectSec = (180 - elapsed).clamp(0, 180);

        Color borderColor = isTheirTurn ? AppColors.accent : Colors.white24;
        Color bgColor = isTheirTurn ? const Color(0xFF1E3A2E) : Colors.black.withValues(alpha: 0.6);

        if (isEliminated) {
          borderColor = Colors.redAccent.withValues(alpha: 0.7);
          bgColor = Colors.red.withValues(alpha: 0.2);
        } else if (isDropped) {
          borderColor = Colors.orangeAccent.withValues(alpha: 0.7);
          bgColor = Colors.orange.withValues(alpha: 0.15);
        } else if (isDisconnected) {
          borderColor = Colors.amberAccent.withValues(alpha: 0.7);
          bgColor = Colors.amber.withValues(alpha: 0.15);
        }

        final screenH = MediaQuery.of(context).size.height;
        final isCompactH = screenH < 550;

        return Align(
          alignment: alignment,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompactH ? 7 : 10,
              vertical: isCompactH ? 3.5 : 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: isTheirTurn ? 2 : 1,
              ),
              boxShadow: isTheirTurn
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: isCompactH ? 11 : 14,
                  backgroundColor: isEliminated
                      ? Colors.redAccent
                      : (isDropped
                          ? Colors.orangeAccent
                          : (isDisconnected
                              ? Colors.amberAccent
                              : (isTheirTurn ? AppColors.accent : Colors.white12))),
                  child: Icon(
                    isEliminated
                        ? Icons.close
                        : (isDropped
                            ? Icons.exit_to_app
                            : (isDisconnected ? Icons.wifi_off : Icons.person)),
                    color: (isTheirTurn || isEliminated || isDropped || isDisconnected) ? Colors.black : Colors.white70,
                    size: isCompactH ? 13 : 16,
                  ),
                ),
                SizedBox(width: isCompactH ? 5 : 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.displayName,
                          style: TextStyle(
                            color: isEliminated
                                ? Colors.redAccent
                                : (isDropped
                                    ? Colors.orangeAccent
                                    : (isTheirTurn ? AppColors.accent : Colors.white)),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: (isEliminated || isDropped) ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isTheirTurn && !isEliminated && !isDropped && game.status == 'IN_PROGRESS') ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.accent, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 9, color: AppColors.accent),
                                const SizedBox(width: 2),
                                Text(
                                  '${remainingTurnSeconds}s',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isEliminated)
                      const Text(
                        'ELIMINATED (80 PTS)',
                        style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      )
                    else if (isDropped)
                      Text(
                        'DROPPED (${p.score} PTS)',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      )
                    else if (isDisconnected)
                      Text(
                        'DISCONNECTED (${remainingReconnectSec}s)',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.style_outlined, color: Colors.white54, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '${p.cardCount} cards',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          if (p.misses > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.redAccent, width: 0.7),
                              ),
                              child: Text(
                                '${p.misses}/3 miss',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
                if (isHost && game.status == 'IN_PROGRESS' && p.status == 'ACTIVE') ...[
                  const SizedBox(width: 6),
                  IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove ${p.displayName} from Game',
                    icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent),
                    onPressed: () => _showKickPlayerFromGameDialog(context, p),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
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
