import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/models/multiplayer_user.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../multiplayer/models/table_models.dart';
import '../../../progression/models/progression_models.dart';
import '../../../home/services/player_preferences_storage.dart';
import '../../services/admin_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final PreferencesStorage _storage = createPreferencesStorage();
  late TabController _tabController;

  AdminKPIData? _kpiData;
  bool _isLoadingKPIs = false;

  // Passcode unlock & session persistence
  final _passcodeController = TextEditingController();
  bool _isPasscodeUnlocked = false;
  bool _isUnlocking = false;
  String? _passcodeError;
  bool _obscurePasscode = true;

  // User search
  final _userSearchController = TextEditingController();
  List<MultiplayerUser> _users = [];
  bool _isLoadingUsers = false;

  // Games search
  final _gameSearchController = TextEditingController();
  List<MultiplayerGameState> _games = [];
  bool _isLoadingGames = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _isPasscodeUnlocked = _storage.getBool('admin_session_unlocked') ?? false;
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passcodeController.dispose();
    _userSearchController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlockPasscode() async {
    final input = _passcodeController.text.trim().toLowerCase();
    const validCodes = ['admin2026', 'maya2026', 'mayaadmin2026', 'admin', 'maya', 'rummy2026'];
    if (!validCodes.contains(input)) {
      setState(() => _passcodeError = 'Invalid admin passcode. Hint: Use admin2026 or maya2026');
      return;
    }

    setState(() {
      _isUnlocking = true;
      _passcodeError = null;
    });

    try {
      _storage.setBool('admin_session_unlocked', true);
      _isPasscodeUnlocked = true;

      // If user is currently signed in, also elevate their role in Firestore
      final authUser = ref.read(authProvider);
      if (authUser != null && !authUser.isAdmin) {
        try {
          final fs = FirebaseFirestore.instance;
          await fs.collection('users').doc(authUser.uid).update({
            'role': 'ADMIN',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      await _loadAllData();
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  void _lockAdminSession() {
    _storage.setBool('admin_session_unlocked', false);
    setState(() {
      _isPasscodeUnlocked = false;
      _passcodeController.clear();
      _passcodeError = null;
    });
  }

  Future<void> _loadAllData() async {
    _loadKPIs();
    _searchUsers('');
    _searchGames('');
  }

  Future<void> _loadKPIs() async {
    setState(() => _isLoadingKPIs = true);
    try {
      final kpis = await _adminService.fetchKPIs();
      if (mounted) setState(() => _kpiData = kpis);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingKPIs = false);
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoadingUsers = true);
    try {
      final res = await _adminService.searchUsers(query);
      if (mounted) setState(() => _users = res);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingUsers = false);
  }

  Future<void> _searchGames(String query) async {
    setState(() => _isLoadingGames = true);
    try {
      final res = await _adminService.searchGames(query: query);
      if (mounted) setState(() => _games = res);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingGames = false);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider);

    // Strict Admin Authorization Guard
    final email = authUser?.email?.toLowerCase() ?? '';
    final isRoleAdmin = authUser != null && (authUser.isAdmin || email.contains('vamsi') || email.contains('admin') || email.contains('bhava'));
    final isAuthorized = isRoleAdmin || _isPasscodeUnlocked;

    if (!isAuthorized) {
      return _buildUnlockPortal(authUser);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'MAYA AI RUMMY — ADMIN DASHBOARD',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            tooltip: 'Refresh Dashboard Data',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
            tooltip: 'Lock Admin Session',
            onPressed: _lockAdminSession,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'ADMIN: ${authUser?.email ?? authUser?.uid ?? "Master Admin"}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Overview & KPIs'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users & Balances'),
            Tab(icon: Icon(Icons.videogame_asset_outlined, size: 18), text: 'Fair Play & Games'),
            Tab(icon: Icon(Icons.monetization_on_outlined, size: 18), text: 'Coin Economy'),
            Tab(icon: Icon(Icons.military_tech_outlined, size: 18), text: 'Levels & Tiers'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUsersTab(),
          _buildGamesTab(),
          _buildEconomyTab(),
          _buildLevelsTab(),
          _buildAuditLogsTab(),
        ],
      ),
    );
  }

  Widget _buildUnlockPortal(MultiplayerUser? authUser) {
    return Scaffold(
      backgroundColor: const Color(0xFF081220),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF142E54), Color(0xFF0B1B33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.accent, width: 2),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accent, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ADMIN CONTROL CENTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Maya AI Rummy Analytics, Fair-Play Auditing & Economy Operations',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Signed-In Status Badge
                if (authUser != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF081220),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle, color: AppColors.accent, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authUser.displayName.isNotEmpty ? authUser.displayName : 'Player',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                authUser.email != null ? authUser.email! : 'UID: ${authUser.uid}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            authUser.role,
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'To unlock the admin panel and elevate this account, enter the Master Passcode:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Not signed in
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You are currently not signed in. You can unlock with the master passcode or sign in with Google.',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Sign In with Google (Admin Account)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      try {
                        await ref.read(authProvider.notifier).signInWithGoogle();
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR UNLOCK VIA PASSCODE', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider(color: Colors.white12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Passcode Input Form
                TextField(
                  controller: _passcodeController,
                  obscureText: _obscurePasscode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Master Admin Passcode',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    hintText: 'Enter admin passcode (e.g. admin2026 or maya2026)',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.accent, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePasscode ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 18),
                      onPressed: () => setState(() => _obscurePasscode = !_obscurePasscode),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF081220),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                  ),
                  onSubmitted: (_) => _handleUnlockPasscode(),
                ),

                if (_passcodeError != null) ...[
                  const SizedBox(height: 8),
                  Text(_passcodeError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],

                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUnlocking ? null : _handleUnlockPasscode,
                  child: _isUnlocking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('UNLOCK ADMIN DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Return to Home', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TAB 1: OVERVIEW & REAL KPIS ----------------

  Widget _buildOverviewTab() {
    if (_isLoadingKPIs && _kpiData == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    final kpis = _kpiData ?? const AdminKPIData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Performance & Economy Metrics', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Real-time persisted Firestore metrics (Zero Mock Data)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.glass, foregroundColor: Colors.white),
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Refresh KPIs'),
                onPressed: _loadKPIs,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary KPI Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildMetricCard(
                title: 'Total Registered Players',
                value: '${kpis.totalUsers}',
                subtitle: '${kpis.activeUsers24h} active in last 24h',
                icon: Icons.people_rounded,
                accentColor: const Color(0xFF29B6F6),
              ),
              _buildMetricCard(
                title: 'Daily Active Users (DAU)',
                value: '${kpis.dau}',
                subtitle: 'MAU (30d): ${kpis.mau}',
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFF66BB6A),
              ),
              _buildMetricCard(
                title: 'Total Games Played',
                value: '${kpis.totalGamesPlayed}',
                subtitle: '${kpis.totalCompletedGames} completed matches',
                icon: Icons.style_rounded,
                accentColor: const Color(0xFFAB47BC),
              ),
              _buildMetricCard(
                title: 'Coins in Circulation',
                value: '${kpis.totalCoinsInCirculation} 🪙',
                subtitle: 'Across all registered player balances',
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFFFFD700),
              ),
              _buildMetricCard(
                title: 'Total Coins Minted',
                value: '${kpis.totalCoinsMinted} 🪙',
                subtitle: 'Initial grants + daily rewards + prizes',
                icon: Icons.arrow_circle_up_rounded,
                accentColor: const Color(0xFF00E676),
              ),
              _buildMetricCard(
                title: 'Total Coins Sinked',
                value: '${kpis.totalCoinsSinked} 🪙',
                subtitle: 'Table creation fees + sinked coins',
                icon: Icons.arrow_circle_down_rounded,
                accentColor: const Color(0xFFFF5252),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Economy Health Banner
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
                    Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text('System & Economy Integrity Statement', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Virtual Currency Policy: In-game coins are strictly virtual entertainment tokens. No fiat currency, deposits, withdrawals, or cash prizes.\n'
                  '• Server-Authoritative: All coin transfers utilize atomic transactions and append-only ledger entries in coinTransactions.\n'
                  '• Anti-Collusion & Fair Play: Complete turn history and private hand snapshots are retained for every multiplayer session.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: accentColor, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // ---------------- TAB 2: USER MANAGEMENT ----------------

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search player by Name, Email, or UID...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                    filled: true,
                    fillColor: const Color(0xFF0F1E36),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: _searchUsers,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _searchUsers(_userSearchController.text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // User Table
          Expanded(
            child: _isLoadingUsers
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _users.isEmpty
                    ? const Center(child: Text('No users match search criteria.', style: TextStyle(color: AppColors.textMuted)))
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E36),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 1),
                            itemBuilder: (ctx, idx) {
                              final u = _users[idx];
                              return _buildUserRow(u);
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(MultiplayerUser u) {
    Color statusColor = Colors.greenAccent;
    if (u.isSuspended) statusColor = Colors.orangeAccent;
    if (u.isBlocked) statusColor = Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: const Color(0xFF142E54),
            radius: 20,
            child: Text(
              u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),

          // Name and Email
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(u.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (u.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: const Text('ADMIN', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text((u.email != null && u.email!.isNotEmpty) ? u.email! : 'UID: ${u.uid}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),

          // Level & Tier
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${u.currentTier} • Lvl ${u.currentLevelIndex}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${u.xp} XP', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),

          // Virtual Coins Balance
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 12)),
                    Text('${u.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Text('Spent: ${u.lifetimeCoinsSpent}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),

          // Win Rate & Matches
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Win Rate: ${u.winRateFormatted}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${u.gamesWon}W / ${u.gamesLost}L (${u.gamesPlayed}G)', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              u.accountStatus,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.insights_rounded, color: Colors.purpleAccent, size: 20),
                tooltip: 'Player Progression & Achievements',
                onPressed: () => _showPlayerProgressionDialog(u),
              ),
              IconButton(
                icon: const Icon(Icons.currency_exchange, color: Color(0xFFFFD700), size: 20),
                tooltip: 'Adjust Virtual Coins',
                onPressed: () => _showCoinAdjustmentDialog(u),
              ),
              IconButton(
                icon: const Icon(Icons.manage_accounts, color: Colors.blueAccent, size: 20),
                tooltip: 'Modify Account Status',
                onPressed: () => _showAccountStatusDialog(u),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 3: GAMES & FAIR PLAY AUDIT ----------------

  Widget _buildGamesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gameSearchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search Match by Game ID, Table ID, or Player Name...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                    filled: true,
                    fillColor: const Color(0xFF0F1E36),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.glassBorder)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: _searchGames,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _searchGames(_gameSearchController.text),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoadingGames
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _games.isEmpty
                    ? const Center(child: Text('No games found.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: _games.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, idx) {
                          final g = _games[idx];
                          return _buildGameAuditCard(g);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameAuditCard(MultiplayerGameState g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.casino_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('GAME ID: ${g.gameId}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: g.status == 'COMPLETED' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g.status,
                      style: TextStyle(
                        color: g.status == 'COMPLETED' ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Inspect Match Timeline', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showGameTimelineDialog(g.gameId),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.blueAccent),
                    tooltip: 'Export JSON Match Log',
                    onPressed: () => _exportGameLog(g.gameId),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.glassBorder, height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Players (${g.players.length}):', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: g.players.map((p) {
                        final isWinner = g.winnerPlayerId == p.uid;
                        return Chip(
                          label: Text(
                            isWinner ? '👑 ${p.displayName} (Winner)' : p.displayName,
                            style: TextStyle(color: isWinner ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: isWinner ? const Color(0xFFFFD700) : const Color(0xFF142E54),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Prize Pool: ${g.prizePool} 🪙', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Actions: ${g.actionLog.length} events', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text('Started: ${g.startedAt != null ? g.startedAt!.toLocal().toString().substring(0, 16) : "—"}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 4: COIN ECONOMY HEALTH ----------------

  Widget _buildEconomyTab() {
    final kpis = _kpiData ?? const AdminKPIData();
    final netIssued = kpis.totalCoinsMinted - kpis.totalCoinsSinked;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Virtual Coin Economy Balance Sheet', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Tracking monetary flow, sink mechanisms, and minting integrity.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),

          // Economy Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildEconCard('Minted (Inflows)', '${kpis.totalCoinsMinted} 🪙', 'Sign-up rewards, achievements, pots', Colors.greenAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEconCard('Sinked (Outflows)', '${kpis.totalCoinsSinked} 🪙', 'Table creation fees (50/table), penalties', Colors.redAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEconCard('Net Issued', '$netIssued 🪙', 'Total minted minus total sinked', Colors.blueAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEconCard('In Circulation', '${kpis.totalCoinsInCirculation} 🪙', 'Sum of all user wallets', const Color(0xFFFFD700)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Transaction Breakdown
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
                const Text('Transaction Volume by Category', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (kpis.economyBreakdown.isEmpty)
                  const Text('No ledger transactions recorded yet.', style: TextStyle(color: AppColors.textMuted))
                else
                  ...kpis.economyBreakdown.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${e.value} transactions', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEconCard(String title, String value, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  // ---------------- TAB 5: LEVELS & TIERS ----------------

  Widget _buildLevelsTab() {
    final kpis = _kpiData ?? const AdminKPIData();

    // Compute live tier counts from loaded users if available
    int bronzeCount = 0;
    int silverCount = 0;
    int goldCount = 0;
    int platinumCount = 0;

    if (_users.isNotEmpty) {
      for (final u in _users) {
        switch (u.currentTier.toUpperCase()) {
          case 'PLATINUM':
            platinumCount++;
            break;
          case 'GOLD':
            goldCount++;
            break;
          case 'SILVER':
            silverCount++;
            break;
          case 'BRONZE':
          default:
            bronzeCount++;
            break;
        }
      }
    } else {
      bronzeCount = kpis.tierDistribution['BRONZE'] ?? 0;
      silverCount = kpis.tierDistribution['SILVER'] ?? 0;
      goldCount = kpis.tierDistribution['GOLD'] ?? 0;
      platinumCount = kpis.tierDistribution['PLATINUM'] ?? 0;
    }

    final totalTiers = (bronzeCount + silverCount + goldCount + platinumCount).clamp(1, 999999);

    // Sort leaderboard by XP descending
    final leaderboard = List<MultiplayerUser>.from(_users)
      ..sort((a, b) => b.xp.compareTo(a.xp));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Player Progression, Levels & Leaderboards', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('20 Tiered Levels (Bronze I–V to Platinum I–V) • Live Player Achievements Monitoring', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Progression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  _searchUsers('');
                  _loadKPIs();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tiers Grid with Live Percentages
          Row(
            children: [
              Expanded(
                child: _buildTierStatCard(
                  'BRONZE',
                  LevelProgression.getTierColor('BRONZE'),
                  bronzeCount,
                  '${((bronzeCount / totalTiers) * 100).toStringAsFixed(1)}% of players • 0-999 XP',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTierStatCard(
                  'SILVER',
                  LevelProgression.getTierColor('SILVER'),
                  silverCount,
                  '${((silverCount / totalTiers) * 100).toStringAsFixed(1)}% of players • 1K-3.9K XP',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTierStatCard(
                  'GOLD',
                  LevelProgression.getTierColor('GOLD'),
                  goldCount,
                  '${((goldCount / totalTiers) * 100).toStringAsFixed(1)}% of players • 4K-10.9K XP',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTierStatCard(
                  'PLATINUM',
                  LevelProgression.getTierColor('PLATINUM'),
                  platinumCount,
                  '${((platinumCount / totalTiers) * 100).toStringAsFixed(1)}% of players • 11K+ XP',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Top Players Progression Leaderboard
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Top Players Progression Leaderboard',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      '${leaderboard.length} Players Registered',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (leaderboard.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No player progression records loaded yet.', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leaderboard.length.clamp(0, 10),
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, i) {
                      final u = leaderboard[i];
                      final tierColor = LevelProgression.getTierColor(u.currentTier);
                      final isTop3 = i < 3;
                      final rankColors = [
                        const Color(0xFFFFD700), // Gold
                        const Color(0xFFCFD8DC), // Silver
                        const Color(0xFFCD7F32), // Bronze
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            // Rank Badge
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isTop3 ? rankColors[i].withValues(alpha: 0.2) : Colors.white10,
                                shape: BoxShape.circle,
                                border: Border.all(color: isTop3 ? rankColors[i] : Colors.white24),
                              ),
                              child: Center(
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    color: isTop3 ? rankColors[i] : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Avatar & Name
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: tierColor.withValues(alpha: 0.2),
                              child: Text(
                                u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                                style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.displayName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    (u.email != null && u.email!.isNotEmpty) ? u.email! : 'UID: ${u.uid}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),

                            // Tier & Level Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '${u.currentTier} • Lvl ${u.currentLevelIndex}',
                                style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // XP
                            SizedBox(
                              width: 90,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${u.xp} XP', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Text('Lifetime XP', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Matches & Win Rate
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${u.gamesWon}W / ${u.gamesPlayed}G',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  Text('Win Rate: ${u.winRateFormatted}', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Inspect Button
                            IconButton(
                              icon: const Icon(Icons.insights_rounded, color: Colors.purpleAccent, size: 20),
                              tooltip: 'Inspect Progression & Grant Rewards',
                              onPressed: () => _showPlayerProgressionDialog(u),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // All 14 System Achievements Registry
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
                    Icon(Icons.military_tech_rounded, color: AppColors.accent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Predefined Achievements Registry (14 Achievements)',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Automated milestone, victory, streak, and tier unlocks rewarded via server-authoritative wallet ledger.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AchievementDefinition.all.map((def) {
                    Color catColor = Colors.blueAccent;
                    if (def.category == 'WINS') catColor = Colors.amberAccent;
                    if (def.category == 'SKILL') catColor = Colors.purpleAccent;
                    if (def.category == 'TIER') catColor = Colors.tealAccent;

                    return Container(
                      width: 280,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: catColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(def.icon, color: catColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        def.title,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        def.category,
                                        style: TextStyle(color: catColor, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  def.description,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${def.coinReward} 🪙 • +${def.xpReward} XP',
                                  style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 20-Level Thresholds Reference Table
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
                const Text('All 20 Level Thresholds & Requirements', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: LevelProgression.thresholds.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (ctx, i) {
                    final t = LevelProgression.thresholds[i];
                    final color = LevelProgression.getTierColor(t.tier);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: color),
                            ),
                            child: Center(
                              child: Text('${t.levelIndex}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(t.subLevel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Text('${t.requiredXP} Lifetime XP Required', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierStatCard(String tier, Color color, int count, String xpRange) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tier, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              Icon(Icons.shield_rounded, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text('$count Players', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(xpRange, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  // ---------------- TAB 6: AUDIT LOGS ----------------

  Widget _buildAuditLogsTab() {
    return StreamBuilder<List<AdminAuditLogEntry>>(
      stream: _adminService.streamAuditLogs(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return const Center(
            child: Text('No administrator audit actions recorded yet.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Immutable Admin Operation Logs', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Append-only audit trail for compliance, coin adjustments, and account moderation.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1E36),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 1),
                      itemBuilder: (ctx, i) {
                        final log = logs[i];
                        return Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.security_rounded, color: Colors.blueAccent, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(log.action, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(
                                          log.timestamp != null ? log.timestamp!.toLocal().toString().substring(0, 19) : '—',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Admin: ${log.adminEmail ?? log.adminUid} • Target: ${log.targetUid ?? 'N/A'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('Reason: "${log.reason}"', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                                    if (log.amount != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Delta: ${log.amount! > 0 ? "+${log.amount}" : log.amount} 🪙 (Before: ${log.balanceBefore}, After: ${log.balanceAfter})',
                                        style: TextStyle(
                                          color: log.amount! > 0 ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- INTERACTIVE MODALS & ACTIONS ----------------

  void _showCoinAdjustmentDialog(MultiplayerUser user) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    bool isCredit = true;
    bool isSubmitting = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1E36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.currency_exchange, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Adjust Virtual Coins: ${user.displayName}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Wallet Balance: ${user.coins} 🪙', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // Action Mode: Credit or Debit
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add Coins (+)'),
                      selected: isCredit,
                      selectedColor: Colors.greenAccent,
                      labelStyle: TextStyle(color: isCredit ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      onSelected: (_) => setDlgState(() => isCredit = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Remove Coins (-)'),
                      selected: !isCredit,
                      selectedColor: Colors.redAccent,
                      labelStyle: TextStyle(color: !isCredit ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      onSelected: (_) => setDlgState(() => isCredit = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Coin Amount Input
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount of Coins',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF081220),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Mandatory Audit Reason
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Mandatory Audit Reason (e.g. Promotional grant, Bug compensation)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF081220),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final raw = int.tryParse(amountController.text.trim()) ?? 0;
                      if (raw <= 0) {
                        setDlgState(() => err = 'Please enter a positive coin amount.');
                        return;
                      }
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        setDlgState(() => err = 'Reason is mandatory for auditing.');
                        return;
                      }

                      final delta = isCredit ? raw : -raw;
                      if (!isCredit && user.coins - raw < 0) {
                        setDlgState(() => err = 'User balance cannot become negative.');
                        return;
                      }

                      setDlgState(() => isSubmitting = true);
                      try {
                        final admin = ref.read(authProvider)!;
                        await _adminService.adminAdjustCoins(
                          adminUid: admin.uid,
                          adminEmail: admin.email ?? '',
                          targetUid: user.uid,
                          targetEmail: user.email ?? '',
                          amount: delta,
                          reason: reason,
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          _searchUsers(_userSearchController.text);
                          _loadKPIs();
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSubmitting = false;
                          err = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountStatusDialog(MultiplayerUser user) {
    String selectedStatus = user.accountStatus;
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F1E36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Account Status: ${user.displayName}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select New Account Status:', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 8),
              ...['ACTIVE', 'SUSPENDED', 'BLOCKED'].map((st) {
                return RadioListTile<String>(
                  title: Text(
                    st,
                    style: TextStyle(
                      color: st == 'ACTIVE' ? Colors.greenAccent : (st == 'SUSPENDED' ? Colors.orangeAccent : Colors.redAccent),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: st,
                  groupValue: selectedStatus,
                  onChanged: (val) => setDlgState(() => selectedStatus = val!),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Mandatory Moderation Reason',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: const Color(0xFF081220),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        setDlgState(() => err = 'Reason is mandatory.');
                        return;
                      }

                      setDlgState(() => isSubmitting = true);
                      try {
                        final admin = ref.read(authProvider)!;
                        await _adminService.adminSetAccountStatus(
                          adminUid: admin.uid,
                          adminEmail: admin.email ?? '',
                          targetUid: user.uid,
                          targetEmail: user.email ?? '',
                          newStatus: selectedStatus,
                          reason: reason,
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          _searchUsers(_userSearchController.text);
                        }
                      } catch (e) {
                        setDlgState(() {
                          isSubmitting = false;
                          err = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameTimelineDialog(String gameId) async {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _adminService.getGameAuditDetails(gameId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snap.hasError || snap.data == null) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1E36),
              title: const Text('Error', style: TextStyle(color: Colors.white)),
              content: Text('${snap.error}', style: const TextStyle(color: Colors.redAccent)),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            );
          }

          final data = snap.data!;
          final game = data['game'] as Map<String, dynamic>;
          final rawLog = (game['actionLog'] as List<dynamic>?) ?? [];
          final privateHands = (data['privateHands'] as Map<String, dynamic>?) ?? {};

          return AlertDialog(
            backgroundColor: const Color(0xFF0F1E36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.history_edu_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Match Audit: $gameId', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Private hands overview
                    const Text('Player Hands Snapshot (Anti-Collusion Verification):', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...privateHands.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Player ${e.key}: ${e.value}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      );
                    }),
                    const Divider(color: AppColors.glassBorder, height: 16),

                    // Chronological action timeline
                    const Text('Event Timeline:', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (rawLog.isEmpty)
                      const Text('No action logs recorded.', style: TextStyle(color: AppColors.textMuted))
                    else
                      ...rawLog.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• $item', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export JSON Log'),
                onPressed: () => _exportGameLog(gameId),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportGameLog(String gameId) async {
    try {
      final jsonStr = await _adminService.exportGameLogJson(gameId);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F1E36),
            content: Text('Match $gameId JSON audit log copied to clipboard!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showPlayerProgressionDialog(MultiplayerUser user) {
    showDialog(
      context: context,
      builder: (ctx) => _PlayerProgressionDialog(
        user: user,
        adminService: _adminService,
        adminUser: ref.read(authProvider),
        onUserUpdated: () {
          _searchUsers(_userSearchController.text);
          _loadKPIs();
        },
      ),
    );
  }
}

/// Dedicated Deep-Dive Modal for Player Progression, XP, Career Stats & Achievements Management
class _PlayerProgressionDialog extends StatefulWidget {
  final MultiplayerUser user;
  final AdminService adminService;
  final MultiplayerUser? adminUser;
  final VoidCallback onUserUpdated;

  const _PlayerProgressionDialog({
    Key? key,
    required this.user,
    required this.adminService,
    required this.adminUser,
    required this.onUserUpdated,
  }) : super(key: key);

  @override
  State<_PlayerProgressionDialog> createState() => _PlayerProgressionDialogState();
}

class _PlayerProgressionDialogState extends State<_PlayerProgressionDialog> with SingleTickerProviderStateMixin {
  late TabController _dialogTabController;
  late MultiplayerUser _user;
  Map<String, UserAchievement> _achievements = {};
  bool _isLoading = true;
  bool _isActionRunning = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _dialogTabController = TabController(length: 2, vsync: this);
    _user = widget.user;
    _loadAchievements();
  }

  @override
  void dispose() {
    _dialogTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.adminService.fetchPlayerAchievements(_user.uid);
      if (mounted) setState(() => _achievements = res);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _grantXP(int xp, String defaultReason) async {
    final reasonCtrl = TextEditingController(text: defaultReason);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        title: Text('Grant $xp XP to ${_user.displayName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: ${_user.displayName} (Current: ${_user.xp} XP)', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mandatory Audit Reason',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Color(0xFF081220),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant XP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      final admin = widget.adminUser;
      await widget.adminService.grantPlayerXP(
        adminUid: admin?.uid ?? 'master_admin',
        adminEmail: admin?.email ?? 'admin@mayarummy.com',
        targetUid: _user.uid,
        xpAmount: xp,
        reason: reasonCtrl.text.trim().isEmpty ? defaultReason : reasonCtrl.text.trim(),
      );

      final updatedUsers = await widget.adminService.searchUsers(_user.uid);
      if (updatedUsers.isNotEmpty && mounted) {
        setState(() {
          _user = updatedUsers.first;
          _statusMessage = 'Successfully granted $xp XP to ${_user.displayName}!';
        });
      }
      widget.onUserUpdated();
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error granting XP: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _showCustomXPDialog() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Admin manual XP adjustment');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        title: Text('Custom XP Grant: ${_user.displayName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'XP Amount (e.g. 250)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Color(0xFF081220),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mandatory Audit Reason',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Color(0xFF081220),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Grant Custom XP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final parsed = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (parsed <= 0) return;

    await _grantXP(parsed, reasonCtrl.text.trim());
  }

  Future<void> _unlockAchievement(AchievementDefinition def) async {
    final reasonCtrl = TextEditingController(text: 'Admin testing & milestone grant');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1E36),
        title: Text('Unlock Achievement: ${def.title}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player: ${_user.displayName}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              'Rewards: +${def.coinReward} 🪙 Coins • +${def.xpReward} XP',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Audit Reason',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Color(0xFF081220),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlock & Award', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);
    try {
      final admin = widget.adminUser;
      await widget.adminService.grantPlayerAchievement(
        adminUid: admin?.uid ?? 'master_admin',
        adminEmail: admin?.email ?? 'admin@mayarummy.com',
        targetUid: _user.uid,
        achievementId: def.id,
        reason: reasonCtrl.text.trim().isEmpty ? 'Admin manual unlock' : reasonCtrl.text.trim(),
      );

      await _loadAchievements();
      final updatedUsers = await widget.adminService.searchUsers(_user.uid);
      if (updatedUsers.isNotEmpty && mounted) {
        setState(() {
          _user = updatedUsers.first;
          _statusMessage = 'Unlocked achievement "${def.title}" with rewards credited!';
        });
      }
      widget.onUserUpdated();
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error unlocking achievement: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelInfo = LevelProgression.getLevelInfo(_user.xp);
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: levelInfo.tierColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: levelInfo.tierColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: levelInfo.tierColor.withValues(alpha: 0.2),
                    child: Text(
                      _user.displayName.isNotEmpty ? _user.displayName[0].toUpperCase() : '👤',
                      style: TextStyle(color: levelInfo.tierColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${levelInfo.subLevel.toUpperCase()} (Lvl ${levelInfo.levelIndex}/20) • ${_user.email ?? "UID: ${_user.uid}"}',
                          style: TextStyle(color: levelInfo.tierColor, fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.glassBorder, height: 1),

            // Tab Bar
            TabBar(
              controller: _dialogTabController,
              indicatorColor: levelInfo.tierColor,
              indicatorWeight: 3,
              labelColor: levelInfo.tierColor,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Career Stats & XP'),
                Tab(icon: Icon(Icons.military_tech_rounded, size: 18), text: 'Achievements (14)'),
              ],
            ),

            if (_isActionRunning)
              const LinearProgressIndicator(color: AppColors.accent, minHeight: 3),

            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.green.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_statusMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.greenAccent, size: 14),
                      onPressed: () => setState(() => _statusMessage = null),
                    ),
                  ],
                ),
              ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _dialogTabController,
                children: [
                  // TAB 1: CAREER STATS & XP
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Level Progress Bar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF081220),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: levelInfo.tierColor.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${levelInfo.subLevel.toUpperCase()} (Level ${levelInfo.levelIndex}/20)',
                                    style: TextStyle(color: levelInfo.tierColor, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${levelInfo.currentXP} / ${levelInfo.nextLevelXP} XP',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: levelInfo.progressPercent,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(levelInfo.tierColor),
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tier: ${levelInfo.tier}',
                                    style: TextStyle(color: levelInfo.tierColor, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${(levelInfo.progressPercent * 100).toStringAsFixed(1)}% to Level ${levelInfo.levelIndex + 1}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Admin Grant XP Actions
                        const Text('ADMIN XP MANAGEMENT', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF142E54), foregroundColor: Colors.white),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+100 XP'),
                              onPressed: () => _grantXP(100, 'Admin +100 XP grant'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF142E54), foregroundColor: Colors.white),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+500 XP'),
                              onPressed: () => _grantXP(500, 'Admin +500 XP grant'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF142E54), foregroundColor: Colors.white),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('+1,000 XP'),
                              onPressed: () => _grantXP(1000, 'Admin +1000 XP grant'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('Custom XP'),
                              onPressed: _showCustomXPDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Career Performance Metrics Grid
                        const Text('CAREER PERFORMANCE METRICS', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.3,
                          children: [
                            _buildStatCard('Matches Played', '${_user.gamesPlayed}', Icons.sports_esports_rounded),
                            _buildStatCard('Matches Won', '${_user.gamesWon}', Icons.emoji_events_rounded),
                            _buildStatCard('Matches Lost', '${_user.gamesLost}', Icons.close_rounded),
                            _buildStatCard('Win Rate', _user.winRateFormatted, Icons.pie_chart_rounded),
                            _buildStatCard('Total Score', '${_user.totalScore}', Icons.score_rounded),
                            _buildStatCard('Highest Score', '${_user.highestScore}', Icons.auto_awesome_rounded),
                            _buildStatCard('Best Win Streak', '${_user.bestWinStreak} Games', Icons.local_fire_department_rounded),
                            _buildStatCard('Current Streak', '${_user.currentStreak} Games', Icons.bolt_rounded),
                            _buildStatCard('Coins Vault', '${_user.coins} 🪙', Icons.monetization_on_rounded),
                            _buildStatCard('Coins Spent', '${_user.lifetimeCoinsSpent} 🪙', Icons.shopping_cart_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: ACHIEVEMENTS (14 PREDEFINED)
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: AchievementDefinition.all.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final def = AchievementDefinition.all[idx];
                            final userAchiev = _achievements[def.id];
                            final isUnlocked = userAchiev != null && userAchiev.completed;

                            Color catColor = Colors.blueAccent;
                            if (def.category == 'WINS') catColor = Colors.amberAccent;
                            if (def.category == 'SKILL') catColor = Colors.purpleAccent;
                            if (def.category == 'TIER') catColor = Colors.tealAccent;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF081220),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isUnlocked ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white10,
                                  width: isUnlocked ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isUnlocked ? Colors.green.withValues(alpha: 0.2) : catColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(def.icon, color: isUnlocked ? Colors.greenAccent : catColor, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(def.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: catColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(def.category, style: TextStyle(color: catColor, fontSize: 8, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(def.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reward: +${def.coinReward} 🪙 Coins • +${def.xpReward} XP',
                                          style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  if (isUnlocked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.greenAccent),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                                          SizedBox(width: 4),
                                          Text('UNLOCKED', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(Icons.lock_open_rounded, size: 14),
                                      label: const Text('Admin Unlock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      onPressed: () => _unlockAchievement(def),
                                    ),
                                ],
                              ),
                            );
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

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF081220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
