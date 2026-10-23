import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/player_preferences_service.dart';
import '../../auth/providers/auth_provider.dart';

class HomeState {
  final AILevel selectedDifficulty;
  final int coins;
  final bool soundEnabled;
  final bool dailyBonusClaimed;
  final int dailyChallengeProgress;
  final bool dailyChallengeClaimed;
  final int gamesPlayed;
  final int gamesWon;
  final int playerLevel;
  final int playerXP;
  final int activeBottomNavIndex;
  final String selectedJokerMode; // 'OPEN' or 'CLOSED'

  const HomeState({
    this.selectedDifficulty = AILevel.intermediate,
    this.coins = 0,
    this.soundEnabled = true,
    this.dailyBonusClaimed = false,
    this.dailyChallengeProgress = 0,
    this.dailyChallengeClaimed = false,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.playerLevel = 1,
    this.playerXP = 0,
    this.activeBottomNavIndex = 0,
    this.selectedJokerMode = 'OPEN',
  });

  HomeState copyWith({
    AILevel? selectedDifficulty,
    int? coins,
    bool? soundEnabled,
    bool? dailyBonusClaimed,
    int? dailyChallengeProgress,
    bool? dailyChallengeClaimed,
    int? gamesPlayed,
    int? gamesWon,
    int? playerLevel,
    int? playerXP,
    int? activeBottomNavIndex,
    String? selectedJokerMode,
  }) {
    return HomeState(
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
      coins: coins ?? this.coins,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      dailyBonusClaimed: dailyBonusClaimed ?? this.dailyBonusClaimed,
      dailyChallengeProgress: dailyChallengeProgress ?? this.dailyChallengeProgress,
      dailyChallengeClaimed: dailyChallengeClaimed ?? this.dailyChallengeClaimed,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      playerLevel: playerLevel ?? this.playerLevel,
      playerXP: playerXP ?? this.playerXP,
      activeBottomNavIndex: activeBottomNavIndex ?? this.activeBottomNavIndex,
      selectedJokerMode: selectedJokerMode ?? this.selectedJokerMode,
    );
  }

  double get winRate => gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0.0;
  String get winRateFormatted => gamesPlayed > 0 ? '${winRate.toStringAsFixed(1)}%' : '—';
}

class HomeNotifier extends StateNotifier<HomeState> {
  final Ref _ref;
  final PlayerPreferencesService _prefs = PlayerPreferencesService();

  HomeNotifier(this._ref) : super(const HomeState()) {
    _loadInitial();
    _ref.listen(authProvider, (previous, next) {
      if (next != null) {
        state = state.copyWith(
          coins: next.coins,
          gamesPlayed: next.gamesPlayed,
          gamesWon: next.gamesWon,
          playerLevel: next.currentLevelIndex,
          playerXP: next.xp,
        );
      }
    });
  }

  void _loadInitial() {
    final user = _ref.read(authProvider);
    if (user != null) {
      state = state.copyWith(
        selectedDifficulty: _prefs.getDifficulty(),
        coins: user.coins,
        soundEnabled: _prefs.isSoundEnabled(),
        dailyBonusClaimed: _prefs.isDailyBonusClaimedToday(),
        dailyChallengeProgress: _prefs.getDailyChallengeProgress(),
        dailyChallengeClaimed: _prefs.isDailyChallengeClaimed(),
        gamesPlayed: user.gamesPlayed,
        gamesWon: user.gamesWon,
        playerLevel: user.currentLevelIndex,
        playerXP: user.xp,
      );
    } else {
      state = state.copyWith(
        selectedDifficulty: _prefs.getDifficulty(),
        coins: _prefs.getCoins(),
        soundEnabled: _prefs.isSoundEnabled(),
        dailyBonusClaimed: _prefs.isDailyBonusClaimedToday(),
        dailyChallengeProgress: _prefs.getDailyChallengeProgress(),
        dailyChallengeClaimed: _prefs.isDailyChallengeClaimed(),
        gamesPlayed: _prefs.getGamesPlayed(),
        gamesWon: _prefs.getGamesWon(),
        playerLevel: _prefs.getPlayerLevel(),
        playerXP: _prefs.getPlayerXP(),
      );
    }
  }

  void setDifficulty(AILevel level) {
    _prefs.setDifficulty(level);
    state = state.copyWith(selectedDifficulty: level);
  }

  void toggleSound() {
    final next = !state.soundEnabled;
    _prefs.setSoundEnabled(next);
    state = state.copyWith(soundEnabled: next);
  }

  void claimDailyBonus() {
    if (state.dailyBonusClaimed) return;
    _prefs.claimDailyBonus();
    state = state.copyWith(
      coins: _prefs.getCoins(),
      dailyBonusClaimed: true,
    );
  }

  void claimDailyChallenge() {
    if (state.dailyChallengeClaimed || state.dailyChallengeProgress < 2) return;
    _prefs.claimDailyChallenge();
    state = state.copyWith(
      coins: _prefs.getCoins(),
      dailyChallengeClaimed: true,
    );
  }

  void setJokerMode(String mode) {
    state = state.copyWith(selectedJokerMode: mode);
  }

  void setBottomNavIndex(int index) {
    state = state.copyWith(activeBottomNavIndex: index);
  }

  void refreshStats() {
    _loadInitial();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});
