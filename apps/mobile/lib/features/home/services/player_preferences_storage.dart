import 'player_preferences_stub.dart'
    if (dart.library.html) 'player_preferences_web.dart';

abstract class PreferencesStorage {
  String? getString(String key);
  void setString(String key, String value);
  int? getInt(String key);
  void setInt(String key, int value);
  bool? getBool(String key);
  void setBool(String key, bool value);
}

PreferencesStorage createPreferencesStorage() => getPreferencesStorage();
