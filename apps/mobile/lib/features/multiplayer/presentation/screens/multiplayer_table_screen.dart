import 'dart:async';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/table_models.dart';
import '../../providers/multiplayer_providers.dart';
import '../../../game/presentation/widgets/card_widget.dart';
import '../../../game/presentation/widgets/card_back_widget.dart';
import '../../../game/presentation/widgets/player_hand.dart';
import '../../../game/presentation/widgets/card_animation_layer.dart';
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
      } else if (game.status == 'IN_PROGRESS') {
        final currentUid = ref.read(authProvider)?.uid;
        final isSeated = currentUid != null && game.players.any((p) => p.uid == currentUid);
        if (!isSeated) return;
        final isMyTurn = currentUid != null && game.currentTurnPlayerId == currentUid;

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
                                    const Text('ðŸ‘‘ Host', style: TextStyle(color: Colors.amberAccent, fontSize: 9))
                                  else if (p.uid == game.dealerPlayerId)
                                    const Text('ðŸ…³ Dealer', style: TextStyle(color: Colors.cyanAccent, fontSize: 9)),
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
                              color: isCurrentTurn ? Colors.amber.withValues(alpha: 0.2) : Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isCurrentTurn ? Colors.amber : Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isCurrentTurn ? 'PLAYING' : p.status,
                              style: TextStyle(
                                color: isCurrentTurn ? Colors.amberAccent : Colors.white70,
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
    final bool isValid = result['isValid'] == true;
    final results = (result['finalResults'] as List<dynamic>?) ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isValid ? Colors.greenAccent : Colors.redAccent, width: 2),
        ),
        title: Row(
          children: [
            Icon(isValid ? Icons.emoji_events : Icons.warning_amber_rounded, color: isValid ? Colors.amber : Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              isValid ? 'GAME WON!' : 'WRONG SHOW',
              style: TextStyle(color: isValid ? Colors.amber : Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w900),
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
                      Text(
                        '$displayName ${isWinner ? "ðŸ‘‘ (WINNER)" : ""}',
                        style: TextStyle(
                          color: isWinner ? Colors.greenAccent : Colors.white70,
                          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                        ),
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
              : [const Color(0xFF5A2A00), const Color(0xFF2E1500)],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDeclarer ? AppColors.accent : Colors.amberAccent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDeclarer ? Icons.emoji_events_rounded : Icons.notification_important_rounded,
            color: isDeclarer ? AppColors.accent : Colors.amberAccent,
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
                      : 'ðŸ”” $declarerName HAS DECLARED!',
                  style: TextStyle(
                    color: isDeclarer ? AppColors.accent : Colors.amberAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDeclarer
                      ? 'Waiting for opponents to arrange and submit their hands...'
                      : (hasSubmitted
                          ? 'âœ… Your hand is submitted! Waiting for other players...'
                          : 'Arrange your cards to minimize penalty points, then tap "SUBMIT FINAL HAND".'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final tableState = ref.watch(multiplayerGameProvider);
    final game = tableState.gameState;
    final notifier = ref.read(multiplayerGameProvider.notifier);

    // Realtime game completion listener: triggers final scoreboard dialog for all connected players
    ref.listen<MultiplayerGameTableState>(multiplayerGameProvider, (prev, next) {
      final g = next.gameState;
      if (g != null && g.isGameOver && !_hasShownResultDialog) {
        _hasShownResultDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showResultDialog({
              'isValid': true,
              'message': '${g.declaringPlayerName ?? "Winner"} won the match with 0 points!',
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

    return Scaffold(
      backgroundColor: const Color(0xFF06140E),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Turn Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF04100B),
                border: Border(bottom: BorderSide(color: Color(0xFF143E2B))),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => context.go('/multiplayer'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Lobby', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Table Name & Room Code Number Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2B1F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F5C3E)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_restaurant_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            game.tableName.isNotEmpty ? game.tableName : 'Maya Table',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent, width: 0.5),
                          ),
                          child: Text(
                            '#${game.roomCode}',
                            style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Drop Scores Badge (Issue 4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'DROP: ${game.firstDropPenalty} / ${game.middleDropPenalty} / ${game.maxPenalty}',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Turn Indicator Banner
                  Builder(
                    builder: (context) {
                      final int remainingTurnSeconds = game.turnDeadline != null
                          ? game.turnDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 99)
                          : 30;
                      final timerColor = remainingTurnSeconds > 10
                          ? AppColors.accent
                          : (remainingTurnSeconds > 5 ? Colors.amberAccent : Colors.redAccent);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: game.isDeclaring
                              ? Colors.amber.withValues(alpha: 0.2)
                              : (isMyTurn ? AppColors.accent.withValues(alpha: 0.2) : Colors.black45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: game.isDeclaring
                                ? Colors.amberAccent
                                : (isMyTurn ? AppColors.accent : Colors.white24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              game.isDeclaring
                                  ? Icons.flag_rounded
                                  : (isMyTurn ? Icons.touch_app_rounded : Icons.hourglass_top_rounded),
                              color: game.isDeclaring
                                  ? Colors.amberAccent
                                  : (isMyTurn ? AppColors.accent : Colors.white70),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              game.isDeclaring
                                  ? 'DECLARING PHASE'
                                  : (isMyTurn
                                      ? (isDrawPhase ? 'YOUR TURN: Draw a Card' : 'YOUR TURN: Discard a Card')
                                      : "Opponent's Turn..."),
                              style: TextStyle(
                                color: game.isDeclaring
                                    ? Colors.amberAccent
                                    : (isMyTurn ? AppColors.accent : Colors.white70),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!game.isDeclaring && game.status == 'IN_PROGRESS') ...[
                              const SizedBox(width: 8),
                              if (game.turnDeadline != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: timerColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: timerColor, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined, color: timerColor, size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${remainingTurnSeconds}s',
                                        style: TextStyle(
                                          color: timerColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.accent, width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.all_inclusive_rounded, color: AppColors.accent, size: 12),
                                      SizedBox(width: 3),
                                      Text(
                                        'NO LIMIT',
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const Spacer(),

                  // Table Owner End Tournament / Close Game Button
                  if (game.players.any((p) => p.uid == myUid && p.isHost) && !game.isCompleted) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3E1414),
                        foregroundColor: const Color(0xFFFF8A80),
                        side: const BorderSide(color: Color(0xFFD32F2F), width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF8A80), size: 16),
                      label: const Text('END GAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _showEndGameConfirmationDialog(context),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Scoreboard Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF142E54),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.leaderboard_rounded, color: AppColors.accent, size: 16),
                    label: const Text('SCOREBOARD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showScoreboardModal(context, game),
                  ),
                  const SizedBox(width: 8),

                  // Room Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3223),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${game.playerCount}P TABLE',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Declaration Banner (when a player declares)
            if (game.isDeclaring) _buildDeclarationBanner(game, myUid),

            // Main Emerald Felt Table Area with Animation Layer & Score Badge
            Expanded(
              child: Stack(
                children: [
                  // Emerald Felt Background with Oval Border
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment.center,
                          radius: 0.85,
                          colors: [
                            Color(0xFF0F4E34), // Inner bright emerald
                            Color(0xFF082E1E), // Mid felt
                            Color(0xFF051D13), // Deep felt edge
                          ],
                        ),
                        borderRadius: BorderRadius.circular(220),
                        border: Border.all(color: const Color(0xFFC8A155), width: 3), // Gold trim
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(220),
                        child: Stack(
                          children: [
                            // Center Table Elements: Closed Deck, Open Joker, Open Pile
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Closed Deck (Tap to draw)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: (!game.isDeclaring && isMyTurn && isDrawPhase) ? () => notifier.drawFromClosed() : null,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 60,
                                                height: 84,
                                                child: CardBackWidget(),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.8),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${game.closedDeckRemaining}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'CLOSED',
                                          style: TextStyle(
                                            color: (!game.isDeclaring && isMyTurn && isDrawPhase) ? AppColors.accent : Colors.white54,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),

                                    // 2. Open Joker Card
                                    if (game.openJoker != null)
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Transform.rotate(
                                            angle: 0.08,
                                            child: SizedBox(
                                              width: 58,
                                              height: 82,
                                              child: CardWidget(card: game.openJoker!),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'WILD JOKER',
                                            style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(width: 14),

                                    // 3. Open Discard Pile (Shows previous 5 dropped cards in visible stack, top card tap to draw)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (game.openPile.isNotEmpty) ...[
                                          Builder(
                                            builder: (_) {
                                              final openCards = game.openPile;
                                              final count = openCards.length > 5 ? 5 : openCards.length;
                                              final startIndex = openCards.length - count;
                                              final visibleCards = openCards.sublist(startIndex);

                                              return SizedBox(
                                                width: 58.0 + (count - 1) * 22.0,
                                                height: 82.0 + (count - 1) * 1.5,
                                                child: Stack(
                                                  children: List.generate(count, (index) {
                                                    final isTop = index == count - 1;
                                                    final card = visibleCards[index];
                                                    final xOffset = index * 22.0;
                                                    final yOffset = index * 1.5;

                                                    final cardWidget = Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(8),
                                                        boxShadow: const [
                                                          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1)),
                                                        ],
                                                        border: Border.all(
                                                          color: (isTop && !game.isDeclaring && isMyTurn && isDrawPhase)
                                                              ? AppColors.accent
                                                              : Colors.black26,
                                                          width: (isTop && !game.isDeclaring && isMyTurn && isDrawPhase) ? 2 : 1,
                                                        ),
                                                      ),
                                                      child: SizedBox(
                                                        width: 58,
                                                        height: 82,
                                                        child: CardWidget(card: card),
                                                      ),
                                                    );

                                                    return Positioned(
                                                      left: xOffset,
                                                      top: yOffset,
                                                      child: isTop
                                                          ? InkWell(
                                                              onTap: (!game.isDeclaring && isMyTurn && isDrawPhase)
                                                                  ? () => notifier.drawFromOpen()
                                                                  : null,
                                                              borderRadius: BorderRadius.circular(8),
                                                              child: cardWidget,
                                                            )
                                                          : cardWidget,
                                                    );
                                                  }),
                                                ),
                                              );
                                            },
                                          ),
                                        ] else
                                          Container(
                                            width: 60,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.white24, strokeAlign: BorderSide.strokeAlignInside),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Center(child: Text('EMPTY', style: TextStyle(color: Colors.white24, fontSize: 9))),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          game.openPile.isNotEmpty ? 'OPEN PILE (${game.openPile.length})' : 'OPEN PILE',
                                          style: TextStyle(
                                            color: (!game.isDeclaring && isMyTurn && isDrawPhase) ? AppColors.accent : Colors.white54,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Opponents Seating Layout (Dynamic 1 to 5 seats around the top orbit)
                            _buildOpponentsOrbit(opponents, game),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Card Animation Layer (Cascade 13-card deal distribution & card flight animations)
                  const Positioned.fill(
                    child: CardAnimationLayer(),
                  ),
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
              ),

            // Current Player Hand Area (Bottom) with Full Drag-and-Drop PlayerHand
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF04100B),
                border: Border(top: BorderSide(color: Color(0xFF143E2B))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action Buttons Bar: Player Info & Score | Sort | Auto Group | Group | Discard | Declare
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // User Identity & Live Hand Score Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, color: AppColors.accent, size: 15),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              user.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showScoreboardModal(context, game),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0A2218),
                                  border: Border.all(
                                    color: tableState.currentScore == 0 ? AppColors.success : const Color(0xFFC8A155),
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'HAND SCORE: ',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${tableState.currentScore} PTS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: tableState.currentScore == 0 ? AppColors.success : AppColors.accent,
                                      ),
                                    ),
                                    if (game.dealerPlayerId == user.uid) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: Colors.amber, width: 0.8),
                                        ),
                                        child: const Text(
                                          'ðŸ…³ DEALER',
                                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // In-game Action Buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // SORT BUTTON
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                side: const BorderSide(color: AppColors.glassBorder),
                                foregroundColor: Colors.white70,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => notifier.autoSortHand(),
                              child: const Text('SORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),

                            // AUTO GROUP BUTTON
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                side: const BorderSide(color: AppColors.accent),
                                foregroundColor: AppColors.accent,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => notifier.autoGroupHand(),
                              child: const Text('AUTO GROUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),

                            // GROUP BUTTON
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                side: BorderSide(
                                  color: (tableState.selectedCards.length >= 2 || tableState.selectedCard != null)
                                      ? AppColors.accent
                                      : AppColors.glassBorder,
                                ),
                                foregroundColor: (tableState.selectedCards.length >= 2 || tableState.selectedCard != null)
                                    ? AppColors.accent
                                    : Colors.white54,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: (tableState.selectedCards.length >= 2 || tableState.selectedCard != null)
                                  ? () {
                                      if (tableState.selectedCards.length >= 2) {
                                        notifier.groupSelectedCards(tableState.selectedCards.toList());
                                      } else if (tableState.selectedCard != null) {
                                        notifier.groupSelectedCards([tableState.selectedCard!]);
                                      }
                                    }
                                  : null,
                              child: Text(
                                tableState.selectedCards.length >= 2
                                    ? 'GROUP (${tableState.selectedCards.length})'
                                    : (tableState.selectedCard != null ? 'NEW GROUP' : 'GROUP'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),

                            if (game.isDeclaring) ...[
                              if (game.declaringPlayerId == user.uid)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.accent),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.emoji_events, color: AppColors.accent, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'DECLARATION SUBMITTED (0 PTS)',
                                        style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else if (game.submittedPlayerUids.contains(user.uid))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'HAND SUBMITTED',
                                        style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 14),
                                  label: Text(
                                    'SUBMIT FINAL HAND (${tableState.currentScore} PTS)',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
                                  ),
                                  onPressed: tableState.isSubmitting ? null : () => notifier.submitFinalHand(),
                                ),
                            ] else ...[
                              // DROP BUTTON (Issue 1)
                              Builder(
                                builder: (_) {
                                  final hasDrawnOrDiscarded = game.actionLog.any((a) =>
                                      a['playerId'] == user.uid &&
                                      (a['type'] == 'DRAW_CLOSED' || a['type'] == 'DRAW_OPEN' || a['type'] == 'DISCARD'));
                                  final isFirstDrop = game.turnNumber == 0 || !hasDrawnOrDiscarded;
                                  final dropPenalty = isFirstDrop ? game.firstDropPenalty : game.middleDropPenalty;
                                  final canDrop = isMyTurn && isDrawPhase && !game.isDeclaring && game.status == 'IN_PROGRESS' && !isDropped;

                                  return OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      side: BorderSide(
                                        color: canDrop ? Colors.orangeAccent : Colors.white24,
                                        width: canDrop ? 1.2 : 1.0,
                                      ),
                                      foregroundColor: canDrop ? Colors.orangeAccent : Colors.white38,
                                      backgroundColor: canDrop ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: canDrop
                                        ? () => _showDropConfirmationDialog(context, game, dropPenalty, isFirstDrop)
                                        : null,
                                    child: Text(
                                      'DROP ($dropPenalty)',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              // DISCARD BUTTON
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canDiscard ? Colors.redAccent : Colors.white12,
                                  foregroundColor: canDiscard ? Colors.white : Colors.white38,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: canDiscard ? () => notifier.discardSelectedCard() : null,
                                child: Text(
                                  isSelectedCardFromOpen
                                      ? 'OPEN PICK'
                                      : (tableState.selectedCard != null
                                          ? 'DISCARD (${tableState.selectedCard!.label})'
                                          : 'DISCARD'),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // DECLARE BUTTON
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canDeclare ? AppColors.accent : Colors.white12,
                                  foregroundColor: canDeclare ? Colors.black : Colors.white38,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: canDeclare ? _showDeclarationDialog : null,
                                child: Text(
                                  tableState.selectedCard != null
                                      ? 'DECLARE (${tableState.selectedCard!.label})'
                                      : 'DECLARE',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Interactive PlayerHand with Drag-and-Drop & Reordering
                  PlayerHand(
                    cardGroups: tableState.cardGroups,
                    wildJokerCard: game.openJoker,
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
                      notifier.selectCard(card);
                      notifier.discardSelectedCard();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds orbital positioning for 1 to 5 opponents around the table
  Widget _buildOpponentsOrbit(List<TablePlayer> opponents, MultiplayerGameState game) {
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
        final isDisconnected = !p.connected && !isEliminated;
        final elapsed = p.disconnectedAt != null ? DateTime.now().difference(p.disconnectedAt!).inSeconds : 0;
        final remainingReconnectSec = (180 - elapsed).clamp(0, 180);

        Color borderColor = isTheirTurn ? AppColors.accent : Colors.white24;
        Color bgColor = isTheirTurn ? const Color(0xFF1E3A2E) : Colors.black.withValues(alpha: 0.6);

        if (isEliminated) {
          borderColor = Colors.redAccent.withValues(alpha: 0.7);
          bgColor = Colors.red.withValues(alpha: 0.2);
        } else if (isDisconnected) {
          borderColor = Colors.amberAccent.withValues(alpha: 0.7);
          bgColor = Colors.amber.withValues(alpha: 0.15);
        }

        return Align(
          alignment: alignment,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  radius: 14,
                  backgroundColor: isEliminated
                      ? Colors.redAccent
                      : (isDisconnected
                          ? Colors.amberAccent
                          : (isTheirTurn ? AppColors.accent : Colors.white12)),
                  child: Icon(
                    isEliminated
                        ? Icons.close
                        : (isDisconnected ? Icons.wifi_off : Icons.person),
                    color: (isTheirTurn || isEliminated || isDisconnected) ? Colors.black : Colors.white70,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
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
                                : (isTheirTurn ? AppColors.accent : Colors.white),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: isEliminated ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isTheirTurn && !isEliminated && game.status == 'IN_PROGRESS') ...[
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
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
