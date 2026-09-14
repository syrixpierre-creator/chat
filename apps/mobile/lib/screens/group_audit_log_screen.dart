import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class GroupAuditLogScreen extends StatefulWidget {
  final LocaleController localeController;
  final String conversationId;

  const GroupAuditLogScreen({
    super.key,
    required this.localeController,
    required this.conversationId,
  });

  @override
  State<GroupAuditLogScreen> createState() => _GroupAuditLogScreenState();
}

class _GroupAuditLogScreenState extends State<GroupAuditLogScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.getAuditLog(widget.conversationId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      items = List<Map<String, dynamic>>.from(body["items"] ?? []);
    }
    if (mounted) setState(() => loading = false);
  }

  IconData iconFor(String action) {
    switch (action) {
      case "promote":
        return Icons.admin_panel_settings_rounded;
      case "demote":
        return Icons.remove_moderator_rounded;
      case "kick":
        return Icons.person_remove_rounded;
      case "ban":
        return Icons.block_rounded;
      case "transfer_ownership":
        return Icons.workspace_premium_rounded;
      case "closed_group_on":
      case "closed_group_off":
        return Icons.lock_outline_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  String labelFor(Map<String, dynamic> item) {
    final t = widget.localeController.t;
    final action = item["action"] as String;
    return t("group_audit_$action")
        .replaceAll("{actor}", item["actorUsername"] ?? "")
        .replaceAll("{target}", item["targetUsername"] ?? "");
  }

  String timeAgo(String? iso) {
    if (iso == null) return "";
    final date = DateTime.tryParse(iso);
    if (date == null) return "";
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("group_audit_log_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : items.isEmpty
              ? Center(
                  child: Text(t("group_audit_log_empty"), style: const TextStyle(color: SyrixColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      leading: Icon(iconFor(item["action"]), color: SyrixColors.textMuted),
                      title: Text(labelFor(item), style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 14)),
                      trailing: Text(
                        timeAgo(item["createdAt"]),
                        style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                      ),
                    );
                  },
                ),
    );
  }
}
