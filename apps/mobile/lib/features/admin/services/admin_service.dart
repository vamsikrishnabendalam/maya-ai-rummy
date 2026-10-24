import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../auth/models/multiplayer_user.dart';
import '../../multiplayer/models/table_models.dart';
import '../../progression/models/progression_models.dart';
import '../../wallet/services/wallet_service.dart';
import '../../../../core/config/firebase_config.dart';

class AdminKPIData {
  final int totalUsers;
  final int activeUsers24h;
  final int dau;
  final int mau;
  final int totalGamesPlayed;
  final int totalCompletedGames;
  final int totalCoinsInCirculation;
  final int totalCoinsMinted;
  final int totalCoinsSinked;
  final Map<String, int> tierDistribution;
  final Map<String, int> economyBreakdown;

  const AdminKPIData({
    this.totalUsers = 0,
    this.activeUsers24h = 0,
    this.dau = 0,
    this.mau = 0,
    this.totalGamesPlayed = 0,
    this.totalCompletedGames = 0,
    this.totalCoinsInCirculation = 0,
    this.totalCoinsMinted = 0,
    this.totalCoinsSinked = 0,
    this.tierDistribution = const {},
    this.economyBreakdown = const {},
  });
}

class AdminAuditLogEntry {
  final String auditId;
  final String adminUid;
  final String? adminEmail;
  final String? targetUid;
  final String action;
  final String reason;
  final int? amount;
  final int? balanceBefore;
  final int? balanceAfter;
  final DateTime? timestamp;
  final Map<String, dynamic> metadata;

