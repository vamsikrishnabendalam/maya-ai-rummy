import 'player_preferences_storage.dart';

class InMemoryPreferencesStorage implements PreferencesStorage {
  final Map<String, String> _data = {};

  @override
  String? getString(String key) => _data[key];

  @override
  void setString(String key, String value) {
    _data[key] = value;
  }

  @override
  int? getInt(String key) {
    final val = _data[key];
    return val != null ? int.tryParse(val) : null;
  }

  @override
  void setInt(String key, int value) {
    _data[key] = value.toString();
  }

  @override
  bool? getBool(String key) {
    final val = _data[key];
    if (val == null) return null;
    return val.toLowerCase() == 'true';
  }

  @override
  void setBool(String key, bool value) {
    _data[key] = value.toString();
  }
}

PreferencesStorage getPreferencesStorage() => InMemoryPreferencesStorage();
