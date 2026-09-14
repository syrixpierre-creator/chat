import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../widgets/verified_badge.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class GroupMembersScreen extends StatefulWidget {
  final LocaleController localeController;
  final String conversationId;
  final bool isAdmin;
  final bool isOwner;
  final String currentUserId;

  const GroupMembersScreen({
    super.key,
    required this.localeController,
    required this.conversationId,
    required this.isAdmin,
    required this.isOwner,
    required this.currentUserId,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<Map<String, dynamic>> members = [];
  bool loading = true;
  bool ownershipTransferred = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.listMembers(widget.conversationId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      members = List<Map<String, dynamic>>.from(body["members"] ?? []);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> confirmTransferOwnership(Map<String, dynamic> member) async {
    final t = widget.localeController.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("group_members_transfer_confirm_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Text(
          t("group_members_transfer_confirm_body").replaceAll("{name}", member["username"] ?? ""),
          style: const TextStyle(color: SyrixColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("group_members_transfer_confirm_action"), style: const TextStyle(color: SyrixColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final response = await ApiClient.transferOwnership(widget.conversationId, member["id"]);
      if (response.statusCode == 200) {
        ownershipTransferred = true;
        load();
      }
    }
  }

  void openMemberActions(Map<String, dynamic> member) {
    final t = widget.localeController.t;
    final isSelf = member["id"] == widget.currentUserId;
    final isOwner = member["role"] == "owner";
    if (!widget.isAdmin || isSelf || isOwner) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (member["role"] == "admin")
                ListTile(
                  leading: const Icon(Icons.remove_moderator_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("group_members_demote"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ApiClient.demoteMember(widget.conversationId, member["id"]);
                    load();
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("group_members_promote"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ApiClient.promoteMember(widget.conversationId, member["id"]);
                    load();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: SyrixColors.danger),
                title: Text(t("group_members_kick"), style: const TextStyle(color: SyrixColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  await ApiClient.kickMember(widget.conversationId, member["id"]);
                  load();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: SyrixColors.danger),
                title: Text(t("group_members_ban"), style: const TextStyle(color: SyrixColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  await ApiClient.banMember(widget.conversationId, member["id"]);
                  load();
                },
              ),
              if (widget.isOwner) ...[
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded, color: SyrixColors.primary),
                  title: Text(t("group_members_transfer_ownership"), style: const TextStyle(color: SyrixColors.primary)),
                  onTap: () {
                    Navigator.pop(context);
                    confirmTransferOwnership(member);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String roleLabel(String role) {
    final t = widget.localeController.t;
    switch (role) {
      case "owner":
        return t("group_members_role_owner");
      case "admin":
        return t("group_members_role_admin");
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).pop(ownershipTransferred);
      },
      child: Scaffold(
        backgroundColor: SyrixColors.background,
        appBar: AppBar(
          backgroundColor: SyrixColors.surface,
          iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
          title: Text(t("group_members_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final role = member["role"] as String;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: SyrixColors.surfaceAlt,
                      backgroundImage: member["avatarUrl"] != null ? NetworkImage(member["avatarUrl"]) : null,
                      child: member["avatarUrl"] == null
                          ? Text(
                              (member["username"] ?? "").isNotEmpty ? member["username"][0].toUpperCase() : "?",
                              style: const TextStyle(color: SyrixColors.textPrimary),
                            )
                          : null,
                    ),
                    title: UsernameWithBadge(
                      username: member["username"] ?? "",
                      isPremium: member["isPremium"] == true,
                      style: const TextStyle(color: SyrixColors.textPrimary),
                    ),
                    subtitle: Row(
                      children: [
                        if (role != "member") ...[
                          Text(roleLabel(role), style: const TextStyle(color: SyrixColors.primary, fontSize: 12)),
                          const SizedBox(width: 6),
                          const Text("·", style: TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          widget.localeController.t("group_leaderboard_level").replaceAll("{level}", "${member["level"] ?? 1}"),
                          style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    onTap: () => openMemberActions(member),
                  );
                },
              ),
      ),
    );
  }
}
