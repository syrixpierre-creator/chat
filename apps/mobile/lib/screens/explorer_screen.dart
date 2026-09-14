import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../utils/invite_code.dart";
import "chat_screen.dart";
import "qr_scanner_screen.dart";
import "user_profile_screen.dart";

class ExplorerScreen extends StatefulWidget {
  final LocaleController localeController;

  const ExplorerScreen({super.key, required this.localeController});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final linkController = TextEditingController();
  String? error;
  bool joining = false;
  List<Map<String, dynamic>> nearbyUsers = [];
  bool loadingNearby = true;

  @override
  void initState() {
    super.initState();
    loadNearby();
  }

  Future<void> loadNearby() async {
    final response = await ApiClient.getNearbySuggestions();
    if (response.statusCode == 200) {
      nearbyUsers = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loadingNearby = false);
  }

  Future<void> join() async {
    await joinWithCode(extractInviteCode(linkController.text));
  }

  Future<void> joinWithCode(String code) async {
    if (code.isEmpty) return;
    setState(() {
      joining = true;
      error = null;
    });
    try {
      final response = await ApiClient.joinByInviteCode(code);
      if (response.statusCode != 200) {
        setState(() => error = widget.localeController.t("join_group_error"));
        return;
      }
      final body = jsonDecode(response.body);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            localeController: widget.localeController,
            conversationId: body["id"].toString(),
            title: body["name"] ?? "",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  Future<void> openScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QrScannerScreen(localeController: widget.localeController)),
    );
    if (scanned == null || scanned.isEmpty) return;
    if (isProfileQrCode(scanned)) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            localeController: widget.localeController,
            userId: extractUserIdFromProfileQr(scanned),
          ),
        ),
      );
      return;
    }
    await joinWithCode(extractInviteCode(scanned));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t("join_group_title"),
              style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SyrixColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: linkController,
                    style: const TextStyle(color: SyrixColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: t("join_group_hint"),
                      hintStyle: const TextStyle(color: SyrixColors.textMuted),
                      filled: true,
                      fillColor: SyrixColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: SyrixColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: joining ? null : join,
                  child: Text(t("join_group_action")),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: openScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(t("qr_scan_action")),
            ),
            if (!loadingNearby && nearbyUsers.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                t("explorer_nearby_title"),
                style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...nearbyUsers.map(
                (user) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: SyrixColors.surfaceAlt,
                    backgroundImage: user["avatarUrl"] != null ? NetworkImage(user["avatarUrl"]) : null,
                    child: user["avatarUrl"] == null
                        ? Text((user["username"] ?? "?")[0].toUpperCase(), style: const TextStyle(color: SyrixColors.textPrimary))
                        : null,
                  ),
                  title: Text(user["username"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                  subtitle: Text(user["location"] ?? "", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                  trailing: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            localeController: widget.localeController,
                            userId: user["id"],
                          ),
                        ),
                      );
                    },
                    child: Text(t("explorer_view_profile")),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
