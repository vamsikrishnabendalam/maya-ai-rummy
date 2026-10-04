import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../wallet/services/wallet_service.dart';
import '../../../../core/config/firebase_config.dart';

class DailyRewardTier {
  final int day;
  final int coins;
  final int xp;
  final bool isBonus;

  const DailyRewardTier({
    required this.day,
    required this.coins,
    required this.xp,
    this.isBonus = false,
  });
}

class RewardsService {
  static final RewardsService _instance = RewardsService._internal();
  factory RewardsService() => _instance;
  RewardsService._internal();

  final WalletService _walletService = WalletService();
  FirebaseFirestore? get _firestore =>
      FirebaseConfig.isInitialized ? FirebaseFirestore.instance : null;

  static const List<DailyRewardTier> schedule = [
    DailyRewardTier(day: 1, coins: 100, xp: 20),
    DailyRewardTier(day: 2, coins: 150, xp: 25),
    DailyRewardTier(day: 3, coins: 200, xp: 30),
    DailyRewardTier(day: 4, coins: 250, xp: 35),
    DailyRewardTier(day: 5, coins: 300, xp: 40),
    DailyRewardTier(day: 6, coins: 400, xp: 50),
    DailyRewardTier(day: 7, coins: 750, xp: 100, isBonus: true),
  ];

  static String getTodayUtcString() {
    return DateTime.now().toUtc().toIso8601String().substring(0, 10);
  }

  static String getYesterdayUtcString() {
    return DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
  }

  /// Checks if the user is eligible for today's daily reward
  Future<bool> isEligibleForDailyReward(String uid) async {
    final fs = _firestore;
    if (fs == null) return false;

    try {
      final doc = await fs.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      if (data['isGuest'] == true) return false;

      final lastDate = data['lastRewardDate'] as String?;
      final today = getTodayUtcString();
      return lastDate != today;
    } catch (e) {
      debugPrint('[RewardsService] isEligible error: $e');
      return false;
    }
  }

  /// Authoritative claim of today's daily reward
  Future<Map<String, dynamic>> claimDailyReward(String uid) async {
    final fs = _firestore;
    if (fs == null) throw Exception('Database not available');

    final userRef = fs.collection('users').doc(uid);
    final today = getTodayUtcString();
    final yesterday = getYesterdayUtcString();

    return await fs.runTransaction((transaction) async {
      final snap = await transaction.get(userRef);
      if (!snap.exists) throw Exception('User not found');

      final data = snap.data()!;
      if (data['isGuest'] == true) {
        throw Exception('Guest accounts are not eligible for daily rewards. Please sign in with Google.');
      }
      final status = data['accountStatus'] ?? 'ACTIVE';
      if (status == 'BLOCKED' || status == 'SUSPENDED') {
        throw Exception('Account is $status. Rewards cannot be claimed.');
      }

      final lastDate = data['lastRewardDate'] as String?;
      if (lastDate == today) {
        throw Exception('Daily reward already claimed today. Please return tomorrow!');
      }

      int currentStreak = (data['loginStreak'] as num?)?.toInt() ?? 1;
      int nextStreak;
      if (lastDate == yesterday) {
        nextStreak = (currentStreak >= 7) ? 1 : currentStreak + 1;
      } else {
        // Streak broken or first reward
        nextStreak = 1;
      }

      final tier = schedule.firstWhere((s) => s.day == nextStreak, orElse: () => schedule.first);

      // 1. Update user document
      transaction.update(userRef, {
        'lastRewardDate': today,
        'loginStreak': nextStreak,
        'xp': FieldValue.increment(tier.xp),
        'lifetimeXP': FieldValue.increment(tier.xp),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Credit coins via WalletService ledger
      await _walletService.creditCoins(
        uid: uid,
        amount: tier.coins,
        type: 'DAILY_LOGIN_REWARD',
        reason: 'Day $nextStreak Daily Login Reward',
        referenceId: 'daily_reward_$today',
      );

      return {
        'success': true,
        'day': nextStreak,
        'coins': tier.coins,
        'xp': tier.xp,
      };
    });
  }
}
