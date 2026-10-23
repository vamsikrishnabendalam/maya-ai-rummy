import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/multiplayer_providers.dart';

class JoinRedirectScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const JoinRedirectScreen({Key? key, required this.roomCode}) : super(key: key);

  @override
  ConsumerState<JoinRedirectScreen> createState() => _JoinRedirectScreenState();
}

class _JoinRedirectScreenState extends ConsumerState<JoinRedirectScreen> {
  bool _isLoading = true;
  bool _needsLogin = false;
  String? _errorMessage;
  final TextEditingController _guestNameController = TextEditingController();

  @override
  void dispose() {
    _guestNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndJoin();
    });
  }

  Future<void> _checkAuthAndJoin() async {
    final user = ref.read(authProvider);
    if (user != null) {
      if (user.isGuest && (user.displayName.isEmpty || user.displayName == 'Guest Player')) {
        // If guest has no custom nickname yet, prompt for nickname
        if (mounted) {
          setState(() {
            _isLoading = false;
            _needsLogin = true;
          });
        }
        return;
      }
      _executeJoin(user.uid);
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _needsLogin = true;
        });
      }
    }
  }

  Future<void> _loginAndJoin(bool isGuest, {String? guestName}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = isGuest
          ? await ref.read(authProvider.notifier).signInAsGuest(name: guestName, forceNewSession: false)
          : await ref.read(authProvider.notifier).signInWithGoogle();

      if (user != null) {
        _executeJoin(user.uid);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _needsLogin = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _executeJoin(String uid) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _needsLogin = false;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(multiplayerLobbyProvider.notifier).joinTable(
        roomCode: widget.roomCode,
      );
      if (mounted) {
        if (res['activeGameId'] != null && (res['status'] == 'PLAYING' || res['status'] == 'IN_PROGRESS')) {
          context.go('/table/${res['activeGameId']}');
        } else {
          context.go('/lobby/${res['roomCode']}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081220),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF101F36),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 20),
                    Text(
                      'Joining Table ${widget.roomCode}...',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connecting to Maya Rummy table...',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ] else if (_needsLogin) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.table_restaurant_rounded, color: AppColors.accent, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Join Table ${widget.roomCode}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You have been invited to play 13-Card Indian Rummy. Sign in to join the game directly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Sign in with Google
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                        label: const Text('SIGN IN WITH GOOGLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _loginAndJoin(false),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: const [
                        Expanded(child: Divider(color: Colors.white24)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR PLAY AS GUEST', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Colors.white24)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Guest Name Input Field
                    TextField(
                      controller: _guestNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0A1628),
                        hintText: 'Enter your name (e.g. Alex)',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                      ),
                      onSubmitted: (val) {
                        final name = val.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter your name to play as guest'),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        _loginAndJoin(true, guestName: name);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Play as Guest Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          foregroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('PLAY AS GUEST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          final name = _guestNameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your name to play as guest'),
                                backgroundColor: Colors.redAccent,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _loginAndJoin(true, guestName: name);
                        },
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 14),
                    Text(
                      'Unable to Join Table ${widget.roomCode}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                          onPressed: () => context.go('/multiplayer'),
                          child: const Text('Multiplayer Hub'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                          onPressed: () => _checkAuthAndJoin(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
