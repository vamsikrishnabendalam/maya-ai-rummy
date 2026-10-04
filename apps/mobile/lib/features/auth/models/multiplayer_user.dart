class MultiplayerUser {
  final String uid;
  final String displayName;
  final String name;
  final String photoURL;
  final String? email;
  final String dateOfBirth;
  final String country;
  final String accountStatus; // ACTIVE | BLOCKED | SUSPENDED
  final String role; // PLAYER | ADMIN
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int totalScore;
  final int highestScore;
  final int coins;
  final int lifetimeCoinsEarned;
  final int lifetimeCoinsSpent;
  final String currentTier; // BRONZE | SILVER | GOLD | PLATINUM
  final String currentLevel; // e.g. 'Bronze I', 'Gold III'
  final int currentLevelIndex; // 1 to 20
  final int xp;
  final int lifetimeXP;
  final int loginStreak;
  final String? lastRewardDate; // YYYY-MM-DD
  final bool isProfileComplete;
  final bool isGuest;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const MultiplayerUser({
    required this.uid,
    required this.displayName,
    this.name = '',
    this.photoURL = '',
    this.email,
    this.dateOfBirth = '',
    this.country = 'India',
    this.accountStatus = 'ACTIVE',
    this.role = 'PLAYER',
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.totalScore = 0,
    this.highestScore = 0,
    this.coins = 0,
    this.lifetimeCoinsEarned = 0,
    this.lifetimeCoinsSpent = 0,
    this.currentTier = 'BRONZE',
    this.currentLevel = 'Bronze I',
    this.currentLevelIndex = 1,
    this.xp = 0,
    this.lifetimeXP = 0,
    this.loginStreak = 1,
    this.lastRewardDate,
    this.isProfileComplete = false,
    this.isGuest = false,
    this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role == 'ADMIN';
  bool get isBlocked => accountStatus == 'BLOCKED';
  bool get isSuspended => accountStatus == 'SUSPENDED';
  bool get isActive => accountStatus == 'ACTIVE';

  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  String get winRateFormatted => gamesPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : '—';

  MultiplayerUser copyWith({
    String? uid,
    String? displayName,
    String? name,
    String? photoURL,
    String? email,
    String? dateOfBirth,
    String? country,
    String? accountStatus,
    String? role,
    int? gamesPlayed,
    int? gamesWon,
    int? gamesLost,
    int? totalScore,
    int? highestScore,
    int? coins,
    int? lifetimeCoinsEarned,
    int? lifetimeCoinsSpent,
    String? currentTier,
    String? currentLevel,
    int? currentLevelIndex,
    int? xp,
    int? lifetimeXP,
    int? loginStreak,
    String? lastRewardDate,
    bool? isProfileComplete,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return MultiplayerUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      name: name ?? this.name,
      photoURL: photoURL ?? this.photoURL,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      accountStatus: accountStatus ?? this.accountStatus,
      role: role ?? this.role,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      totalScore: totalScore ?? this.totalScore,
      highestScore: highestScore ?? this.highestScore,
      coins: coins ?? this.coins,
      lifetimeCoinsEarned: lifetimeCoinsEarned ?? this.lifetimeCoinsEarned,
      lifetimeCoinsSpent: lifetimeCoinsSpent ?? this.lifetimeCoinsSpent,
      currentTier: currentTier ?? this.currentTier,
      currentLevel: currentLevel ?? this.currentLevel,
      currentLevelIndex: currentLevelIndex ?? this.currentLevelIndex,
      xp: xp ?? this.xp,
      lifetimeXP: lifetimeXP ?? this.lifetimeXP,
      loginStreak: loginStreak ?? this.loginStreak,
      lastRewardDate: lastRewardDate ?? this.lastRewardDate,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'name': name,
    'photoURL': photoURL,
    'email': email,
    'dateOfBirth': dateOfBirth,
    'country': country,
    'accountStatus': accountStatus,
    'role': role,
    'gamesPlayed': gamesPlayed,
    'gamesWon': gamesWon,
    'gamesLost': gamesLost,
    'totalScore': totalScore,
    'highestScore': highestScore,
    'coins': coins,
    'lifetimeCoinsEarned': lifetimeCoinsEarned,
    'lifetimeCoinsSpent': lifetimeCoinsSpent,
    'currentTier': currentTier,
    'currentLevel': currentLevel,
    'currentLevelIndex': currentLevelIndex,
    'xp': xp,
    'lifetimeXP': lifetimeXP,
    'loginStreak': loginStreak,
    'lastRewardDate': lastRewardDate,
    'isProfileComplete': isProfileComplete,
    'isGuest': isGuest,
    'createdAt': createdAt?.toIso8601String(),
    'lastLoginAt': lastLoginAt?.toIso8601String(),
  };

  factory MultiplayerUser.fromJson(Map<String, dynamic> json) {
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

    final stats = json['stats'] as Map<String, dynamic>? ?? {};

    return MultiplayerUser(
      uid: json['uid'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? 'Player',
      name: json['name'] ?? json['displayName'] ?? '',
      photoURL: json['photoURL'] ?? '',
      email: json['email'],
      dateOfBirth: json['dateOfBirth'] ?? '',
      country: json['country'] ?? 'India',
      accountStatus: json['accountStatus'] ?? 'ACTIVE',
      role: json['role'] ?? 'PLAYER',
      gamesPlayed: json['gamesPlayed'] ?? stats['gamesPlayed'] ?? 0,
      gamesWon: json['gamesWon'] ?? stats['gamesWon'] ?? 0,
      gamesLost: json['gamesLost'] ?? stats['gamesLost'] ?? 0,
      totalScore: json['totalScore'] ?? stats['totalScore'] ?? 0,
      highestScore: json['highestScore'] ?? stats['highestScore'] ?? 0,
      coins: json['coins'] ?? 0,
      lifetimeCoinsEarned: json['lifetimeCoinsEarned'] ?? json['coins'] ?? 0,
      lifetimeCoinsSpent: json['lifetimeCoinsSpent'] ?? 0,
      currentTier: json['currentTier'] ?? 'BRONZE',
      currentLevel: json['currentLevel'] ?? 'Bronze I',
      currentLevelIndex: json['currentLevelIndex'] ?? 1,
      xp: json['xp'] ?? 0,
      lifetimeXP: json['lifetimeXP'] ?? json['xp'] ?? 0,
      loginStreak: json['loginStreak'] ?? 1,
      lastRewardDate: json['lastRewardDate'],
      isProfileComplete: json['isProfileComplete'] ?? (json['email'] != null && !(json['isGuest'] ?? false)),
      isGuest: json['isGuest'] ?? false,
      createdAt: parseDate(json['createdAt']),
      lastLoginAt: parseDate(json['lastLoginAt']),
    );
  }
}
