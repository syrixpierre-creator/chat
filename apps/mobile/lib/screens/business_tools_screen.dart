import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class BusinessToolsScreen extends StatefulWidget {
  final LocaleController localeController;

  const BusinessToolsScreen({super.key, required this.localeController});

  @override
  State<BusinessToolsScreen> createState() => _BusinessToolsScreenState();
}

class _BusinessToolsScreenState extends State<BusinessToolsScreen> {
  bool loading = true;
  bool awayEnabled = false;
  final awayController = TextEditingController();
  List<Map<String, String>> quickReplies = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.getBusinessTools();
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      awayEnabled = body["awayEnabled"] == true;
      awayController.text = body["awayMessage"] ?? "";
      quickReplies = List<Map<String, dynamic>>.from(body["quickReplies"] ?? [])
          .map((q) => {"shortcut": "${q["shortcut"]}", "text": "${q["text"]}"})
          .toList();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveAway() async {
    await ApiClient.updateBusinessTools(awayEnabled: awayEnabled, awayMessage: awayController.text.trim());
  }

  Future<void> saveQuickReplies() async {
    await ApiClient.updateBusinessTools(quickReplies: quickReplies);
  }

  Future<void> addQuickReply() async {
    final t = widget.localeController.t;
    final shortcutController = TextEditingController();
    final textController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("business_quick_reply_new"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: shortcutController,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(hintText: t("business_shortcut_hint")),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(hintText: t("business_text_hint")),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t("contact_rename_save"))),
        ],
      ),
    );
    if (result != true) return;
    final shortcut = shortcutController.text.trim().replaceAll("/", "");
    final text = textController.text.trim();
    if (shortcut.isEmpty || text.isEmpty) return;
    setState(() => quickReplies.add({"shortcut": shortcut, "text": text}));
    saveQuickReplies();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    if (loading) {
      return const Scaffold(
        backgroundColor: SyrixColors.background,
        body: Center(child: CircularProgressIndicator(color: SyrixColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("business_tools_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: SyrixColors.primary,
            title: Text(t("business_away_enable"), style: const TextStyle(color: SyrixColors.textPrimary)),
            value: awayEnabled,
            onChanged: (v) {
              setState(() => awayEnabled = v);
              saveAway();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: awayController,
            maxLines: 3,
            enabled: awayEnabled,
            onSubmitted: (_) => saveAway(),
            onEditingComplete: saveAway,
            style: const TextStyle(color: SyrixColors.textPrimary),
            decoration: InputDecoration(
              hintText: t("business_away_hint"),
              filled: true,
              fillColor: SyrixColors.surfaceAlt,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t("business_quick_replies"), style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(icon: const Icon(Icons.add_rounded, color: SyrixColors.primary), onPressed: addQuickReply),
            ],
          ),
          for (final reply in quickReplies)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bolt_rounded, color: SyrixColors.primary),
              title: Text("/${reply["shortcut"]}", style: const TextStyle(color: SyrixColors.textPrimary)),
              subtitle: Text(reply["text"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SyrixColors.textMuted)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: SyrixColors.danger),
                onPressed: () {
                  setState(() => quickReplies.remove(reply));
                  saveQuickReplies();
                },
              ),
            ),
        ],
      ),
    );
  }
}
