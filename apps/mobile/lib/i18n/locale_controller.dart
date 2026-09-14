import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "strings.dart";

class LocaleController extends ChangeNotifier {
  String _locale = "en";

  String get locale => _locale;

  String t(String key) {
    return SyrixStrings.values[_locale]?[key] ?? key;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString("syrix_locale") ?? "en";
    notifyListeners();
  }

  Future<void> setLocale(String next) async {
    _locale = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("syrix_locale", next);
    notifyListeners();
  }
}
