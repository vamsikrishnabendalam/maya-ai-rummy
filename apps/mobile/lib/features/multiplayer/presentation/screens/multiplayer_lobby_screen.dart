import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/table_models.dart';
import '../../providers/multiplayer_providers.dart';

class MultiplayerLobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const MultiplayerLobbyScreen({Key? key, required this.roomCode}) : super(key: key);

  @override
  ConsumerState<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends ConsumerState<MultiplayerLobbyScreen> {
  bool _isStarting = false;
  String? _statusNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureJoined();
    });
  }

  Future<void> _ensureJoined() async {
    final currentLobby = ref.read(multiplayerLobbyProvider).valueOrNull;
    if (currentLobby == null || currentLobby.roomCode != widget.roomCode) {
      // If not authenticated or anonymous without custom name, redirect to join screen
      final user = ref.read(authProvider);
      if (user == null || (user.isGuest && (user.displayName.isEmpty || user.displayName == 'Guest Player'))) {
        if (mounted) {
          context.go('/join/${widget.roomCode}');
        }
        return;
      }
      try {
        await ref.read(multiplayerLobbyProvider.notifier).joinTable(roomCode: widget.roomCode);
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusNotice = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobbyAsync = ref.watch(multiplayerLobbyProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF081220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () async {
            await ref.read(multiplayerLobbyProvider.notifier).leaveTable();
            if (context.mounted) context.go('/multiplayer');
          },
        ),
        title: const Text(
          'TABLE LOBBY',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ),
      body: lobbyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text('Error: $err', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                  onPressed: () => context.go('/multiplayer'),
                  child: const Text('Return to Multiplayer Hub'),
                ),
              ],
            ),
          ),
        ),
        data: (lobby) {
          if (lobby == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_statusNotice != null) ...[
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _statusNotice!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                      onPressed: () => context.go('/multiplayer'),
                      child: const Text('Back to Tables'),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      'Entering Room ${widget.roomCode}...',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ],
              ),
            );
          }

          // If game has started, navigate to game table screen!
          if (lobby.isPlaying && lobby.activeGameId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/table/${lobby.activeGameId}');
            });
          }

          // If non-host player is not in table players list, they were removed by host
          if (user != null && lobby.players.isNotEmpty && !lobby.players.any((p) => p.uid == user.uid)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You were removed from the table by the host.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                context.go('/multiplayer');
              }
            });
          }

          final isHost = user != null && lobby.hostUid == user.uid;
          final canStart = isHost && lobby.players.length >= 2;
          final origin = kIsWeb ? Uri.base.origin : 'https://mayarummy.cwards.com';
          final inviteLink = '$origin/join/${lobby.roomCode}';

          // Sort players: Table Host ALWAYS first, followed by others in seat order
          final sortedPlayers = [...lobby.players];
          sortedPlayers.sort((a, b) {
            if (a.isHost) return -1;
            if (b.isHost) return 1;
            return a.seatIndex.compareTo(b.seatIndex);
          });

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Room Code & Invite Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF142E54), Color(0xFF0F1E36)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            lobby.tableName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${lobby.gameMode} • ${lobby.turnTimerSeconds}s Turn • ${lobby.firstDropPenalty}/${lobby.middleDropPenalty}/${lobby.maxPenalty} Drop',
                              style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('ROOM CODE: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF081220),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.accent),
                                ),
                                child: Text(
                                  lobby.roomCode,
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Copy Room Code',
                                icon: const Icon(Icons.copy_rounded, color: AppColors.accent, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: lobby.roomCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room code copied to clipboard!'), duration: Duration(seconds: 2)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Copy Invite Link Button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.glassBorder),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 16, color: AppColors.accent),
                            label: const Text('COPY INVITE LINK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: inviteLink));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invite link copied: $inviteLink'), duration: const Duration(seconds: 3)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Player Slots Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SEATED PLAYERS',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        ),
                        Text(
                          '${lobby.players.length} / ${lobby.maxPlayers}',
                          style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // List of slots (up to maxPlayers)
                    ...List.generate(lobby.maxPlayers, (index) {
                      final player = index < sortedPlayers.length ? sortedPlayers[index] : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: player != null ? const Color(0xFF0F1E36) : const Color(0xFF0B1422),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: player != null ? AppColors.glassBorder : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: player != null ? AppColors.accent.withValues(alpha: 0.2) : Colors.white10,
                              child: player != null
                                  ? const Icon(Icons.person, color: AppColors.accent, size: 18)
                                  : Text('${index + 1}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player != null ? player.displayName : 'Empty Slot',
                                    style: TextStyle(
                                      color: player != null ? Colors.white : Colors.white30,
                                      fontWeight: player != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (player != null && player.isHost)
                                    const Row(
                                      children: [
                                        Icon(Icons.workspace_premium, color: Colors.amber, size: 13),
                                        SizedBox(width: 4),
                                        Text('TABLE HOST', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (player != null) ...[
                              if (isHost && !player.isHost)
                                IconButton(
                                  tooltip: 'Remove ${player.displayName}',
                                  icon: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showKickConfirmationDialog(context, player),
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ] else
                              const Text('Waiting...', style: TextStyle(color: Colors.white24, fontSize: 11)),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    if (_statusNotice != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Text(_statusNotice!, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                      ),

                    // Host Action: Start Game
                    if (isHost)
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canStart ? AppColors.accent : Colors.white12,
                            foregroundColor: canStart ? Colors.black : Colors.white38,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: canStart ? 4 : 0,
                          ),
                          icon: _isStarting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.play_arrow_rounded, size: 22),
                          label: Text(
                            canStart ? 'START GAME (13-CARD RUMMY)' : 'WAITING FOR PLAYERS (MIN 2)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                          ),
                          onPressed: (canStart && !_isStarting)
                              ? () async {
                                  setState(() => _isStarting = true);
                                  try {
                                    final gameId = await ref.read(multiplayerLobbyProvider.notifier).startGame();
                                    if (context.mounted) {
                                      context.go('/table/$gameId');
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isStarting = false;
                                      _statusNotice = e.toString().replaceAll('Exception: ', '');
                                    });
                                  }
                                }
                              : null,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                            SizedBox(width: 10),
                            Text('Waiting for Host to start the game...', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    // Leave Table Button
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () async {
                        await ref.read(multiplayerLobbyProvider.notifier).leaveTable();
                        if (context.mounted) context.go('/multiplayer');
                      },
                      child: const Text('LEAVE TABLE'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showKickConfirmationDialog(BuildContext context, TablePlayer player) {
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
            Text('Remove Player?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${player.displayName}" from this table?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                await ref.read(multiplayerLobbyProvider.notifier).kickPlayer(player.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed ${player.displayName} from table'), backgroundColor: Colors.orangeAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('REMOVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
