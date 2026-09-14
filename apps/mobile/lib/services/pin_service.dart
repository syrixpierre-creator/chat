import "dart:convert";
import "package:crypto/crypto.dart";
import "package:shared_preferences/shared_preferences.dart";

class PinService {
  static const _hashKey = "syrix_pin_hash";
  static const _salt = "syrix_chat_local_salt_v1";

  static String _hash(String pin) {
    return sha256.convert(utf8.encode("$_salt:$pin")).toString();
  }

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hashKey) != null;
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hashKey, _hash(pin));
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  static Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
  }
}
