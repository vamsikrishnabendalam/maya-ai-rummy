import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/progression_models.dart';
import '../../wallet/services/wallet_service.dart';
import '../../../../core/config/firebase_config.dart';

class ProgressionService {
  static final ProgressionService _instance = ProgressionService._internal();
  factory ProgressionService() => _instance;
  ProgressionService._internal();

  final WalletService _walletService = WalletService();
  FirebaseFirestore? get _firestore =>
      FirebaseConfig.isInitialized ? FirebaseFirestore.instance : null;

  /// Authoritatively records a completed multiplayer match result for a player
  Future<void> recordCompletedMatch({
    required String uid,
    required bool won,
    required int score,
    required bool madeDeclaration,
    required int matchDurationSeconds,
    required int playerCount,
  }) async {
    final fs = _firestore;
    if (fs == null) return;

    final userRef = fs.collection('users').doc(uid);
    final statsRef = fs.collection('playerStats').doc(uid);
    final progressRef = fs.collection('playerProgress').doc(uid);

    // XP calculation:
    // +25 XP for match completion
    // +75 XP for match victory
    // +30 XP for valid declaration
    int earnedXP = 25;
    if (won) earnedXP += 75;
    if (madeDeclaration) earnedXP += 30;

    await fs.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      final userData = userSnap.data()!;
      final currentPlayed = (userData['gamesPlayed'] as num?)?.toInt() ?? 0;
      final currentWon = (userData['gamesWon'] as num?)?.toInt() ?? 0;
      final currentLost = (userData['gamesLost'] as num?)?.toInt() ?? 0;
      final currentTotalScore = (userData['totalScore'] as num?)?.toInt() ?? 0;
      final currentHighest = (userData['highestScore'] as num?)?.toInt() ?? 0;
      final currentStreak = (userData['currentStreak'] as num?)?.toInt() ?? 0;
      final bestStreak = (userData['bestWinStreak'] as num?)?.toInt() ?? 0;
      final currentXP = (userData['xp'] as num?)?.toInt() ?? 0;
      final currentLifetimeXP = (userData['lifetimeXP'] as num?)?.toInt() ?? currentXP;

      final newPlayed = currentPlayed + 1;
      final newWon = won ? currentWon + 1 : currentWon;
      final newLost = won ? currentLost : currentLost + 1;
      final newTotalScore = currentTotalScore + score;
      final newHighest = score > currentHighest ? score : currentHighest;
      final newStreak = won ? currentStreak + 1 : 0;
      final newBestStreak = newStreak > bestStreak ? newStreak : bestStreak;
      final newXP = currentXP + earnedXP;
      final newLifetimeXP = currentLifetimeXP + earnedXP;

      final levelInfo = LevelProgression.getLevelInfo(newXP);

      // 1. Update user document
      transaction.update(userRef, {
        'gamesPlayed': newPlayed,
        'gamesWon': newWon,
        'gamesLost': newLost,
        'totalScore': newTotalScore,
        'highestScore': newHighest,
        'currentStreak': newStreak,
        'bestWinStreak': newBestStreak,
        'xp': newXP,
        'lifetimeXP': newLifetimeXP,
        'currentTier': levelInfo.tier,
        'currentLevel': levelInfo.subLevel,
        'currentLevelIndex': levelInfo.levelIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update playerStats document
      transaction.set(statsRef, {
        'uid': uid,
        'gamesPlayed': newPlayed,
        'gamesWon': newWon,
        'gamesLost': newLost,
        'totalScore': newTotalScore,
        'highestScore': newHighest,
        'currentStreak': newStreak,
        'bestWinStreak': newBestStreak,
        'totalCoinsEarned': userData['lifetimeCoinsEarned'] ?? 0,
        'totalCoinsSpent': userData['lifetimeCoinsSpent'] ?? 0,
        'averageScore': newPlayed > 0 ? (newTotalScore / newPlayed) : 0.0,
        'averageDurationSeconds': matchDurationSeconds,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Update playerProgress document
      transaction.set(progressRef, {
        'uid': uid,
        'xp': newXP,
        'lifetimeXP': newLifetimeXP,
        'tier': levelInfo.tier,
        'subLevel': levelInfo.subLevel,
        'levelIndex': levelInfo.levelIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // 4. Check achievements asynchronously
    await checkAchievements(
      uid: uid,
      score: score,
      won: won,
      madeDeclaration: madeDeclaration,
    );
  }

  /// Evaluates 14 predefined achievements and grants rewards if unlocked
  Future<void> checkAchievements({
    required String uid,
    required int score,
    required bool won,
    required bool madeDeclaration,
  }) async {
    final fs = _firestore;
    if (fs == null) return;

    try {
      final userSnap = await fs.collection('users').doc(uid).get();
      if (!userSnap.exists) return;
      final data = userSnap.data()!;
      final gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
      final gamesWon = (data['gamesWon'] as num?)?.toInt() ?? 0;
      final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final xp = (data['xp'] as num?)?.toInt() ?? 0;

      final achievCol = fs.collection('users').doc(uid).collection('achievements');

      for (final def in AchievementDefinition.all) {
        int currentProgress = 0;
        bool isMet = false;

        switch (def.id) {
          case 'FIRST_GAME':
            currentProgress = gamesPlayed;
            isMet = gamesPlayed >= 1;
            break;
          case 'FIRST_WIN':
            currentProgress = gamesWon;
            isMet = gamesWon >= 1;
            break;
          case 'GAMES_PLAYED_10':
            currentProgress = gamesPlayed;
            isMet = gamesPlayed >= 10;
            break;
          case 'GAMES_PLAYED_25':
            currentProgress = gamesPlayed;
            isMet = gamesPlayed >= 25;
            break;
          case 'GAMES_PLAYED_50':
            currentProgress = gamesPlayed;
            isMet = gamesPlayed >= 50;
            break;
          case 'GAMES_PLAYED_100':
            currentProgress = gamesPlayed;
            isMet = gamesPlayed >= 100;
            break;
          case 'FIRST_DECLARATION':
            currentProgress = madeDeclaration ? 1 : 0;
            isMet = madeDeclaration;
            break;
          case 'DECLARATIONS_10':
            // Read declarations count if tracked
            currentProgress = madeDeclaration ? 1 : 0;
            isMet = false; // Progresses cumulatively
            break;
          case 'WIN_STREAK_3':
            currentProgress = currentStreak;
            isMet = currentStreak >= 3;
            break;
          case 'WIN_STREAK_5':
            currentProgress = currentStreak;
            isMet = currentStreak >= 5;
            break;
          case 'HIGH_SCORE_MASTER':
            currentProgress = (won && score == 0) ? 1 : 0;
            isMet = won && score == 0;
            break;
          case 'REACH_SILVER':
            currentProgress = xp;
            isMet = xp >= 1000;
            break;
          case 'REACH_GOLD':
            currentProgress = xp;
            isMet = xp >= 4000;
            break;
          case 'REACH_PLATINUM':
            currentProgress = xp;
            isMet = xp >= 11000;
            break;
        }

        final docRef = achievCol.doc(def.id);
        final docSnap = await docRef.get();
        final alreadyCompleted = docSnap.exists && (docSnap.data()?['completed'] == true);

        if (isMet && !alreadyCompleted) {
          // Grant achievement!
          await docRef.set({
            'achievementId': def.id,
            'progress': def.target,
            'target': def.target,
            'completed': true,
            'completedAt': FieldValue.serverTimestamp(),
            'rewardClaimed': true,
          });

          // Award coins via WalletService
          if (def.coinReward > 0) {
            await _walletService.creditCoins(
              uid: uid,
              amount: def.coinReward,
              type: 'ACHIEVEMENT_REWARD',
              reason: 'Achievement Unlocked: ${def.title}',
              referenceId: def.id,
            );
          }

          // Award XP
          if (def.xpReward > 0) {
            await fs.collection('users').doc(uid).update({
              'xp': FieldValue.increment(def.xpReward),
              'lifetimeXP': FieldValue.increment(def.xpReward),
            });
          }
        } else if (!alreadyCompleted) {
          // Update progress
          await docRef.set({
            'achievementId': def.id,
            'progress': currentProgress.clamp(0, def.target),
            'target': def.target,
            'completed': false,
            'rewardClaimed': false,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('[ProgressionService] checkAchievements error: $e');
    }
  }

  /// Stream user achievements from Firestore
  Stream<List<UserAchievement>> streamUserAchievements(String uid) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    return fs
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserAchievement.fromJson(d.data())).toList());
  }

  /// Stream player statistics
  Stream<PlayerStats?> streamPlayerStats(String uid) {
    final fs = _firestore;
    if (fs == null) return Stream.value(null);

    return fs.collection('playerStats').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return PlayerStats.fromJson(snap.data()!);
    });
  }
}
