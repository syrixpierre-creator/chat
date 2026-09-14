import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class NotificationsScreen extends StatefulWidget {
  final LocaleController localeController;

  const NotificationsScreen({super.key, required this.localeController});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listNotifications();
    if (response.statusCode == 200) {
      notifications = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  IconData iconFor(String type) {
    switch (type) {
      case "mention":
        return Icons.alternate_email_rounded;
      case "contact_added":
        return Icons.person_add_alt_rounded;
      case "reaction":
        return Icons.favorite_rounded;
      case "gift":
        return Icons.card_giftcard_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String textFor(Map<String, dynamic> n) {
    final t = widget.localeController.t;
    switch (n["type"]) {
      case "mention":
        return t("notif_mention");
      case "contact_added":
        return t("notif_contact_added");
      default:
        return n["text"] ?? "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("nav_notifications"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiClient.markAllNotificationsRead();
              load();
            },
            child: Text(t("notif_mark_all_read")),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : notifications.isEmpty
              ? Center(child: Text(t("notif_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SyrixColors.surfaceAlt,
                        child: Icon(iconFor(n["type"] ?? ""), color: SyrixColors.primary, size: 18),
                      ),
                      title: Text(
                        textFor(n),
                        style: TextStyle(
                          color: SyrixColors.textPrimary,
                          fontWeight: n["read"] == true ? FontWeight.normal : FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
