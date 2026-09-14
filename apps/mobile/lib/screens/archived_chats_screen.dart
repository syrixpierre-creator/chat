import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class ArchivedChatsScreen extends StatefulWidget {
  final LocaleController localeController;

  const ArchivedChatsScreen({super.key, required this.localeController});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> archived = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listArchivedConversations();
    if (response.statusCode == 200) {
      archived = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> unarchive(String conversationId) async {
    await ApiClient.unarchiveConversation(conversationId);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("archived_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : archived.isEmpty
              ? Center(child: Text(t("archived_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: archived.length,
                  itemBuilder: (context, index) {
                    final conv = archived[index];
                    return ListTile(
                      leading: const Icon(Icons.archive_rounded, color: SyrixColors.textMuted),
                      title: Text(conv["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                      trailing: TextButton(
                        onPressed: () => unarchive(conv["id"].toString()),
                        child: Text(t("archived_unarchive")),
                      ),
                    );
                  },
                ),
    );
  }
}
