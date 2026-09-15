import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "chat_screen.dart";

class ContactsScreen extends StatefulWidget {
  final LocaleController localeController;

  const ContactsScreen({super.key, required this.localeController});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

const Map<String, Color> _tagColors = {
  "prospect": Color(0xFF3B82F6),
  "vip": Color(0xFF6C5CE7),
  "order_in_progress": Color(0xFFF59E0B),
};

class _ContactsScreenState extends State<ContactsScreen> {
  bool loading = true;
  List<Map<String, dynamic>> contacts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listContacts();
    if (response.statusCode == 200) {
      contacts = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pickTag(Map<String, dynamic> contact) async {
    final t = widget.localeController.t;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.close_rounded, color: SyrixColors.textMuted),
              title: Text(t("contact_tag_none"), style: const TextStyle(color: SyrixColors.textPrimary)),
              onTap: () => Navigator.pop(context, ""),
            ),
            for (final entry in _tagColors.entries)
              ListTile(
                leading: CircleAvatar(radius: 8, backgroundColor: entry.value),
                title: Text(tagLabel(entry.key), style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ApiClient.renameContact(contact["id"], tag: selected.isEmpty ? null : selected);
    load();
  }

  String tagLabel(String key) {
    final t = widget.localeController.t;
    switch (key) {
      case "prospect":
        return t("contact_tag_prospect");
      case "vip":
        return t("contact_tag_vip");
      case "order_in_progress":
        return t("contact_tag_order");
      default:
        return key;
    }
  }

  Future<void> renameContact(Map<String, dynamic> contact) async {
    final t = widget.localeController.t;
    final controller = TextEditingController(text: contact["alias"] ?? "");
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("contact_rename_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SyrixColors.textPrimary),
          decoration: InputDecoration(hintText: t("contact_rename_hint")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t("contact_rename_save")),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ApiClient.renameContact(contact["id"], alias: result.isEmpty ? null : result);
    load();
  }

  Future<void> showAddContactDialog() async {
    final t = widget.localeController.t;
    final idController = TextEditingController();
    final aliasController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("contact_add_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              autofocus: true,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                labelText: "User ID / Username",
                labelStyle: const TextStyle(color: SyrixColors.textMuted),
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SyrixColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aliasController,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                labelText: t("contact_add_hint_alias"),
                labelStyle: const TextStyle(color: SyrixColors.textMuted),
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SyrixColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("contact_add_save")),
          ),
        ],
      ),
    );
    if (added == true && idController.text.trim().isNotEmpty) {
      final res = await ApiClient.addContact(
        idController.text.trim(),
        alias: aliasController.text.trim().isNotEmpty ? aliasController.text.trim() : null,
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("contacts_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: SyrixColors.primary),
            tooltip: t("contact_add_title"),
            onPressed: showAddContactDialog,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : contacts.isEmpty
              ? Center(child: Text(t("contacts_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final displayName = (contact["alias"] as String?)?.isNotEmpty == true
                        ? contact["alias"]
                        : contact["username"];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SyrixColors.surfaceAlt,
                        backgroundImage: contact["avatarUrl"] != null ? NetworkImage(contact["avatarUrl"]) : null,
                        child: contact["avatarUrl"] == null
                            ? Text((contact["username"] ?? "?")[0].toUpperCase(), style: const TextStyle(color: SyrixColors.textPrimary))
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(displayName ?? "", overflow: TextOverflow.ellipsis, style: const TextStyle(color: SyrixColors.textPrimary))),
                          if ((contact["tag"] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (_tagColors[contact["tag"]] ?? SyrixColors.textMuted).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tagLabel(contact["tag"]),
                                style: TextStyle(color: _tagColors[contact["tag"]] ?? SyrixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: (contact["alias"] as String?)?.isNotEmpty == true
                          ? Text("@${contact["username"]}", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.label_outline_rounded, color: SyrixColors.textMuted, size: 18),
                            onPressed: () => pickTag(contact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: SyrixColors.textMuted, size: 18),
                            onPressed: () => renameContact(contact),
                          ),
                        ],
                      ),
                      onTap: () async {
                        final response = await ApiClient.startPrivateChat(contact["id"]);
                        if (response.statusCode != 200 && response.statusCode != 201) return;
                        final body = jsonDecode(response.body);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              localeController: widget.localeController,
                              conversationId: body["id"].toString(),
                              title: displayName ?? "",
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
