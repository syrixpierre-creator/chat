import "dart:convert";
import "package:crypto/crypto.dart";
import "package:shared_preferences/shared_preferences.dart";

class VaultService {
  static const _hashKey = "syrix_vault_pin_hash";
  static const _itemsKey = "syrix_vault_items";
  static const _salt = "syrix_chat_vault_salt_v1";

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

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.remove(_itemsKey);
  }

  static Future<List<Map<String, dynamic>>> listItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_itemsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> addItem(Map<String, dynamic> item) async {
    final items = await listItems();
    items.add(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(items));
  }

  static Future<void> removeItem(String mediaUrl) async {
    final items = await listItems();
    items.removeWhere((i) => i["mediaUrl"] == mediaUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_itemsKey, jsonEncode(items));
  }
}
