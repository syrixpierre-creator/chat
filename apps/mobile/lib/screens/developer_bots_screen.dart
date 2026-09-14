import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class DeveloperBotsScreen extends StatefulWidget {
  final LocaleController localeController;

  const DeveloperBotsScreen({super.key, required this.localeController});

  @override
  State<DeveloperBotsScreen> createState() => _DeveloperBotsScreenState();
}

class _DeveloperBotsScreenState extends State<DeveloperBotsScreen> {
  List<Map<String, dynamic>> bots = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.listBots();
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      bots = List<Map<String, dynamic>>.from(body["bots"] ?? []);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> showTokenDialog(String token) async {
    final t = widget.localeController.t;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("developer_bots_token_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t("developer_bots_token_warning"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SyrixColors.border),
              ),
              child: SelectableText(token, style: const TextStyle(color: SyrixColors.primary, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t("developer_bots_token_copied"))),
              );
            },
            child: const Icon(Icons.copy_rounded, size: 18, color: SyrixColors.textMuted),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> createBot() async {
    final t = widget.localeController.t;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("developer_bots_create"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: SyrixColors.textPrimary),
          decoration: InputDecoration(hintText: t("developer_bots_name_hint")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t("developer_bots_create_action")),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final response = await ApiClient.createBot(name);
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body);
      await load();
      if (mounted) showTokenDialog(body["token"]);
    }
  }

  void openBotDetail(Map<String, dynamic> bot) {
    final t = widget.localeController.t;
    final webhookController = TextEditingController(text: bot["webhookUrl"] ?? "");
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bot["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text("@${bot["username"] ?? ""}", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Text(t("developer_bots_webhook"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: webhookController,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(hintText: t("developer_bots_webhook_hint")),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final response = await ApiClient.updateBotWebhook(
                      bot["id"],
                      webhookController.text.trim().isEmpty ? null : webhookController.text.trim(),
                    );
                    if (response.statusCode == 200 && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t("developer_bots_webhook_saved"))),
                      );
                      Navigator.pop(context);
                      load();
                    }
                  },
                  child: Text(t("developer_bots_save")),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.key_rounded, color: SyrixColors.textPrimary),
                title: Text(t("developer_bots_regenerate_token"), style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: SyrixColors.surface,
                      title: Text(t("developer_bots_regenerate_token"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      content: Text(t("developer_bots_regenerate_confirm"), style: const TextStyle(color: SyrixColors.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t("developer_bots_regenerate_token"))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final response = await ApiClient.regenerateBotToken(bot["id"]);
                    if (response.statusCode == 200 && context.mounted) {
                      final body = jsonDecode(response.body);
                      Navigator.pop(context);
                      showTokenDialog(body["token"]);
                    }
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: SyrixColors.danger),
                title: Text(t("developer_bots_delete"), style: const TextStyle(color: SyrixColors.danger)),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: SyrixColors.surface,
                      title: Text(t("developer_bots_delete"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      content: Text(t("developer_bots_delete_confirm"), style: const TextStyle(color: SyrixColors.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(t("developer_bots_delete"), style: const TextStyle(color: SyrixColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ApiClient.deleteBot(bot["id"]);
                    if (context.mounted) Navigator.pop(context);
                    load();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("developer_bots_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: createBot),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : bots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      t("developer_bots_empty"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SyrixColors.textMuted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: bots.length,
                  itemBuilder: (context, index) {
                    final bot = bots[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: SyrixColors.surfaceAlt,
                        child: Icon(Icons.smart_toy_rounded, color: SyrixColors.primary),
                      ),
                      title: Text(bot["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                      subtitle: Text(
                        "@${bot["username"] ?? ""} · ${bot["tokenPrefix"]}…",
                        style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                      onTap: () => openBotDetail(bot),
                    );
                  },
                ),
    );
  }
}