  const AdminAuditLogEntry({
    required this.auditId,
    required this.adminUid,
    this.adminEmail,
    this.targetUid,
    required this.action,
    required this.reason,
    this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.timestamp,
    this.metadata = const {},
  });

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return AdminAuditLogEntry(
      auditId: json['auditId'] ?? '',
      adminUid: json['adminUid'] ?? '',
      adminEmail: json['adminEmail'],
      targetUid: json['targetUid'],
      action: json['action'] ?? '',
      reason: json['reason'] ?? '',
      amount: (json['amount'] as num?)?.toInt(),
      balanceBefore: (json['balanceBefore'] as num?)?.toInt(),
      balanceAfter: (json['balanceAfter'] as num?)?.toInt(),
      timestamp: parseDate(json['timestamp']),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  final WalletService _walletService = WalletService();
  FirebaseFirestore? get _firestore =>
      FirebaseConfig.isInitialized ? FirebaseFirestore.instance : null;

  /// Fetch Real System KPIs from Firestore
  Future<AdminKPIData> fetchKPIs() async {
    final fs = _firestore;
    if (fs == null) {
      return const AdminKPIData();
    }

    try {
      // 1. Fetch Users
      final usersSnap = await fs.collection('users').get();
      final now = DateTime.now();
      final dayAgo = now.subtract(const Duration(hours: 24));
      final monthAgo = now.subtract(const Duration(days: 30));

      int totalUsers = usersSnap.docs.length;
      int active24h = 0;
      int dau = 0;
      int mau = 0;
      int totalCoinsInCirculation = 0;
      final Map<String, int> tiers = {
        'BRONZE': 0,
        'SILVER': 0,
        'GOLD': 0,
        'PLATINUM': 0,
      };

      for (final doc in usersSnap.docs) {
        final d = doc.data();
        final coins = (d['coins'] as num?)?.toInt() ?? 0;
        totalCoinsInCirculation += coins;

        final tier = (d['currentTier'] as String?)?.toUpperCase() ?? 'BRONZE';
        tiers[tier] = (tiers[tier] ?? 0) + 1;

        DateTime? lastActive;
        final rawActive = d['lastActiveAt'];
        if (rawActive is Timestamp) lastActive = rawActive.toDate();
        else if (rawActive is String) lastActive = DateTime.tryParse(rawActive);

        if (lastActive != null) {
          if (lastActive.isAfter(dayAgo)) {
            active24h++;
            dau++;
          }
          if (lastActive.isAfter(monthAgo)) {
            mau++;
          }
        }
      }

      // 2. Fetch Games Summary
      int totalGames = 0;
      int completedGames = 0;
      try {
        final gamesSnap = await fs.collection('games').get();
        totalGames = gamesSnap.docs.length;
        for (final doc in gamesSnap.docs) {
          if (doc.data()['status'] == 'COMPLETED') {
            completedGames++;
          }
        }
      } catch (e) {
        debugPrint('[AdminService] Games metrics query notice: $e');
      }

      // 3. Economy Breakdown from coinTransactions
      int minted = 0;
      int sinked = 0;
      final Map<String, int> econBreakdown = {};
      try {
        final txSnap = await fs.collection('coinTransactions').limit(500).get();
        for (final doc in txSnap.docs) {
          final td = doc.data();
          final type = td['type'] as String? ?? 'OTHER';
          final amount = (td['amount'] as num?)?.toInt() ?? 0;

          econBreakdown[type] = (econBreakdown[type] ?? 0) + 1;
          if (amount > 0) minted += amount;
          else if (amount < 0) sinked += (-amount);
        }
      } catch (e) {
        debugPrint('[AdminService] Coin transactions query notice: $e');
      }

      return AdminKPIData(
        totalUsers: totalUsers,
        activeUsers24h: active24h,
        dau: dau,
        mau: mau,
        totalGamesPlayed: totalGames,
        totalCompletedGames: completedGames,
        totalCoinsInCirculation: totalCoinsInCirculation,
        totalCoinsMinted: minted,
        totalCoinsSinked: sinked,
        tierDistribution: tiers,
        economyBreakdown: econBreakdown,
      );
    } catch (e) {
      debugPrint('[AdminService] fetchKPIs error: $e');
      return const AdminKPIData();
    }
  }

  /// Search users by name, email, or UID
  Future<List<MultiplayerUser>> searchUsers(String query) async {
    final fs = _firestore;
    if (fs == null) return [];

    try {
      final snap = await fs.collection('users').limit(60).get();
      final all = snap.docs.map((d) => MultiplayerUser.fromJson(d.data())).toList();

      final clean = query.trim().toLowerCase();
      if (clean.isEmpty) return all;

      return all.where((u) {
        return u.name.toLowerCase().contains(clean) ||
            u.displayName.toLowerCase().contains(clean) ||
            (u.email?.toLowerCase().contains(clean) ?? false) ||
            u.uid.toLowerCase().contains(clean);
      }).toList();
    } catch (e) {
      debugPrint('[AdminService] searchUsers error: $e');
      return [];
    }
  }

  /// Adjust user virtual coins (Credit or Debit)
  Future<void> adminAdjustCoins({
    required String adminUid,
    required String adminEmail,
    required String targetUid,
    required String targetEmail,
    required int amount,
    required String reason,
  }) async {
    if (amount == 0) throw Exception('Adjustment amount cannot be zero');
    if (reason.trim().isEmpty) throw Exception('An audit reason is required for coin adjustment.');

    await _walletService.adminAdjustCoins(
      adminUid: adminUid,
      targetUid: targetUid,
      amount: amount,
      reason: '$reason (Admin: $adminEmail)',
    );
  }

  /// Change Account Status (ACTIVE, SUSPENDED, BLOCKED)
  Future<void> adminSetAccountStatus({
    required String adminUid,
    required String adminEmail,
    required String targetUid,
    required String targetEmail,
    required String newStatus,
    required String reason,
  }) async {
    final fs = _firestore;
    if (fs == null) return;
    if (reason.trim().isEmpty) throw Exception('An audit reason is required to change user status.');

    final valid = ['ACTIVE', 'SUSPENDED', 'BLOCKED'];
    if (!valid.contains(newStatus)) {
      throw Exception('Invalid status: $newStatus. Must be ACTIVE, SUSPENDED, or BLOCKED.');
    }

    final userRef = fs.collection('users').doc(targetUid);
    final auditId = 'audit_status_${DateTime.now().millisecondsSinceEpoch}_${targetUid.substring(0, targetUid.length.clamp(0, 5))}';
    final auditRef = fs.collection('adminAuditLogs').doc(auditId);

    await fs.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('User $targetUid not found');

      final oldStatus = snap.data()?['accountStatus'] ?? 'ACTIVE';

      tx.update(userRef, {
        'accountStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        'auditId': auditId,
        'adminUid': adminUid,
        'adminEmail': adminEmail,
        'targetUid': targetUid,
        'targetEmail': targetEmail,
        'action': 'STATUS_CHANGE',
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Search match games for fair play review
  Future<List<MultiplayerGameState>> searchGames({String? query, int limit = 30}) async {
    final fs = _firestore;
    if (fs == null) return [];

    try {
      final snap = await fs
          .collection('games')
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      final list = snap.docs.map((d) => MultiplayerGameState.fromJson(d.data())).toList();

      final clean = query?.trim().toLowerCase() ?? '';
      if (clean.isEmpty) return list;

      return list.where((g) {
        return g.gameId.toLowerCase().contains(clean) ||
            g.tableId.toLowerCase().contains(clean) ||
            g.players.any((p) =>
                p.displayName.toLowerCase().contains(clean) ||
                p.uid.toLowerCase().contains(clean));
      }).toList();
    } catch (e) {
      debugPrint('[AdminService] searchGames error: $e');
      return [];
    }
  }

  /// Fetch full match details including private hands and full action history
  Future<Map<String, dynamic>> getGameAuditDetails(String gameId) async {
    final fs = _firestore;
    if (fs == null) return {};

    try {
      final gameDoc = await fs.collection('games').doc(gameId).get();
      if (!gameDoc.exists || gameDoc.data() == null) {
        throw Exception('Game $gameId not found');
      }

      final gameData = gameDoc.data()!;

      // Retrieve all player private hands
      final handsSnap = await fs.collection('games').doc(gameId).collection('privateHands').get();
      final Map<String, dynamic> privateHands = {};
      for (final doc in handsSnap.docs) {
        privateHands[doc.id] = doc.data()['cards'] ?? [];
      }

      return {
        'game': gameData,
        'privateHands': privateHands,
      };
    } catch (e) {
      debugPrint('[AdminService] getGameAuditDetails error: $e');
      rethrow;
    }
  }

  /// Stream Admin Audit Logs
  Stream<List<AdminAuditLogEntry>> streamAuditLogs({int limit = 50}) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    return fs
        .collection('adminAuditLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AdminAuditLogEntry.fromJson(d.data())).toList());
  }

  /// Export complete game audit history as JSON string
  Future<String> exportGameLogJson(String gameId) async {
    final details = await getGameAuditDetails(gameId);
    return const JsonEncoder.withIndent('  ').convert(details);
  }

  /// Grant or adjust player XP authoritatively
  Future<void> grantPlayerXP({
    required String adminUid,
    required String adminEmail,
    required String targetUid,
    required int xpAmount,
    required String reason,
  }) async {
    final fs = _firestore;
    if (fs == null) return;
    if (xpAmount == 0) throw Exception('XP amount cannot be zero');
    if (reason.trim().isEmpty) throw Exception('An audit reason is required for XP adjustments.');

    final userRef = fs.collection('users').doc(targetUid);
    final progressRef = fs.collection('playerProgress').doc(targetUid);
    final auditId = 'audit_xp_${DateTime.now().millisecondsSinceEpoch}_${targetUid.substring(0, targetUid.length.clamp(0, 5))}';
    final auditRef = fs.collection('adminAuditLogs').doc(auditId);

    await fs.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) throw Exception('User $targetUid not found');

      final currentXP = (snap.data()?['xp'] as num?)?.toInt() ?? 0;
      final currentLifetimeXP = (snap.data()?['lifetimeXP'] as num?)?.toInt() ?? currentXP;

      final newXP = (currentXP + xpAmount).clamp(0, 9999999);
      final newLifetimeXP = (currentLifetimeXP + xpAmount).clamp(0, 9999999);
      final levelInfo = LevelProgression.getLevelInfo(newXP);

      tx.update(userRef, {
        'xp': newXP,
        'lifetimeXP': newLifetimeXP,
        'currentTier': levelInfo.tier,
        'currentLevel': levelInfo.subLevel,
        'currentLevelIndex': levelInfo.levelIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(progressRef, {
        'uid': targetUid,
        'xp': newXP,
        'lifetimeXP': newLifetimeXP,
        'tier': levelInfo.tier,
        'subLevel': levelInfo.subLevel,
        'levelIndex': levelInfo.levelIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(auditRef, {
        'auditId': auditId,
        'adminUid': adminUid,
        'adminEmail': adminEmail,
        'targetUid': targetUid,
        'action': 'XP_GRANT',
        'amount': xpAmount,
        'balanceBefore': currentXP,
        'balanceAfter': newXP,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Manually unlock and grant an achievement to a player
  Future<void> grantPlayerAchievement({
    required String adminUid,
    required String adminEmail,
    required String targetUid,
    required String achievementId,
    required String reason,
  }) async {
    final fs = _firestore;
    if (fs == null) return;

    final def = AchievementDefinition.all.firstWhere(
      (a) => a.id == achievementId,
      orElse: () => throw Exception('Achievement $achievementId does not exist in definition registry'),
    );

    final achievRef = fs.collection('users').doc(targetUid).collection('achievements').doc(achievementId);
    final auditId = 'audit_achiev_${DateTime.now().millisecondsSinceEpoch}_${targetUid.substring(0, targetUid.length.clamp(0, 5))}';
    final auditRef = fs.collection('adminAuditLogs').doc(auditId);

    await achievRef.set({
      'achievementId': def.id,
      'progress': def.target,
      'target': def.target,
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'rewardClaimed': true,
      'grantedByAdmin': adminEmail,
    });

    if (def.coinReward > 0) {
      await _walletService.creditCoins(
        uid: targetUid,
        amount: def.coinReward,
        type: 'ADMIN_ACHIEVEMENT_REWARD',
        reason: 'Admin Granted: ${def.title} ($reason)',
        referenceId: def.id,
      );
    }

    if (def.xpReward > 0) {
      await grantPlayerXP(
        adminUid: adminUid,
        adminEmail: adminEmail,
        targetUid: targetUid,
        xpAmount: def.xpReward,
        reason: 'Achievement Reward: ${def.title}',
      );
    }

    await auditRef.set({
      'auditId': auditId,
      'adminUid': adminUid,
      'adminEmail': adminEmail,
      'targetUid': targetUid,
      'action': 'ACHIEVEMENT_UNLOCK',
      'reason': reason,
      'metadata': {
        'achievementId': achievementId,
        'title': def.title,
        'coinReward': def.coinReward,
        'xpReward': def.xpReward,
      },
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch all achievements unlocked by a user
  Future<Map<String, UserAchievement>> fetchPlayerAchievements(String uid) async {
    final fs = _firestore;
    if (fs == null) return {};

    try {
      final snap = await fs.collection('users').doc(uid).collection('achievements').get();
      final map = <String, UserAchievement>{};
      for (final doc in snap.docs) {
        final a = UserAchievement.fromJson(doc.data());
        map[a.achievementId] = a;
      }
      return map;
    } catch (e) {
      debugPrint('[AdminService] fetchPlayerAchievements error: $e');
      return {};
    }
  }

  /// Fetch player detailed career stats
  Future<PlayerStats?> fetchPlayerStats(String uid) async {
    final fs = _firestore;
    if (fs == null) return null;

    try {
      final snap = await fs.collection('playerStats').doc(uid).get();
      if (snap.exists && snap.data() != null) {
        return PlayerStats.fromJson(snap.data()!);
      }
      final userSnap = await fs.collection('users').doc(uid).get();
      if (userSnap.exists && userSnap.data() != null) {
        final d = userSnap.data()!;
        return PlayerStats(
          uid: uid,
          gamesPlayed: (d['gamesPlayed'] as num?)?.toInt() ?? 0,
          gamesWon: (d['gamesWon'] as num?)?.toInt() ?? 0,
          gamesLost: (d['gamesLost'] as num?)?.toInt() ?? 0,
          totalScore: (d['totalScore'] as num?)?.toInt() ?? 0,
          highestScore: (d['highestScore'] as num?)?.toInt() ?? 0,
          currentStreak: (d['currentStreak'] as num?)?.toInt() ?? 0,
          bestWinStreak: (d['bestWinStreak'] as num?)?.toInt() ?? 0,
          totalCoinsEarned: (d['lifetimeCoinsEarned'] as num?)?.toInt() ?? 0,
          totalCoinsSpent: (d['lifetimeCoinsSpent'] as num?)?.toInt() ?? 0,
        );
      }
      return null;
    } catch (e) {
      debugPrint('[AdminService] fetchPlayerStats error: $e');
      return null;
    }
  }
}
