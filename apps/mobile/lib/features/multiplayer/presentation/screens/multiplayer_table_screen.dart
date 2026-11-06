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
import '../../../game/presentation/widgets/secret_joker_reveal_overlay.dart';
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

      final syncedNow = ref.read(multiplayerServiceProvider).syncedServerNow;

      if (game.isDeclaring) {
        if (game.declarationDeadline != null && syncedNow.isAfter(game.declarationDeadline!)) {
          ref.read(multiplayerGameProvider.notifier).checkDeclarationTimeout();
        }
      } else if (game.status == 'ROUND_OVER') {
        if (game.nextRoundStartTime != null && syncedNow.isAfter(game.nextRoundStartTime!)) {
          ref.read(multiplayerGameProvider.notifier).startNextRound();
        }
      } else if (game.status == 'IN_PROGRESS') {
        final currentUid = ref.read(authProvider)?.uid;
        final isSeated = currentUid != null && game.players.any((p) => p.uid == currentUid);
        if (!isSeated) return;
        final isMyTurn = game.currentTurnPlayerId == currentUid;

        // Turn timeout handling with universal synced clock & 4s grace window
        if (game.turnDeadline != null) {
          if (isMyTurn && syncedNow.isAfter(game.turnDeadline!)) {
            ref.read(multiplayerGameProvider.notifier).handleTurnTimeout();
          } else if (!isMyTurn && syncedNow.isAfter(game.turnDeadline!.add(const Duration(seconds: 4)))) {
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
          width: 520,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 290),
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
                const SizedBox(height: 6),

                // Player Rows (Scrollable for up to 6 players)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                ),
                const SizedBox(height: 6),
              ],
            ),
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

  Future<void> _handleMultiplayerDeclare({Card? finishCard}) async {
    final gameNotifier = ref.read(multiplayerGameProvider.notifier);
    final tableState = ref.read(multiplayerGameProvider);
    final cardToDeclare = finishCard ?? tableState.selectedCard;

    if (cardToDeclare == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select 1 card or drag it into the Finish slot to declare!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final res = await gameNotifier.declareWithCard(cardToDeclare);
    if (res != null && mounted) {
      if (res['isValid'] == false && !_hasShownResultDialog) {
        _hasShownResultDialog = true;
        _showResultDialog(res);
      }
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final bool isAborted = result['isAborted'] == true;
    final bool isValid = result['isValid'] == true;
    final results = (result['finalResults'] as List<dynamic>?) ?? [];

    final user = ref.read(authProvider);
    final myUid = user?.uid ?? '';
    final winnerResult = results.firstWhere(
      (r) => (r is Map ? r['isWinner'] == true : r.isWinner == true),
      orElse: () => null,
    );
    final bool isMeWinner = winnerResult != null &&
        (winnerResult is Map ? winnerResult['uid'] == myUid : winnerResult.uid == myUid);

    IconData titleIcon = isMeWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied_rounded;
    Color titleColor = isMeWinner ? Colors.amber : (isValid ? const Color(0xFFF59E0B) : Colors.redAccent);
    String titleText = isMeWinner ? 'VICTORY!' : (isValid ? 'MATCH OVER' : 'WRONG SHOW');

    if (isAborted) {
      titleIcon = Icons.stop_circle_outlined;
      titleColor = Colors.orangeAccent;
      titleText = 'GAME ENDED BY HOST';
    }

    final currentG = ref.read(multiplayerGameProvider).gameState;
    final isMatchOver = isAborted || (currentG != null && (currentG.isGameOver || currentG.isCompleted));

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
          if (!isValid && !isMatchOver)
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
                        remainingSecs = game.nextRoundStartTime!.difference(ref.read(multiplayerServiceProvider).syncedServerNow).inSeconds.clamp(0, 10);
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
      remainingSeconds = game.declarationDeadline!.difference(ref.read(multiplayerServiceProvider).syncedServerNow).inSeconds.clamp(0, 30);
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
          if (!isDeclarer && !isDroppedOrElim) ...[
            const SizedBox(width: 10),
            InkWell(
              onTap: hasSubmitted ? null : () => ref.read(multiplayerGameProvider.notifier).submitFinalHand(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: hasSubmitted
                      ? null
                      : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  color: hasSubmitted ? const Color(0xFF1E293B) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasSubmitted ? Colors.white24 : const Color(0xFFA7F3D0),
                    width: 1.5,
                  ),
                  boxShadow: hasSubmitted
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSubmitted ? Icons.check_circle_rounded : Icons.send_rounded,
                      size: 14,
                      color: hasSubmitted ? Colors.white54 : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasSubmitted ? 'HAND SUBMITTED' : 'SUBMIT FINAL HAND',
                      style: GoogleFonts.outfit(
                        color: hasSubmitted ? Colors.white54 : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    if (game.isGameOver || game.isCompleted) {
      return 'Match completed! Check the final scorecard.';
    }
    if (game.isRoundOver) {
      return 'Deal completed! Waiting for next deal...';
    }
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
      if (g != null && (prevG == null || g.currentRound > prevG.currentRound)) {
        if (!g.isGameOver) {
          _hasShownResultDialog = false;
        }
      }
      if (g != null && g.isGameOver && !_hasShownResultDialog) {
        _hasShownResultDialog = true;
        final wasAbortedByHost = g.actionLog.any((a) => a['type'] == 'HOST_ENDED_GAME');
        final wrongShowLog = g.actionLog.lastWhere(
          (a) => a['type'] == 'DECLARE_INVALID',
          orElse: () => <String, dynamic>{},
        );
        final hasWrongShow = wrongShowLog.isNotEmpty;
        final wrongShowPlayerId = wrongShowLog['playerId'];
        final myUid = user?.uid ?? '';
        final isMeWrongShow = myUid.isNotEmpty && wrongShowPlayerId == myUid;
        final winnerPlayer = g.players.firstWhere(
          (p) => p.uid == g.winnerPlayerId,
          orElse: () => TablePlayer(uid: '', displayName: 'Winner', photoURL: '', seatIndex: 0),
        );

        String message;
        if (wasAbortedByHost) {
          message = 'The table host ended the match before completion. Match cancelled with 0 points for all players.';
        } else if (hasWrongShow) {
          if (isMeWrongShow) {
            message = 'Wrong Show! Your declaration was invalid and you were penalized 80 points. ${winnerPlayer.displayName} wins the match!';
          } else {
            message = 'Opponent Wrong Show! An invalid declaration occurred (80 pts penalty). You win the match with 0 points!';
          }
        } else {
          message = '${g.declaringPlayerName ?? winnerPlayer.displayName} won the match with 0 points!';
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showResultDialog({
              'isValid': !isMeWrongShow && !wasAbortedByHost,
              'isAborted': wasAbortedByHost,
              'hasWrongShow': hasWrongShow,
              'message': message,
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

    final totalCardsInHand = tableState.cardGroups.fold<int>(0, (sum, g) => sum + g.cards.length);
    final has14Cards = totalCardsInHand >= 14 || game.myHand.length >= 14 || tableState.hasDrawnThisTurn;

    // A player holding 14 cards MUST be in discard phase, never draw phase
    final isDrawPhase = game.isDrawPhase && !has14Cards;
    final isDiscardPhase = game.isDiscardPhase || has14Cards;
    final myUid = user.uid;

    final opponents = game.players.where((p) => p.uid != myUid).toList();

    final isSelectedCardFromOpen = tableState.selectedCard != null &&
        game.cardDrawnFromOpenThisTurn != null &&
        tableState.selectedCard == game.cardDrawnFromOpenThisTurn;

    final canDiscardAction = isMyTurn && isDiscardPhase && !game.isDeclaring && !game.isGameOver && !game.isCompleted && !game.isRoundOver && !tableState.isHandLocked;
    final canDiscard = canDiscardAction && tableState.selectedCard != null && !isSelectedCardFromOpen;
    final canDeclare = canDiscardAction && tableState.selectedCard != null;

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final isDesktop = Responsive.isDesktop(context) || size.width >= 1024;
    final isFirstDrop = game.isPlayerFirstDrop(myUid, hasDrawnThisTurn: tableState.hasDrawnThisTurn);
    final dropPenalty = isFirstDrop ? game.firstDropPenalty : game.middleDropPenalty;
    final canDrop = !game.isDeclaring && !game.isGameOver && !game.isCompleted && !game.isRoundOver && !tableState.isHandLocked && isMyTurn && isDrawPhase && !isDropped;

    final toastMessage = _computeMultiplayerToast(
      game: game,
      isMyTurn: isMyTurn,
      isDrawPhase: isDrawPhase,
      isDiscardPhase: isDiscardPhase,
      isSelectedCard: tableState.selectedCard != null,
      isSelectedCardFromOpen: isSelectedCardFromOpen,
      isDropped: isDropped,
    );

    final int remainingTurnSeconds = game.turnTimerSeconds == 0
        ? 0
        : (game.turnDeadline != null
            ? game.turnDeadline!.difference(ref.read(multiplayerServiceProvider).syncedServerNow).inSeconds.clamp(0, 99)
            : game.turnTimerSeconds);

    final Card? wildJoker = (game.hasPlayerOpenedJoker(user.uid) || !game.isClosedJoker) ? game.openJoker : null;
    final int activeCapacity = (game.status == 'IN_PROGRESS' || game.status == 'DECLARING' || game.status == 'COMPLETED')
        ? game.players.length.clamp(2, 6)
        : game.playerCount.clamp(2, 6);

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
                                    hasLife: notifier.hasFirstLife && !has14Cards && !tableState.hasDrawnThisTurn,
                                    onOpenClosedJoker: () {
                                      if (has14Cards || tableState.hasDrawnThisTurn) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please discard a card to complete your turn before viewing the Closed Joker.'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
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
                                      if (game.isDeclaring || game.isGameOver || game.isCompleted || game.isRoundOver || tableState.isHandLocked) return;
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
                                    finishCard: (game.isDeclaring || game.isRoundOver || game.isCompleted) ? (game.finishCard ?? tableState.finishCard) : null,
                                    wildJoker: wildJoker,
                                    isActivated: (isMyTurn && isDiscardPhase && ref.watch(gameUIProvider).isDragging) ||
                                        (isMyTurn && isDiscardPhase && tableState.selectedCard != null),
                                    canAcceptDrop: isMyTurn && isDiscardPhase && !game.isDeclaring,
                                    canDeclare: isMyTurn && isDiscardPhase && !game.isDeclaring && tableState.selectedCard != null,
                                    onDeclare: (isMyTurn && isDiscardPhase && !game.isDeclaring)
                                        ? () => _handleMultiplayerDeclare()
                                        : null,
                                    onCardDeclared: (isMyTurn && isDiscardPhase && !game.isDeclaring)
                                        ? (card) => _handleMultiplayerDeclare(finishCard: card)
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
                    maxPlayers: activeCapacity,
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

    final isMobileLandscape = Responsive.isMobileLandscape(context);
    if (isMobileLandscape) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: MultiplayerTableBackground(
          maxPlayers: activeCapacity,
          child: _buildMobileLandscapeLayout(
            context,
            ref,
            game: game,
            tableState: tableState,
            notifier: notifier,
            user: user,
            toastMessage: toastMessage,
            isMyTurn: isMyTurn,
            isDrawPhase: isDrawPhase,
            isDiscardPhase: isDiscardPhase,
            remainingTurnSeconds: remainingTurnSeconds,
            wildJoker: wildJoker,
            canDrop: canDrop,
            dropPenalty: dropPenalty,
            isFirstDrop: isFirstDrop,
            canDiscard: canDiscardAction,
            canDeclare: canDeclare,
            myUid: myUid,
            activeCapacity: activeCapacity,
            opponents: opponents,
            myPlayer: myPlayer,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09141A),
      body: MultiplayerTableBackground(
        maxPlayers: activeCapacity,
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

            // 9. Secret Joker Reveal Animation Layer (Gold Particles & Card Flip)
            if (ref.watch(gameUIProvider).showSecretJokerReveal && ref.watch(gameUIProvider).secretJokerCard != null)
              Positioned.fill(
                child: SecretJokerRevealOverlay(
                  wildJoker: ref.watch(gameUIProvider).secretJokerCard!,
                  onDismiss: () => ref.read(gameUIProvider.notifier).dismissSecretJokerReveal(),
                ),
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
    Card? finishCard,
    Card? wildJoker,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    if (finishCard != null) {
      return Container(
        width: _tableCardW,
        height: _tableCardH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.75),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              CardWidget(
                card: finishCard,
                isWildJoker: wildJoker != null && JokerUtils.isWildJoker(finishCard, wildJoker),
                width: _tableCardW,
                height: _tableCardH,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'FINISH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                    _buildNetworkIndicator(isDesktop: true),
                    SizedBox(width: isDesktop ? 8 : 5),
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

          // Declare Hand (Mobile: with Network Indicator on the left)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                _buildNetworkIndicator(isDesktop: false),
                SizedBox(width: gap),
              ],
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
                    _handleMultiplayerDeclare(finishCard: droppedCard);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  final active = (isMyTurn && isDiscardPhase && !game.isDeclaring && tableState.selectedCard != null) || isHovering;
                  return InkWell(
                    onTap: (isMyTurn && isDiscardPhase && !game.isDeclaring)
                        ? () => _handleMultiplayerDeclare()
                        : null,
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
        ],
      ),
    );
  }

  Widget _buildNetworkIndicator({required bool isDesktop}) {
    final netStatus = ref.watch(networkStatusProvider).value ?? const NetworkStatus();
    final isDisconnected = netStatus.isDisconnected;
    final isDegraded = netStatus.isDegraded;

    final Color dotColor;
    final Color textColor;
    final Color bgColor;
    final Color borderColor;
    final String label;

    if (isDisconnected) {
      dotColor = const Color(0xFFEF4444);
      textColor = const Color(0xFFFECACA);
      bgColor = const Color(0xFF261010);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.6);
      if (isDesktop) {
        label = netStatus.pendingActions > 0
            ? 'Reconnecting... | Queue: ${netStatus.pendingActions}'
            : 'Reconnecting...';
      } else {
        label = netStatus.pendingActions > 0
            ? 'Reconnecting (${netStatus.pendingActions})'
            : 'Reconnecting...';
      }
    } else if (isDegraded) {
      dotColor = const Color(0xFFF59E0B);
      textColor = const Color(0xFFFDE68A);
      bgColor = const Color(0xFF241C0A);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.5);
      label = isDesktop
          ? '${netStatus.pingMs}ms • Weak'
          : '${netStatus.pingMs}ms';
    } else {
      dotColor = const Color(0xFF10B981);
      textColor = const Color(0xFFA7F3D0);
      bgColor = const Color(0xFF0F231B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      label = isDesktop
          ? '${netStatus.pingMs}ms • Stable'
          : '${netStatus.pingMs}ms';
    }

    return Tooltip(
      message: isDisconnected
          ? 'Network disconnected. Reconnecting & synchronizing with server...'
          : (isDegraded ? 'High latency: ${netStatus.pingMs}ms' : 'Connection stable: ${netStatus.pingMs}ms'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 9 : 7,
          vertical: isDesktop ? 5 : 4,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: isDisconnected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isDesktop ? 7.0 : 6.0,
              height: isDesktop ? 7.0 : 6.0,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.8),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            SizedBox(width: isDesktop ? 6 : 4),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: isDesktop ? 10.5 : 9.5,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
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

  // ===========================================================================
  // MOBILE LANDSCAPE RESPONSIVE LAYOUT (Calibrated from Maya AI Studio Layout)
  // Canonical Reference Canvas: 1024 x 491 with Proportional FittedBox Scaling
  // ===========================================================================

  Widget _buildMobileLandscapeLayout(
    BuildContext context,
    WidgetRef ref, {
    required MultiplayerGameState game,
    required MultiplayerGameTableState tableState,
    required MultiplayerGameNotifier notifier,
    required dynamic user,
    required String toastMessage,
    required bool isMyTurn,
    required bool isDrawPhase,
    required bool isDiscardPhase,
    required int remainingTurnSeconds,
    required Card? wildJoker,
    required bool canDrop,
    required int dropPenalty,
    required bool isFirstDrop,
    required bool canDiscard,
    required bool canDeclare,
    required String myUid,
    required int activeCapacity,
    required List<TablePlayer> opponents,
    required TablePlayer myPlayer,
  }) {
    final uiState = ref.watch(gameUIProvider);
    final String modeLabel;
    if (game.gameMode.toUpperCase().contains('POINT')) {
      modeLabel = 'POINTS';
    } else if (game.gameMode.toUpperCase().contains('DEAL')) {
      modeLabel = 'DEALS (${game.currentRound}/2)';
    } else {
      modeLabel = game.gameMode.toUpperCase();
    }

    final turnPlayer = game.players.firstWhere(
      (p) => p.uid == game.currentTurnPlayerId,
      orElse: () => myPlayer,
    );

    final totalCardsInHand = tableState.cardGroups.fold<int>(0, (sum, g) => sum + g.cards.length);
    final has14Cards = totalCardsInHand >= 14 || game.myHand.length >= 14 || tableState.hasDrawnThisTurn;

    return Center(
      child: AspectRatio(
        aspectRatio: 1024.0 / 491.0,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: 1024.0,
            height: 491.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. LAYER 1: MULTIPLAYER OPPONENTS LAYER (Armchair seated opponents 2P to 6P)
                Positioned.fill(
                  child: MultiplayerOpponentsLayer(
                    maxPlayers: activeCapacity,
                    opponents: opponents,
                    currentTurnPlayerId: game.currentTurnPlayerId,
                    dealerPlayerId: game.dealerPlayerId,
                    remainingTurnSeconds: remainingTurnSeconds,
                    isMobile: true,
                    onOpponentTap: myPlayer.isHost && game.status == 'IN_PROGRESS'
                        ? (p) => _showKickPlayerFromGameDialog(context, p)
                        : null,
                  ),
                ),

                // 2. Center Table Cards (Inside Table Circle Felt - Tilted 46 deg perspective)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 243,
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0016)
                        ..rotateX(-0.8028),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Closed Deck Stack with Perpendicular Tucked Wild Joker
                          _buildMobilePerspectiveClosedDeck(
                            context: context,
                            count: game.closedDeckRemaining,
                            wildJoker: game.openJoker,
                            isClosedJoker: game.isClosedJoker,
                            isJokerOpened: game.hasPlayerOpenedJoker(user.uid),
                            hasLife: notifier.hasFirstLife && !has14Cards && !tableState.hasDrawnThisTurn,
                            onOpenClosedJoker: () {
                              if (has14Cards || tableState.hasDrawnThisTurn) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please discard a card to complete your turn before viewing the Closed Joker.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
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
                          const SizedBox(width: 22),
                          // Open Discard Pile
                          _buildMobilePerspectiveOpenPile(
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
                          const SizedBox(width: 22),
                          // Finish / Declare Slot
                          _buildMobilePerspectiveFinishSlot(
                            context: context,
                            finishCard: (game.isDeclaring || game.isRoundOver || game.isCompleted) ? (game.finishCard ?? tableState.finishCard) : null,
                            wildJoker: wildJoker,
                            isActivated: canDeclare || (!game.isDeclaring && isMyTurn && isDiscardPhase && uiState.isDragging),
                            canAcceptDrop: isMyTurn && isDiscardPhase && !game.isDeclaring,
                            canDeclare: canDeclare,
                            onDeclare: (isMyTurn && isDiscardPhase && !game.isDeclaring)
                                ? () => _handleMultiplayerDeclare()
                                : null,
                            onCardDeclared: (isMyTurn && isDiscardPhase && !game.isDeclaring)
                                ? (card) => _handleMultiplayerDeclare(finishCard: card)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Top-Left Brand Pod
                Positioned(
                  left: 7,
                  top: 9,
                  width: 156,
                  height: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF210192A), Color(0xF7090F1A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x99D4AF37), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MULTIPLAYER RUMMY',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFF2CA50),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0x33F2CA50),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x88F2CA50), width: 1),
                            ),
                            child: Text(
                              modeLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFF2CA50),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0x22FFFFFF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${activeCapacity}P',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Left Status Pod (Turn countdown timer, 1st Life, 2nd Life, Deadwood)
                Positioned(
                  left: 6,
                  top: 56,
                  width: 142,
                  height: 58,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF20E1624), Color(0xF7080E18)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x66D4AF37), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isMyTurn ? 'YOUR TURN' : '${turnPlayer.displayName.toUpperCase()}\'S TURN',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isMyTurn ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x26F59E0B),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  (game.turnTimerSeconds == 0 ? '⏱️ ∞' : '⏱️ ${remainingTurnSeconds}s'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    notifier.hasFirstLife ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 11,
                                    color: notifier.hasFirstLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '1st Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: notifier.hasFirstLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Icon(
                                    notifier.hasSecondLife ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 11,
                                    color: notifier.hasSecondLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '2nd Life',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: notifier.hasSecondLife ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'DEADWOOD: ${tableState.currentScore} PTS',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: tableState.currentScore == 0 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Center Toast Banner
                Positioned(
                  left: 334,
                  top: 12,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xF00E1828), Color(0xF016263E)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x99F2CA50), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFFF2CA50), size: 13),
                        const SizedBox(width: 6),
                        Text(
                          toastMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFFBEB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Declaration Banner (when active)
                if (game.isDeclaring)
                  Positioned(
                    top: 48,
                    left: 200,
                    right: 200,
                    child: _buildDeclarationBanner(game, myUid),
                  ),

                // 7. Top Right: Declare Hand / Submit Final Hand Button
                Positioned(
                  left: 792,
                  top: 10,
                  width: 138,
                  height: 34,
                  child: Builder(
                    builder: (ctx) {
                      if (game.isDeclaring) {
                        if (game.declaringPlayerId == myUid) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accent, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                '0 PTS (Declared)',
                                style: GoogleFonts.outfit(
                                  color: AppColors.accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                        final hasSubmitted = game.submittedPlayerUids.contains(myUid);
                        return InkWell(
                          onTap: hasSubmitted ? null : () => notifier.submitFinalHand(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: hasSubmitted
                                  ? null
                                  : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                              color: hasSubmitted ? const Color(0xFF1E293B) : null,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: hasSubmitted ? Colors.white24 : const Color(0xFFA7F3D0),
                                width: 1.5,
                              ),
                              boxShadow: hasSubmitted
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  hasSubmitted ? Icons.check_circle_rounded : Icons.send_rounded,
                                  size: 13,
                                  color: hasSubmitted ? Colors.white54 : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasSubmitted ? 'Submitted' : 'SUBMIT HAND',
                                  style: GoogleFonts.outfit(
                                    color: hasSubmitted ? Colors.white54 : Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return DragTarget<Object>(
                        onWillAcceptWithDetails: (details) =>
                            (!game.isDeclaring && isMyTurn && isDiscardPhase) &&
                            (details.data is CardDragData || details.data is Card),
                        onAcceptWithDetails: (details) {
                          Card? card;
                          if (details.data is CardDragData) {
                            card = (details.data as CardDragData).card;
                          } else if (details.data is Card) {
                            card = details.data as Card;
                          }
                          _handleMultiplayerDeclare(finishCard: card);
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;
                          final active = canDeclare || isHovering;

                          return InkWell(
                            onTap: (canDeclare && !game.isDeclaring)
                                ? () => _handleMultiplayerDeclare()
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: active ? 1.0 : 0.45,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF141B26), Color(0xFF0B1018)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isHovering ? const Color(0xFF34D399) : const Color(0xFFF2CA50),
                                    width: isHovering ? 2.2 : 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isHovering
                                          ? const Color(0xFF34D399).withValues(alpha: 0.6)
                                          : const Color(0xFFF2CA50).withValues(alpha: canDeclare ? 0.35 : 0.0),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2CA50), size: 14),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Declare Hand',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFF2CA50),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // 8. Top Right: 3-Dash MENU Button
                Positioned(
                  left: 939,
                  top: 10,
                  width: 78,
                  height: 34,
                  child: InkWell(
                    onTap: () => _showMobileMultiplayerMenu(context, ref, game, myPlayer),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1E0D), Color(0xFF151A22)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF2CA50), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF2CA50).withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                              const SizedBox(height: 2.5),
                              Container(width: 14, height: 1.8, color: const Color(0xFFF2CA50)),
                            ],
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'MENU',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFF2CA50),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 9. Top-Right Discard Button (Directly below Declare & Menu with DragTarget support)
                Positioned(
                  left: 905,
                  top: 52,
                  width: 106,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Discard',
                    icon: Icons.arrow_upward_rounded,
                    gradientColors: [const Color(0xFF1B2230), const Color(0xFF111722)],
                    borderColor: canDiscard ? const Color(0xFF60A5FA) : const Color(0xFF475569),
                    textColor: canDiscard ? Colors.white : const Color(0xFF94A3B8),
                    canAcceptDrop: canDiscard,
                    onCardDropped: (card) {
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
                    onTap: canDiscard
                        ? () {
                            if (tableState.selectedCard != null) {
                              final card = tableState.selectedCard!;
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
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Select 1 card from your hand to discard, or drag it here.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                ),

                // 10. Left Action Buttons Stack (All 112px x 38px)
                // Group Button
                Positioned(
                  left: 6,
                  top: 124,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Group',
                    icon: Icons.folder_rounded,
                    gradientColors: [const Color(0xFF2F62C9), const Color(0xFF1E4498)],
                    borderColor: const Color(0xFF60A5FA),
                    textColor: Colors.white,
                    onTap: () => notifier.groupSelectedCards(),
                  ),
                ),
                // Drop
                Positioned(
                  left: 7,
                  top: 171,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Drop ($dropPenalty)',
                    icon: Icons.flag_rounded,
                    gradientColors: canDrop
                        ? [const Color(0xFFA82020), const Color(0xFF7E1515)]
                        : [const Color(0xFF221616), const Color(0xFF181010)],
                    borderColor: canDrop ? const Color(0xFFFCA5A5) : const Color(0xFF452222),
                    textColor: canDrop ? Colors.white : const Color(0xFF7A4A4A),
                    onTap: canDrop
                        ? () => _showDropConfirmationDialog(context, game, dropPenalty, isFirstDrop)
                        : null,
                  ),
                ),
                // Sort Hand
                Positioned(
                  left: 6,
                  top: 218,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'Sort Hand',
                    icon: Icons.swap_vert_rounded,
                    gradientColors: [const Color(0xFF2D7D46), const Color(0xFF1E5C32)],
                    borderColor: const Color(0xFF10B981),
                    textColor: Colors.white,
                    onTap: () => notifier.sortHandAscending(),
                  ),
                ),
                // AI Group
                Positioned(
                  left: 6,
                  top: 267,
                  width: 112,
                  height: 38,
                  child: _buildMobilePillButton(
                    label: 'AI Group',
                    icon: Icons.auto_awesome_rounded,
                    gradientColors: [const Color(0xFF6A3EA1), const Color(0xFF502A82)],
                    borderColor: const Color(0xFFA855F7),
                    textColor: Colors.white,
                    onTap: () => notifier.autoGroupHand(),
                  ),
                ),

                // 11. Grouped Player Hand (Full 938px width rack, 14 cards fit without scrolling)
                Positioned(
                  left: 44,
                  top: 335,
                  width: 938,
                  child: PlayerHand(
                    cardGroups: tableState.cardGroups,
                    wildJokerCard: wildJoker,
                    selectedCard: tableState.selectedCard,
                    selectedCards: tableState.selectedCards,
                    isDiscardPhase: !game.isDeclaring && isMyTurn && isDiscardPhase,
                    customCardWidth: 90.0,
                    customCardHeight: 130.0,
                    customCardOverlap: 44.0,
                    customGroupSpacing: 16.0,
                    onCardTap: (card) => notifier.selectCard(card),
                    onCardMoved: (card, fromGroupId, toGroupId) {
                      notifier.moveCardBetweenGroups(
                        card,
                        fromGroupId,
                        toGroupId,
                        tableState.cardGroups
                            .firstWhere((g) => g.id == toGroupId, orElse: () => tableState.cardGroups.first)
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
                      if (game.isDeclaring || game.isGameOver || game.isCompleted || game.isRoundOver || tableState.isHandLocked) return;
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

                // 12. Round Over Overlay (if round completed)
                if (game.isRoundOver)
                  Positioned.fill(
                    child: _buildRoundOverOverlay(game, myUid, notifier),
                  ),

                // 13. Card Animation Layer (Deal & Discard flights)
                const Positioned.fill(
                  child: CardAnimationLayer(),
                ),

                // 14. Secret Joker Reveal Animation Layer (Gold Particles & Card Flip)
                if (uiState.showSecretJokerReveal && uiState.secretJokerCard != null)
                  Positioned.fill(
                    child: SecretJokerRevealOverlay(
                      wildJoker: uiState.secretJokerCard!,
                      onDismiss: () => ref.read(gameUIProvider.notifier).dismissSecretJokerReveal(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePerspectiveClosedDeck({
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
    const double cardW = 58.0;
    const double cardH = 82.0;
    final bool showJokerFace = !isClosedJoker || isJokerOpened;

    return SizedBox(
      width: cardW + 36.0,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          // Perpendicular Wild Joker tucked horizontally underneath peeking to the left
          Positioned(
            left: 2,
            top: (cardH - cardW) / 2,
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: (showJokerFace && wildJoker != null)
                    ? CardWidget(
                        card: wildJoker,
                        isWildJoker: true,
                        width: cardW,
                        height: cardH,
                      )
                    : GestureDetector(
                        onTap: () {
                          if (!showJokerFace) {
                            if (hasLife) {
                              onOpenClosedJoker();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Form a Pure Sequence (Life) of 3+ cards to view the Joker.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CardBackWidget(
                              width: cardW,
                              height: cardH,
                              showPulse: hasLife,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4.5),
                              decoration: BoxDecoration(
                                color: hasLife ? const Color(0xFFF59E0B) : Colors.black87,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasLife ? Colors.white : Colors.amber.shade700,
                                  width: 1.0,
                                ),
                              ),
                              child: Icon(
                                hasLife ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                size: 14,
                                color: hasLife ? Colors.black : Colors.amber.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          // Face-down closed deck stack on top
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: canDraw ? onDraw : null,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: canDraw
                          ? const Color(0xFFF2CA50).withValues(alpha: 0.6)
                          : Colors.black.withValues(alpha: 0.7),
                      blurRadius: canDraw ? 10 : 6,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CardBackWidget(
                      width: cardW,
                      height: cardH,
                      onTap: canDraw ? onDraw : null,
                    ),
                    Positioned(
                      bottom: -4,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xF20E141E),
                          border: Border.all(color: const Color(0xFFF2CA50), width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CLOSED ($count)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF2CA50),
                          ),
                        ),
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

  Widget _buildMobilePerspectiveOpenPile({
    required BuildContext context,
    required List<Card> discardPile,
    required Card? wildJoker,
    required bool canDraw,
    required VoidCallback onDraw,
    required bool canDiscard,
    required void Function(Card)? onDiscardCard,
    required VoidCallback onShowHistory,
  }) {
    const double cardW = 58.0;
    const double cardH = 82.0;
    final visibleDiscards = discardPile.length <= 5
        ? discardPile
        : discardPile.sublist(discardPile.length - 5);
    final count = visibleDiscards.length;
    final double stepX = 18.0;
    final double totalWidth = count <= 1 ? cardW : (cardW + (count - 1) * stepX);

    final pileWidget = SizedBox(
      width: totalWidth,
      height: cardH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count == 0)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: cardW,
                height: cardH,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Center(
                  child: Text(
                    'EMPTY',
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          for (int i = 0; i < count; i++) ...[
            Positioned(
              left: i * stepX,
              top: 0,
              child: GestureDetector(
                onTap: (i == count - 1 && canDraw) ? onDraw : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: (i == count - 1 && canDraw)
                            ? const Color(0xFF10B981).withValues(alpha: 0.7)
                            : Colors.black.withValues(alpha: 0.55),
                        blurRadius: (i == count - 1 && canDraw) ? 10 : 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  child: CardWidget(
                    card: visibleDiscards[i],
                    width: cardW,
                    height: cardH,
                    isWildJoker: wildJoker != null && visibleDiscards[i].rank == wildJoker.rank,
                  ),
                ),
              ),
            ),
          ],

          if (count > 0)
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onShowHistory,
                child: Container(
                  padding: const EdgeInsets.all(4),
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
                    size: 11,
                    color: Color(0xFFFBBF24),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: -15,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                count > 1 ? 'OPEN PILE ($count)' : 'OPEN PILE',
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) =>
          canDiscard && (details.data is CardDragData || details.data is Card),
      onAcceptWithDetails: (details) {
        Card? card;
        if (details.data is CardDragData) {
          card = (details.data as CardDragData).card;
        } else if (details.data is Card) {
          card = details.data as Card;
        }
        if (card != null && onDiscardCard != null) {
          onDiscardCard(card);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final bool isTargetHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: isTargetHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: pileWidget,
        );
      },
    );
  }

  Widget _buildMobilePerspectiveFinishSlot({
    required BuildContext context,
    required bool isActivated,
    required bool canAcceptDrop,
    required bool canDeclare,
    Card? finishCard,
    Card? wildJoker,
    VoidCallback? onDeclare,
    void Function(Card)? onCardDeclared,
  }) {
    const double cardW = 58.0;
    const double cardH = 82.0;

    if (finishCard != null) {
      return Container(
        width: cardW,
        height: cardH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.7),
              blurRadius: 12,
              spreadRadius: 1.5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              CardWidget(
                card: finishCard,
                isWildJoker: wildJoker != null && JokerUtils.isWildJoker(finishCard, wildJoker),
                width: cardW,
                height: cardH,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Text(
                    'FINISH',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) =>
          canAcceptDrop && (details.data is CardDragData || details.data is Card),
      onAcceptWithDetails: (details) {
        Card? card;
        if (details.data is CardDragData) {
          card = (details.data as CardDragData).card;
        } else if (details.data is Card) {
          card = details.data as Card;
        }
        if (card != null && onCardDeclared != null) {
          onCardDeclared(card);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        final active = isActivated || isHovering || canDeclare;

        return GestureDetector(
          onTap: canDeclare ? onDeclare : null,
          child: Container(
            width: cardW,
            height: cardH,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: active
                    ? [const Color(0x33F59E0B), const Color(0x22FBBF24)]
                    : [const Color(0x33120424), const Color(0x220A0214)],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? const Color(0xFFFBBF24) : const Color(0x55F59E0B),
                width: active ? 2.0 : 1.2,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: active ? const Color(0xFFFBBF24) : const Color(0x88F59E0B),
                        size: 16,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FINISH',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: active ? const Color(0xFFFBBF24) : const Color(0x88F59E0B),
                        ),
                      ),
                      Text(
                        '14th Card',
                        style: GoogleFonts.outfit(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white70 : Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'DECLARE',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: active ? const Color(0xFFFDE68A) : Colors.white54,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobilePillButton({
    required String label,
    required IconData icon,
    required List<Color> gradientColors,
    required Color borderColor,
    required Color textColor,
    required VoidCallback? onTap,
    void Function(Card)? onCardDropped,
    bool canAcceptDrop = false,
  }) {
    final enabled = onTap != null || canAcceptDrop;

    Widget buttonBody(bool isHovering) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHovering ? const Color(0xFFF2CA50) : borderColor,
            width: isHovering ? 2.0 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: isHovering
                  ? const Color(0xFFF2CA50).withValues(alpha: 0.6)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: isHovering ? 10 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isHovering ? const Color(0xFFF2CA50) : textColor, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: isHovering ? const Color(0xFFF2CA50) : textColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (canAcceptDrop && onCardDropped != null) {
      return DragTarget<Object>(
        onWillAcceptWithDetails: (details) =>
            canAcceptDrop && (details.data is CardDragData || details.data is Card),
        onAcceptWithDetails: (details) {
          Card? card;
          if (details.data is CardDragData) {
            card = (details.data as CardDragData).card;
          } else if (details.data is Card) {
            card = details.data as Card;
          }
          if (card != null) {
            onCardDropped(card);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: (enabled || isHovering) ? 1.0 : 0.45,
              child: buttonBody(isHovering),
            ),
          );
        },
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.45,
        child: buttonBody(false),
      ),
    );
  }

  void _showMobileMultiplayerMenu(
    BuildContext context,
    WidgetRef ref,
    MultiplayerGameState game,
    TablePlayer myPlayer,
  ) {
    final myUid = myPlayer.uid;
    final isHost = myPlayer.isHost;

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      barrierDismissible: true,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              top: 48,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 215,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xF510192A), Color(0xF9090F1A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF2CA50), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFFF2CA50).withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_rounded, color: Color(0xFFF2CA50), size: 15),
                              const SizedBox(width: 6),
                              Text(
                                'ROYAL GAME MENU',
                                style: GoogleFonts.cinzel(
                                  color: const Color(0xFFF2CA50),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(color: Color(0x33D4AF37), height: 1),
                      const SizedBox(height: 6),
                      _buildMobileMenuButton(
                        icon: Icons.leaderboard_rounded,
                        iconColor: const Color(0xFF60A5FA),
                        title: 'Live Scoreboard',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showScoreboardModal(context, game);
                        },
                      ),
                      _buildMobileMenuButton(
                        icon: Icons.settings_rounded,
                        iconColor: const Color(0xFFFBBF24),
                        title: 'Table Rules',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showTableSettings(context, game);
                        },
                      ),
                      _buildMobileMenuButton(
                        icon: Icons.history_edu_rounded,
                        iconColor: const Color(0xFFA78BFA),
                        title: 'Action Logs',
                        onTap: () async {
                          Navigator.of(ctx).pop();
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
                      ),
                      if (isHost && !game.isCompleted) ...[
                        _buildMobileMenuButton(
                          icon: Icons.manage_accounts_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Manage Players',
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showManagePlayersModal(context, game, myUid);
                          },
                        ),
                        _buildMobileMenuButton(
                          icon: Icons.cancel_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'End Table Session',
                          isDestructive: true,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showEndGameConfirmationDialog(context);
                          },
                        ),
                      ],
                      _buildMobileMenuButton(
                        icon: Icons.exit_to_app_rounded,
                        iconColor: const Color(0xFFF87171),
                        title: 'Leave Table',
                        isDestructive: true,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _handleExitGame(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileMenuButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0x22EF4444) : const Color(0x18FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDestructive ? const Color(0x55EF4444) : const Color(0x28D4AF37),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: isDestructive ? const Color(0xFFFCA5A5) : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableSettings(BuildContext context, MultiplayerGameState game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.settings_rounded, color: Color(0xFFF2CA50), size: 22),
            const SizedBox(width: 8),
            Text(
              'TABLE RULES (LOCKED)',
              style: GoogleFonts.cinzel(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x33F59E0B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x88F59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Multiplayer match in progress. Settings are locked to table host defaults.',
                        style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildRuleRow('Game Mode', game.gameMode),
              _buildRuleRow('First Drop Penalty', '${game.firstDropPenalty} pts'),
              _buildRuleRow('Middle Drop Penalty', '${game.middleDropPenalty} pts'),
              _buildRuleRow('Full Count Cap', '80 pts'),
              _buildRuleRow('Joker Mode', game.isClosedJoker ? 'Closed Joker (Life Required)' : 'Open Joker'),
              _buildRuleRow('Turn Timer', '${game.turnTimerSeconds} seconds'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Color(0xFFF2CA50), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
