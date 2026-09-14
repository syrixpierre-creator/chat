import "dart:convert";
import "package:shared_preferences/shared_preferences.dart";

class AccountService {
  static const _accountsKey = "syrix_accounts";

  static Future<List<Map<String, dynamic>>> listAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> _saveAll(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  static Future<void> saveActiveAccount({
    required String id,
    required String username,
    String? avatarUrl,
    required String token,
  }) async {
    final accounts = await listAccounts();
    accounts.removeWhere((a) => a["id"] == id);
    accounts.add({
      "id": id,
      "username": username,
      "avatarUrl": avatarUrl,
      "token": token,
    });
    await _saveAll(accounts);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("syrix_token", token);
    await prefs.setString("syrix_active_account_id", id);
  }

  static Future<void> updateActiveUsername(String username) async {
    final id = await activeAccountId();
    if (id == null) return;
    final accounts = await listAccounts();
    final index = accounts.indexWhere((a) => a["id"] == id);
    if (index == -1) return;
    accounts[index]["username"] = username;
    await _saveAll(accounts);
  }

  static Future<String?> activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("syrix_active_account_id");
  }

  static Future<bool> switchTo(String id) async {
    final accounts = await listAccounts();
    final match = accounts.where((a) => a["id"] == id).toList();
    if (match.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("syrix_token", match.first["token"]);
    await prefs.setString("syrix_active_account_id", id);
    return true;
  }

  static Future<void> removeAccount(String id) async {
    final accounts = await listAccounts();
    accounts.removeWhere((a) => a["id"] == id);
    await _saveAll(accounts);
    final activeId = await activeAccountId();
    if (activeId == id) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("syrix_token");
      await prefs.remove("syrix_active_account_id");
    }
  }
}
