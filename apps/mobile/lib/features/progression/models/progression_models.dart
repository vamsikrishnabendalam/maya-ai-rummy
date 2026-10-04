import 'package:flutter/material.dart';

class LevelThreshold {
  final int levelIndex; // 1 to 20
  final String tier; // BRONZE | SILVER | GOLD | PLATINUM
  final String subLevel; // Bronze I, Silver II, etc.
  final int requiredXP;

  const LevelThreshold({
    required this.levelIndex,
    required this.tier,
    required this.subLevel,
    required this.requiredXP,
  });
}

class LevelProgression {
  static const List<LevelThreshold> thresholds = [
    LevelThreshold(levelIndex: 1, tier: 'BRONZE', subLevel: 'Bronze I', requiredXP: 0),
    LevelThreshold(levelIndex: 2, tier: 'BRONZE', subLevel: 'Bronze II', requiredXP: 100),
    LevelThreshold(levelIndex: 3, tier: 'BRONZE', subLevel: 'Bronze III', requiredXP: 250),
    LevelThreshold(levelIndex: 4, tier: 'BRONZE', subLevel: 'Bronze IV', requiredXP: 450),
    LevelThreshold(levelIndex: 5, tier: 'BRONZE', subLevel: 'Bronze V', requiredXP: 700),
    LevelThreshold(levelIndex: 6, tier: 'SILVER', subLevel: 'Silver I', requiredXP: 1000),
    LevelThreshold(levelIndex: 7, tier: 'SILVER', subLevel: 'Silver II', requiredXP: 1400),
    LevelThreshold(levelIndex: 8, tier: 'SILVER', subLevel: 'Silver III', requiredXP: 1900),
    LevelThreshold(levelIndex: 9, tier: 'SILVER', subLevel: 'Silver IV', requiredXP: 2500),
    LevelThreshold(levelIndex: 10, tier: 'SILVER', subLevel: 'Silver V', requiredXP: 3200),
    LevelThreshold(levelIndex: 11, tier: 'GOLD', subLevel: 'Gold I', requiredXP: 4000),
    LevelThreshold(levelIndex: 12, tier: 'GOLD', subLevel: 'Gold II', requiredXP: 5000),
    LevelThreshold(levelIndex: 13, tier: 'GOLD', subLevel: 'Gold III', requiredXP: 6200),
    LevelThreshold(levelIndex: 14, tier: 'GOLD', subLevel: 'Gold IV', requiredXP: 7600),
    LevelThreshold(levelIndex: 15, tier: 'GOLD', subLevel: 'Gold V', requiredXP: 9200),
    LevelThreshold(levelIndex: 16, tier: 'PLATINUM', subLevel: 'Platinum I', requiredXP: 11000),
    LevelThreshold(levelIndex: 17, tier: 'PLATINUM', subLevel: 'Platinum II', requiredXP: 13200),
    LevelThreshold(levelIndex: 18, tier: 'PLATINUM', subLevel: 'Platinum III', requiredXP: 16000),
    LevelThreshold(levelIndex: 19, tier: 'PLATINUM', subLevel: 'Platinum IV', requiredXP: 19500),
    LevelThreshold(levelIndex: 20, tier: 'PLATINUM', subLevel: 'Platinum V', requiredXP: 24000),
  ];

  static LevelInfo getLevelInfo(int xp) {
    if (xp < 0) xp = 0;
    LevelThreshold current = thresholds.first;
    LevelThreshold? next;

    for (int i = 0; i < thresholds.length; i++) {
      if (xp >= thresholds[i].requiredXP) {
        current = thresholds[i];
        next = (i + 1 < thresholds.length) ? thresholds[i + 1] : null;
      } else {
        break;
      }
    }

    final minXP = current.requiredXP;
    final maxXP = next != null ? next.requiredXP : minXP + 5000;
    final span = maxXP - minXP;
    final progressInLevel = (xp - minXP).clamp(0, span);
    final percent = span > 0 ? (progressInLevel / span).clamp(0.0, 1.0) : 1.0;

    return LevelInfo(
      levelIndex: current.levelIndex,
      tier: current.tier,
      subLevel: current.subLevel,
      currentXP: xp,
      levelMinXP: minXP,
      nextLevelXP: maxXP,
      progressPercent: percent,
    );
  }

