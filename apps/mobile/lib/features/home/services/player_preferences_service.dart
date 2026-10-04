import 'package:ai_engine/ai_engine.dart';
import 'player_preferences_storage.dart';

class PlayerPreferencesService {
  static final PlayerPreferencesService _instance = PlayerPreferencesService._internal();
  factory PlayerPreferencesService() => _instance;
  PlayerPreferencesService._internal();

  final PreferencesStorage _storage = createPreferencesStorage();

  static const String _keyDifficulty = 'maya_rummy_difficulty';
  static const String _keyCoins = 'maya_rummy_coins';
  static const String _keySound = 'maya_rummy_sound';
  static const String _keyDailyClaimedDate = 'maya_rummy_daily_bonus_date';
  static const String _keyDailyChallengeCount = 'maya_rummy_daily_challenge_count';
  static const String _keyDailyChallengeClaimed = 'maya_rummy_daily_challenge_claimed';
  static const String _keyGamesPlayed = 'maya_rummy_games_played';
  static const String _keyGamesWon = 'maya_rummy_games_won';
  static const String _keyLevel = 'maya_rummy_player_level';
  static const String _keyXP = 'maya_rummy_player_xp';

  AILevel getDifficulty() {
    final val = _storage.getString(_keyDifficulty);
    switch (val) {
      case 'easy':
      case 'beginner':
        return AILevel.beginner;
      case 'hard':
      case 'advanced':
        return AILevel.advanced;
      case 'medium':
      case 'intermediate':
      default:
        return AILevel.intermediate;
    }
  }

  void setDifficulty(AILevel level) {
    String str;
    switch (level) {
      case AILevel.beginner:
        str = 'easy';
        break;
      case AILevel.advanced:
      case AILevel.expert:
        str = 'hard';
        break;
      case AILevel.intermediate:
        str = 'medium';
        break;
    }
    _storage.setString(_keyDifficulty, str);
  }

  int getCoins() {
    return _storage.getInt(_keyCoins) ?? 0;
  }

  void setCoins(int coins) {
    _storage.setInt(_keyCoins, coins);
  }

  void addCoins(int delta) {
    final current = getCoins();
    setCoins(current + delta);
  }

  bool isSoundEnabled() {
    return _storage.getBool(_keySound) ?? true;
  }

  void setSoundEnabled(bool enabled) {
    _storage.setBool(_keySound, enabled);
  }

  bool isDailyBonusClaimedToday() {
    final lastDate = _storage.getString(_keyDailyClaimedDate);
    if (lastDate == null) return false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastDate == today;
  }

  void claimDailyBonus() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _storage.setString(_keyDailyClaimedDate, today);
    addCoins(100);
  }

  int getDailyChallengeProgress() {
    return _storage.getInt(_keyDailyChallengeCount) ?? 0;
  }

  void incrementDailyChallengeProgress() {
    final current = getDailyChallengeProgress();
    if (current < 2) {
      _storage.setInt(_keyDailyChallengeCount, current + 1);
    }
  }

  bool isDailyChallengeClaimed() {
    return _storage.getBool(_keyDailyChallengeClaimed) ?? false;
  }

  void claimDailyChallenge() {
    _storage.setBool(_keyDailyChallengeClaimed, true);
    addCoins(250);
  }

  int getGamesPlayed() => _storage.getInt(_keyGamesPlayed) ?? 0;
  int getGamesWon() => _storage.getInt(_keyGamesWon) ?? 0;
  int getPlayerLevel() => _storage.getInt(_keyLevel) ?? 1;
  int getPlayerXP() => _storage.getInt(_keyXP) ?? 0;

  void recordGameResult({required bool won}) {
    final played = getGamesPlayed() + 1;
    final wonCount = won ? getGamesWon() + 1 : getGamesWon();
    _storage.setInt(_keyGamesPlayed, played);
    _storage.setInt(_keyGamesWon, wonCount);
    if (won) {
      incrementDailyChallengeProgress();
      addCoins(100);
      final xp = getPlayerXP() + 75;
      _storage.setInt(_keyXP, xp);
    } else {
      final xp = getPlayerXP() + 25;
      _storage.setInt(_keyXP, xp);
    }
  }
}
