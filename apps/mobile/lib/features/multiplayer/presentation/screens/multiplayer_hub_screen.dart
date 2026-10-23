import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/multiplayer_providers.dart';

class MultiplayerHubScreen extends ConsumerStatefulWidget {
  const MultiplayerHubScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MultiplayerHubScreen> createState() => _MultiplayerHubScreenState();
}

class _MultiplayerHubScreenState extends ConsumerState<MultiplayerHubScreen> {
  final _roomCodeController = TextEditingController();
  final _tableNameController = TextEditingController();
  final _firstDropController = TextEditingController(text: '20');
  final _middleDropController = TextEditingController(text: '40');
  final _maxPenaltyController = TextEditingController(text: '80');
  int _selectedPlayerCount = 2;
  String _selectedGameMode = 'Points Rummy';
  int _selectedTurnTimer = 30; // 30, 45, 60, or 0 (No Limit)
  String _selectedDropPenalty = '20 / 40 / 80';
  bool _isCustomDrop = false;
  String _selectedEntryType = 'FREE'; // 'FREE' or 'COIN'
  int _selectedEntryCoins = 100; // 100, 250, 500, 1000, 2500, 5000
  static const int _creationFee = 50;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _tableNameController.dispose();
    _firstDropController.dispose();
    _middleDropController.dispose();
    _maxPenaltyController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTable() async {
    final user = ref.read(authProvider);
    if (user == null || (user.isGuest && (user.displayName.isEmpty || user.displayName == 'Guest Player'))) {
      _showSignInModal(onSignedIn: () => _handleCreateTable());
      return;
    }

    if (_selectedEntryType == 'COIN') {
      if (user.isGuest) {
        setState(() => _errorMessage = 'Guest accounts cannot create or join Coin Tables. Please sign in with Google to get 5,000 free coins!');
        return;
      }
      final requiredCoins = _selectedEntryCoins + _creationFee;
      if (user.coins < requiredCoins) {
        setState(() => _errorMessage = 'Insufficient virtual coins. You need $requiredCoins coins ($_selectedEntryCoins entry + $_creationFee creation fee), but only have ${user.coins}.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      int firstDrop = 20;
      int middleDrop = 40;
      int maxPenalty = 80;

      if (_isCustomDrop) {
        firstDrop = int.tryParse(_firstDropController.text.trim()) ?? 20;
        middleDrop = int.tryParse(_middleDropController.text.trim()) ?? 40;
        maxPenalty = int.tryParse(_maxPenaltyController.text.trim()) ?? 80;
      } else if (_selectedDropPenalty.startsWith('25')) {
        firstDrop = 25;
        middleDrop = 50;
        maxPenalty = 80;
      }

      final res = await ref.read(multiplayerLobbyProvider.notifier).createTable(
        tableName: _tableNameController.text.trim().isEmpty
            ? "${user.displayName}'s Table"
            : _tableNameController.text.trim(),
        maxPlayers: _selectedPlayerCount,
        gameMode: _selectedGameMode,
        turnTimerSeconds: _selectedTurnTimer,
        firstDropPenalty: firstDrop,
        middleDropPenalty: middleDrop,
        maxPenalty: maxPenalty,
        entryType: _selectedEntryType,
        entryCoins: _selectedEntryType == 'COIN' ? _selectedEntryCoins : 0,
      );
      if (mounted) {
        context.push('/lobby/${res['roomCode']}');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinTable() async {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a 6-character room code.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null || (user.isGuest && (user.displayName.isEmpty || user.displayName == 'Guest Player'))) {
      _showSignInModal(onSignedIn: () => _handleJoinTable());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref.read(multiplayerLobbyProvider.notifier).joinTable(roomCode: code);
      if (mounted) {
        context.push('/lobby/${res['roomCode']}');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSignInModal({VoidCallback? onSignedIn}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Sign In Required', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Please sign in with Google or continue as Guest to access Online Multiplayer with Friends.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _promptGuestNameAndSignIn(onSignedIn: onSignedIn);
            },
            child: const Text('Play as Guest', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.account_circle, size: 18),
            label: const Text('Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await ref.read(authProvider.notifier).signInWithGoogle();
                if (mounted) {
                  setState(() => _isLoading = false);
                  onSignedIn?.call();
                }
              } catch (_) {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _promptGuestNameAndSignIn({VoidCallback? onSignedIn}) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('Enter Your Name', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please enter your name to play as guest:',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0A1628),
                hintText: 'e.g. Rahul, Maya, Alex',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
              onSubmitted: (val) {
                final trimmed = val.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.pop(ctx, trimmed);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              Navigator.pop(ctx, trimmed);
            },
            child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await ref.read(authProvider.notifier).signInAsGuest(name: name, forceNewSession: false);
        if (mounted) {
          setState(() => _isLoading = false);
          onSignedIn?.call();
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
  }

  Future<void> _promptChangeGuestName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.accent, size: 20),
            SizedBox(width: 8),
            Text('Change Nickname', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0A1628),
                hintText: 'Enter new nickname',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(ctx, trimmed);
              }
            },
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      await ref.read(authProvider.notifier).updateGuestName(newName.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nickname updated to "${newName.trim()}"'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF081220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => context.go('/'),
        ),
        title: const Row(
          children: [
            Icon(Icons.group_rounded, color: AppColors.accent, size: 20),
            SizedBox(width: 8),
            Text(
              'PLAY WITH FRIENDS',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: user.isGuest ? () => _promptChangeGuestName(user.displayName) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.glass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              user.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (user.isGuest) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, color: Colors.white54, size: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '${user.coins}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _showSignInModal,
              icon: const Icon(Icons.login, color: AppColors.accent, size: 16),
              label: const Text('Sign In', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF142E54), Color(0xFF0B1B33)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.style_rounded, color: AppColors.accent, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        '13-Card Indian Rummy',
                        style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Private Multiplayer Tables',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a custom table or join your friends with a 6-character room code or invite link.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // Option 1: Create Table
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E36),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: AppColors.accent, size: 20),
                          SizedBox(width: 8),
                          Text('Create a Table', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _tableNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Table Name (e.g. Maya Champions)",
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: const Color(0xFF081220),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Number of Players (2 to 6):', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [2, 3, 4, 5, 6].map((count) {
                          final isSelected = _selectedPlayerCount == count;
                          return InkWell(
                            onTap: () => setState(() => _selectedPlayerCount = count),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : const Color(0xFF081220),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? AppColors.accent : AppColors.glassBorder),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text('Game Mode:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Points Rummy', 'Pool 101', 'Pool 201', 'Best of 2 Deals'].map((mode) {
                          final isSelected = _selectedGameMode == mode;
                          return ChoiceChip(
                            label: Text(mode, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            selected: isSelected,
                            selectedColor: AppColors.accent,
                            backgroundColor: const Color(0xFF081220),
                            side: BorderSide(color: isSelected ? AppColors.accent : AppColors.glassBorder),
                            onSelected: (_) => setState(() => _selectedGameMode = mode),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Turn Timer:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [30, 45, 60, 0].map((sec) {
                                    final isSelected = _selectedTurnTimer == sec;
                                    return ChoiceChip(
                                      label: Text(
                                        sec == 0 ? 'No Limit' : '${sec}s',
                                        style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      selected: isSelected,
                                      selectedColor: AppColors.accent,
                                      backgroundColor: const Color(0xFF081220),
                                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.glassBorder),
                                      onSelected: (_) => setState(() => _selectedTurnTimer = sec),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Drop Rules:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: ['20 / 40 / 80', '25 / 50 / 80', 'Custom'].map((rules) {
                                    final isSelected = rules == 'Custom' ? _isCustomDrop : (!_isCustomDrop && _selectedDropPenalty == rules);
                                    return ChoiceChip(
                                      label: Text(rules, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      selected: isSelected,
                                      selectedColor: AppColors.accent,
                                      backgroundColor: const Color(0xFF081220),
                                      side: BorderSide(color: isSelected ? AppColors.accent : AppColors.glassBorder),
                                      onSelected: (_) => setState(() {
                                        if (rules == 'Custom') {
                                          _isCustomDrop = true;
                                        } else {
                                          _isCustomDrop = false;
                                          _selectedDropPenalty = rules;
                                        }
                                      }),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isCustomDrop) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF081220),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Custom Drop Penalties (points):', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _firstDropController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: '1st Drop',
                                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        filled: true,
                                        fillColor: const Color(0xFF0D1B2A),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _middleDropController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Mid Drop',
                                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        filled: true,
                                        fillColor: const Color(0xFF0D1B2A),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _maxPenaltyController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Full Count',
                                        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        filled: true,
                                        fillColor: const Color(0xFF0D1B2A),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Table Entry Mode:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedEntryType = 'FREE'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedEntryType == 'FREE'
                                      ? AppColors.accent.withValues(alpha: 0.15)
                                      : const Color(0xFF081220),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedEntryType == 'FREE' ? AppColors.accent : AppColors.glassBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '🎮 FREE TABLE',
                                      style: TextStyle(
                                        color: _selectedEntryType == 'FREE' ? AppColors.accent : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('0 Coins • Casual', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedEntryType = 'COIN'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedEntryType == 'COIN'
                                      ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                                      : const Color(0xFF081220),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedEntryType == 'COIN' ? const Color(0xFFFFD700) : AppColors.glassBorder,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '🪙 COIN ENTRY',
                                      style: TextStyle(
                                        color: _selectedEntryType == 'COIN' ? const Color(0xFFFFD700) : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('Virtual Coins • Winner Pot', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedEntryType == 'COIN') ...[
                        const SizedBox(height: 14),
                        const Text('Entry Fee per Player (Virtual Coins):', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [100, 250, 500, 1000, 2500, 5000].map((fee) {
                            final isSel = _selectedEntryCoins == fee;
                            return ChoiceChip(
                              label: Text('$fee 🪙', style: TextStyle(color: isSel ? Colors.black : const Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                              selected: isSel,
                              selectedColor: const Color(0xFFFFD700),
                              backgroundColor: const Color(0xFF081220),
                              side: BorderSide(color: isSel ? const Color(0xFFFFD700) : AppColors.glassBorder),
                              onSelected: (_) => setState(() => _selectedEntryCoins = fee),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF081220),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Player Entry Fee:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('$_selectedEntryCoins Coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Host Table Creation Fee:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('$_creationFee Coins', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Host Outlay:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text('${_selectedEntryCoins + _creationFee} Coins', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Est. Winner Prize Pool:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('${_selectedEntryCoins * _selectedPlayerCount} Coins', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'ℹ️ Virtual Coins only. Winner receives entire prize pool. If cancelled, fees are refunded.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        if (user != null && user.coins < (_selectedEntryCoins + _creationFee)) ...[
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ Insufficient coins (Balance: ${user.coins}). You need ${_selectedEntryCoins + _creationFee} coins to create this table.',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (user != null && user.isGuest) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '⚠️ Guest accounts cannot create Coin Tables. Please sign in with Google.',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                          ),
                          onPressed: _isLoading ? null : _handleCreateTable,
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('CREATE TABLE & INVITE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Option 2: Join Table by Code
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E36),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.meeting_room_outlined, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Join by Room Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _roomCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 3),
                        decoration: InputDecoration(
                          hintText: "ENTER CODE (e.g. 7K4P92)",
                          hintStyle: const TextStyle(color: AppColors.textMuted, letterSpacing: 1),
                          filled: true,
                          fillColor: const Color(0xFF081220),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blueAccent)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            foregroundColor: Colors.blueAccent,
                          ),
                          onPressed: _isLoading ? null : _handleJoinTable,
                          child: const Text('JOIN TABLE LOBBY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
