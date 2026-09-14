import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class SessionsScreen extends StatefulWidget {
  final LocaleController localeController;

  const SessionsScreen({super.key, required this.localeController});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> sessions = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listSessions();
    if (response.statusCode == 200) {
      sessions = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> revoke(String sessionId) async {
    await ApiClient.revokeSession(sessionId);
    load();
  }

  Future<void> revokeAllOthers() async {
    await ApiClient.revokeOtherSessions();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("sessions_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                OutlinedButton(
                  onPressed: revokeAllOthers,
                  child: Text(t("sessions_revoke_others")),
                ),
                const SizedBox(height: 12),
                for (final session in sessions)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SyrixColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: session["current"] == true ? SyrixColors.primary : SyrixColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          session["deviceInfo"] == "iOS" ? Icons.phone_iphone_rounded : Icons.smartphone_rounded,
                          color: SyrixColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(session["deviceInfo"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                                  if (session["current"] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: SyrixColors.primary, borderRadius: BorderRadius.circular(6)),
                                      child: Text(t("sessions_current"), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(session["ipAddress"] ?? "", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (session["current"] != true)
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: SyrixColors.danger, size: 18),
                            onPressed: () => revoke(session["id"]),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
