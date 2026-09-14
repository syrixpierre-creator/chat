import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class NotesScreen extends StatefulWidget {
  final LocaleController localeController;

  const NotesScreen({super.key, required this.localeController});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.listNotes();
    if (response.statusCode == 200) {
      notes = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> openEditor({Map<String, dynamic>? note}) async {
    final t = widget.localeController.t;
    final controller = TextEditingController(text: note?["content"] ?? "");
    await showModalBottomSheet(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 6,
                minLines: 3,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(
                  hintText: note == null ? t("notes_new_hint") : t("notes_edit_hint"),
                  hintStyle: const TextStyle(color: SyrixColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final content = controller.text.trim();
                  if (content.isEmpty) return;
                  if (note == null) {
                    await ApiClient.createNote(content);
                  } else {
                    await ApiClient.updateNote(note["_id"], content);
                  }
                  if (context.mounted) Navigator.pop(context);
                  load();
                },
                child: Text(t("notes_save")),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> confirmDelete(Map<String, dynamic> note) async {
    final t = widget.localeController.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("notes_delete_confirm"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("notes_delete_action"), style: const TextStyle(color: SyrixColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiClient.deleteNote(note["_id"]);
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("notes_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => openEditor()),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : notes.isEmpty
              ? Center(child: Text(t("notes_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: ListTile(
                        title: Text(
                          note["content"] ?? "",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SyrixColors.textPrimary),
                        ),
                        onTap: () => openEditor(note: note),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: SyrixColors.textMuted, size: 20),
                          onPressed: () => confirmDelete(note),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
