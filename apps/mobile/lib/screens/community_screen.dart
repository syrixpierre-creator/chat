import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/create_sheet.dart";
import "chat_screen.dart";

class CommunityScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final LocaleController localeController;

  const CommunityScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.localeController,
  });

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  bool loading = true;
  List<Map<String, dynamic>> groups = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listCommunityGroups(widget.communityId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      groups = List<Map<String, dynamic>>.from(body["groups"] ?? []);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(widget.communityName, style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateSheet(
          context,
          widget.localeController,
          load,
          communityId: widget.communityId,
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : groups.isEmpty
              ? Center(
                  child: Text(t("community_no_groups"), style: const TextStyle(color: SyrixColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: SyrixColors.surfaceAlt,
                        child: Icon(Icons.groups_rounded, color: SyrixColors.primary),
                      ),
                      title: Text(group["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                      subtitle: Text(
                        "${group["memberCount"] ?? 0} ${t("community_members")}",
                        style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: group["id"].toString(),
                              title: group["name"] ?? "",
                              localeController: widget.localeController,
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
