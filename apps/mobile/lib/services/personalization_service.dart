import "package:shared_preferences/shared_preferences.dart";

class PersonalizationService {
  static const _batterySaverKey = "syrix_battery_saver";
  static bool _cachedBatterySaver = false;

  static bool get batterySaverEnabled => _cachedBatterySaver;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedBatterySaver = prefs.getBool(_batterySaverKey) ?? false;
  }

  static Future<void> setBatterySaver(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batterySaverKey, enabled);
    _cachedBatterySaver = enabled;
  }
}