  static Color getTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'PLATINUM':
        return const Color(0xFF00E5FF);
      case 'GOLD':
        return const Color(0xFFFFD700);
      case 'SILVER':
        return const Color(0xFFCFD8DC);
      case 'BRONZE':
      default:
        return const Color(0xFFCD7F32);
    }
  }
}

class LevelInfo {
  final int levelIndex;
  final String tier;
  final String subLevel;
  final int currentXP;
  final int levelMinXP;
  final int nextLevelXP;
  final double progressPercent;

  const LevelInfo({
    required this.levelIndex,
    required this.tier,
    required this.subLevel,
    required this.currentXP,
    required this.levelMinXP,
    required this.nextLevelXP,
    required this.progressPercent,
  });

  Color get tierColor => LevelProgression.getTierColor(tier);
}

class PlayerStats {
  final String uid;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int totalScore;
  final int highestScore;
  final int declarations;
  final int successfulDeclarations;
  final int failedDeclarations;
  final int currentStreak;
  final int bestWinStreak;
  final int totalCoinsEarned;
  final int totalCoinsSpent;
  final double averageScore;
  final int averageDurationSeconds;

  const PlayerStats({
    required this.uid,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.totalScore = 0,
    this.highestScore = 0,
    this.declarations = 0,
    this.successfulDeclarations = 0,
    this.failedDeclarations = 0,
    this.currentStreak = 0,
    this.bestWinStreak = 0,
    this.totalCoinsEarned = 0,
    this.totalCoinsSpent = 0,
    this.averageScore = 0.0,
    this.averageDurationSeconds = 0,
  });

  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  String get winRateFormatted => gamesPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : '—';

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'gamesPlayed': gamesPlayed,
    'gamesWon': gamesWon,
    'gamesLost': gamesLost,
    'totalScore': totalScore,
    'highestScore': highestScore,
    'declarations': declarations,
    'successfulDeclarations': successfulDeclarations,
    'failedDeclarations': failedDeclarations,
    'currentStreak': currentStreak,
    'bestWinStreak': bestWinStreak,
    'totalCoinsEarned': totalCoinsEarned,
    'totalCoinsSpent': totalCoinsSpent,
    'averageScore': averageScore,
    'averageDurationSeconds': averageDurationSeconds,
  };

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
    uid: json['uid'] ?? '',
    gamesPlayed: json['gamesPlayed'] ?? 0,
    gamesWon: json['gamesWon'] ?? 0,
    gamesLost: json['gamesLost'] ?? 0,
    totalScore: json['totalScore'] ?? 0,
    highestScore: json['highestScore'] ?? 0,
    declarations: json['declarations'] ?? 0,
    successfulDeclarations: json['successfulDeclarations'] ?? 0,
    failedDeclarations: json['failedDeclarations'] ?? 0,
    currentStreak: json['currentStreak'] ?? 0,
    bestWinStreak: json['bestWinStreak'] ?? 0,
    totalCoinsEarned: json['totalCoinsEarned'] ?? 0,
    totalCoinsSpent: json['totalCoinsSpent'] ?? 0,
    averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
    averageDurationSeconds: json['averageDurationSeconds'] ?? 0,
  );
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int target;
  final int coinReward;
  final int xpReward;
  final String category; // 'GAMES' | 'WINS' | 'SKILL' | 'TIER'

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.coinReward,
    required this.xpReward,
    required this.category,
  });

  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: 'FIRST_GAME',
      title: 'First Step',
      description: 'Play your first rummy game',
      icon: Icons.sports_esports_rounded,
      target: 1,
      coinReward: 100,
      xpReward: 50,
      category: 'GAMES',
    ),
    AchievementDefinition(
      id: 'FIRST_WIN',
      title: 'First Victory',
      description: 'Win your first rummy match',
      icon: Icons.emoji_events_rounded,
      target: 1,
      coinReward: 200,
      xpReward: 100,
      category: 'WINS',
    ),
    AchievementDefinition(
      id: 'GAMES_PLAYED_10',
      title: 'Rummy Regular',
      description: 'Complete 10 multiplayer matches',
      icon: Icons.style_rounded,
      target: 10,
      coinReward: 300,
      xpReward: 150,
      category: 'GAMES',
    ),
    AchievementDefinition(
      id: 'GAMES_PLAYED_25',
      title: 'Table Veteran',
      description: 'Complete 25 multiplayer matches',
      icon: Icons.military_tech_rounded,
      target: 25,
      coinReward: 500,
      xpReward: 250,
      category: 'GAMES',
    ),
    AchievementDefinition(
      id: 'GAMES_PLAYED_50',
      title: 'Master Tactician',
      description: 'Complete 50 multiplayer matches',
      icon: Icons.workspace_premium_rounded,
      target: 50,
      coinReward: 1000,
      xpReward: 500,
      category: 'GAMES',
    ),
    AchievementDefinition(
      id: 'GAMES_PLAYED_100',
      title: 'Century Club',
      description: 'Complete 100 multiplayer matches',
      icon: Icons.diamond_rounded,
      target: 100,
      coinReward: 2000,
      xpReward: 1000,
      category: 'GAMES',
    ),
    AchievementDefinition(
      id: 'FIRST_DECLARATION',
      title: 'Clean Show',
      description: 'Successfully declare a valid hand',
      icon: Icons.verified_rounded,
      target: 1,
      coinReward: 150,
      xpReward: 75,
      category: 'SKILL',
    ),
    AchievementDefinition(
      id: 'DECLARATIONS_10',
      title: 'Pure Sequence Prodigy',
      description: 'Complete 10 successful declarations',
      icon: Icons.stars_rounded,
      target: 10,
      coinReward: 500,
      xpReward: 250,
      category: 'SKILL',
    ),
    AchievementDefinition(
      id: 'WIN_STREAK_3',
      title: 'On Fire',
      description: 'Win 3 consecutive matches',
      icon: Icons.local_fire_department_rounded,
      target: 3,
      coinReward: 400,
      xpReward: 200,
      category: 'WINS',
    ),
    AchievementDefinition(
      id: 'WIN_STREAK_5',
      title: 'Unstoppable',
      description: 'Win 5 consecutive matches',
      icon: Icons.bolt_rounded,
      target: 5,
      coinReward: 1000,
      xpReward: 500,
      category: 'WINS',
    ),
    AchievementDefinition(
      id: 'HIGH_SCORE_MASTER',
      title: 'Flawless Victory',
      description: 'Win with a perfect 0-penalty score',
      icon: Icons.auto_awesome_rounded,
      target: 1,
      coinReward: 300,
      xpReward: 150,
      category: 'SKILL',
    ),
    AchievementDefinition(
      id: 'REACH_SILVER',
      title: 'Silver Standard',
      description: 'Reach Silver tier (1,000 XP)',
      icon: Icons.shield_rounded,
      target: 1000,
      coinReward: 500,
      xpReward: 300,
      category: 'TIER',
    ),
    AchievementDefinition(
      id: 'REACH_GOLD',
      title: 'Golden Era',
      description: 'Reach Gold tier (4,000 XP)',
      icon: Icons.workspace_premium_rounded,
      target: 4000,
      coinReward: 1000,
      xpReward: 600,
      category: 'TIER',
    ),
    AchievementDefinition(
      id: 'REACH_PLATINUM',
      title: 'Platinum Legend',
      description: 'Reach Platinum tier (11,000 XP)',
      icon: Icons.military_tech_rounded,
      target: 11000,
      coinReward: 2500,
      xpReward: 1500,
      category: 'TIER',
    ),
  ];
}

class UserAchievement {
  final String achievementId;
  final int progress;
  final int target;
  final bool completed;
  final DateTime? completedAt;
  final bool rewardClaimed;

  const UserAchievement({
    required this.achievementId,
    this.progress = 0,
    required this.target,
    this.completed = false,
    this.completedAt,
    this.rewardClaimed = false,
  });

  double get progressPercent => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'achievementId': achievementId,
    'progress': progress,
    'target': target,
    'completed': completed,
    'completedAt': completedAt?.toIso8601String(),
    'rewardClaimed': rewardClaimed,
  };

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      try {
        final toDate = (d as dynamic).toDate;
        if (toDate != null) return toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return UserAchievement(
      achievementId: json['achievementId'] ?? '',
      progress: json['progress'] ?? 0,
      target: json['target'] ?? 1,
      completed: json['completed'] ?? false,
      completedAt: parseDate(json['completedAt']),
      rewardClaimed: json['rewardClaimed'] ?? false,
    );
  }
}
