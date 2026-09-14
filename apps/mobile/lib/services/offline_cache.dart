import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class OfflineCache {
  static Future<void> saveJson(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("cache_$key", jsonEncode(data));
  }

  static Future<dynamic> loadJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("cache_$key");
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
