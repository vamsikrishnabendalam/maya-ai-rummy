// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'player_preferences_storage.dart';

class WebPreferencesStorage implements PreferencesStorage {
  @override
  String? getString(String key) => html.window.localStorage[key];

  @override
  void setString(String key, String value) {
    html.window.localStorage[key] = value;
  }

  @override
  int? getInt(String key) {
    final val = html.window.localStorage[key];
    return val != null ? int.tryParse(val) : null;
  }

  @override
  void setInt(String key, int value) {
    html.window.localStorage[key] = value.toString();
  }

  @override
  bool? getBool(String key) {
    final val = html.window.localStorage[key];
    if (val == null) return null;
    return val.toLowerCase() == 'true';
  }

  @override
  void setBool(String key, bool value) {
    html.window.localStorage[key] = value.toString();
  }
}

PreferencesStorage getPreferencesStorage() => WebPreferencesStorage();
