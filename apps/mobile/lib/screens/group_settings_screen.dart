import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:qr_flutter/qr_flutter.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "group_members_screen.dart";
import "group_audit_log_screen.dart";
import "group_leaderboard_screen.dart";

class GroupSettingsScreen extends StatefulWidget {
  final LocaleController localeController;
  final String conversationId;
  final String type;

  const GroupSettingsScreen({
    super.key,
    required this.localeController,
    required this.conversationId,
    required this.type,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isPrivate = true;
  bool isCreator = false;
  String? inviteCode;
  int memberCount = 0;
  bool loading = true;
  bool saving = false;
  bool aiModerationEnabled = false;
  bool closedGroup = false;
  bool isAdmin = false;
  String currentUserId = "";
  bool editingName = false;
  bool editingDescription = false;
  String? avatarUrl;
  File? pickedPhoto;
  List<Map<String, dynamic>> members = [];

  // WhatsApp-style permissions
  String whoCanEditInfo = "everyone";
  String whoCanSendMessages = "everyone";
  String whoCanAddMembers = "everyone";
  String whoCanAddGroups = "admins";
  bool approveNewMembers = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.getConversationDetails(widget.conversationId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      nameController.text = body["name"] ?? "";
      avatarUrl = body["avatarUrl"];
      descriptionController.text = body["description"] ?? "";
      isPrivate = body["isPrivate"] ?? true;
      isCreator = body["isCreator"] ?? false;
      inviteCode = body["inviteCode"];
      memberCount = body["memberCount"] ?? 0;
      priceController.text = "${body["messagePrice"] ?? 0}";
      aiModerationEnabled = body["aiModerationEnabled"] ?? false;
      closedGroup = body["closedGroup"] ?? false;
      isAdmin = body["isAdmin"] ?? false;
      whoCanEditInfo = body["whoCanEditInfo"] ?? "everyone";
      whoCanSendMessages = body["whoCanSendMessages"] ?? (closedGroup ? "admins" : "everyone");
      whoCanAddMembers = body["whoCanAddMembers"] ?? "everyone";
      whoCanAddGroups = body["whoCanAddGroups"] ?? "admins";
      approveNewMembers = body["approveNewMembers"] ?? false;
    }
    final meResponse = await ApiClient.me();
    if (meResponse.statusCode == 200) {
      currentUserId = "${jsonDecode(meResponse.body)["id"]}";
    }

    final membersRes = await ApiClient.listMembers(widget.conversationId);
    if (membersRes.statusCode == 200) {
      final mBody = jsonDecode(membersRes.body);
      members = List<Map<String, dynamic>>.from(mBody["members"] ?? []);
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> saveSettings() async {
    setState(() => saving = true);
    try {
      if (pickedPhoto != null) {
        final uploadResponse = await ApiClient.uploadGroupPhoto(widget.conversationId, pickedPhoto!.path);
        final body = jsonDecode(await uploadResponse.stream.bytesToString());
        if (uploadResponse.statusCode == 201) {
          avatarUrl = body["avatarUrl"];
          pickedPhoto = null;
        }
      }
      await ApiClient.updateConversationSettings(
        widget.conversationId,
        name: nameController.text.trim(),
        isPrivate: isPrivate,
        messagePrice: int.tryParse(priceController.text.trim()) ?? 0,
        description: descriptionController.text.trim(),
        whoCanEditInfo: whoCanEditInfo,
        whoCanSendMessages: whoCanSendMessages,
        whoCanAddMembers: whoCanAddMembers,
        whoCanAddGroups: whoCanAddGroups,
        approveNewMembers: approveNewMembers,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paramètres enregistrés")),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickPhoto() async {
    if (!isAdmin && whoCanEditInfo == "admins") return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (result == null) return;
    setState(() => pickedPhoto = File(result.path));
    await saveSettings();
  }

  Future<void> confirmDeleteGroup() async {
    final t = widget.localeController.t;
    final isComm = widget.type == "community";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(
          isComm ? t("community_delete_action") : t("group_delete_action"),
          style: const TextStyle(color: SyrixColors.danger),
        ),
        content: Text(
          isComm ? t("community_delete_confirm") : t("group_delete_confirm"),
          style: const TextStyle(color: SyrixColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isComm ? t("community_delete_action") : t("group_delete_action")),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final res = await ApiClient.deleteConversation(widget.conversationId);
      if (res.statusCode == 200 && mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> confirmLeaveGroup() async {
    final t = widget.localeController.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("group_settings_leave"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Text(t("group_settings_leave_confirm"), style: const TextStyle(color: SyrixColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("group_settings_leave"), style: const TextStyle(color: SyrixColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiClient.leaveGroup(widget.conversationId);
      if (mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> showAddGroupOrChannelDialog({required bool isChannel}) async {
    final t = widget.localeController.t;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(
          isChannel ? t("community_add_channel") : t("community_add_group"),
          style: const TextStyle(color: SyrixColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SyrixColors.textPrimary),
          decoration: InputDecoration(
            hintText: isChannel ? "Nom du canal (ex: Annonces Officielles)" : "Nom du groupe",
            filled: true,
            fillColor: SyrixColors.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t("create_action")),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final res = await ApiClient.createGroupOrCommunity(
        name,
        type: "group",
        communityId: widget.conversationId,
      );
      if (res.statusCode == 201 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${isChannel ? "Canal" : "Groupe"} créé avec succès")),
        );
      }
    }
  }

  Future<void> confirmTransferOwnership(Map<String, dynamic> member) async {
    final t = widget.localeController.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("group_transfer_owner"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Text(
          t("group_transfer_owner_confirm").replaceAll("{name}", member["username"] ?? ""),
          style: const TextStyle(color: SyrixColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("group_transfer_owner")),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final res = await ApiClient.transferOwnership(widget.conversationId, member["id"]);
      if (res.statusCode == 200) {
        load();
      }
    }
  }

  void openMemberActions(Map<String, dynamic> member) {
    final t = widget.localeController.t;
    final isSelf = member["id"] == currentUserId;
    final isOwnerMember = member["role"] == "owner";

    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: SyrixColors.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: SyrixColors.surfaceAlt,
                  backgroundImage: member["avatarUrl"] != null ? NetworkImage(member["avatarUrl"]) : null,
                  child: member["avatarUrl"] == null ? Text((member["username"] ?? "?")[0].toUpperCase()) : null,
                ),
                title: Text(member["username"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text(member["role"] == "owner" ? "Propriétaire" : (member["role"] == "admin" ? "Admin du groupe" : "Membre"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
              ),
              const Divider(color: SyrixColors.border),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded, color: SyrixColors.textPrimary),
                title: Text("Message à @${member["username"]}", style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final res = await ApiClient.startPrivateChat(member["id"]);
                  if (res.statusCode == 200 || res.statusCode == 201) {
                    final b = jsonDecode(res.body);
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: b["id"].toString(),
                          title: member["username"] ?? "",
                          localeController: widget.localeController,
                        ),
                      ),
                    );
                  }
                },
              ),
              if (isAdmin && !isSelf && !isOwnerMember) ...[
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
                    leading: const Icon(Icons.admin_panel_settings_rounded, color: SyrixColors.primary),
                    title: Text(t("group_members_promote"), style: const TextStyle(color: SyrixColors.primary)),
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
              ],
              if (isCreator && !isSelf) ...[
                const Divider(color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B)),
                  title: Text(t("group_transfer_owner"), style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
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

  Future<void> regenerateLink() async {
    final response = await ApiClient.regenerateInviteLink(widget.conversationId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      setState(() => inviteCode = body["inviteCode"]);
    }
  }

  void copyLink() {
    if (inviteCode == null) return;
    Clipboard.setData(ClipboardData(text: inviteCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.localeController.t("group_settings_link_copied"))),
    );
  }

  void showQrCode() {
    if (inviteCode == null) return;
    final t = widget.localeController.t;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("group_settings_qr_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(data: inviteCode!, size: 200),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  void openPermissionsDialog() {
    final t = widget.localeController.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: SyrixColors.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(t("group_permissions_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t("group_edit_info_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(t("group_edit_info_desc"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                    trailing: DropdownButton<String>(
                      dropdownColor: SyrixColors.surfaceAlt,
                      value: whoCanEditInfo,
                      underline: const SizedBox(),
                      style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold),
                      items: [
                        DropdownMenuItem(value: "everyone", child: Text(t("group_permission_everyone"))),
                        DropdownMenuItem(value: "admins", child: Text(t("group_permission_admins"))),
                      ],
                      onChanged: isAdmin ? (v) {
                        if (v != null) {
                          setModalState(() => whoCanEditInfo = v);
                          setState(() => whoCanEditInfo = v);
                          saveSettings();
                        }
                      } : null,
                    ),
                  ),
                  const Divider(color: SyrixColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t("group_send_messages_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(t("group_send_messages_desc"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                    trailing: DropdownButton<String>(
                      dropdownColor: SyrixColors.surfaceAlt,
                      value: whoCanSendMessages,
                      underline: const SizedBox(),
                      style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold),
                      items: [
                        DropdownMenuItem(value: "everyone", child: Text(t("group_permission_everyone"))),
                        DropdownMenuItem(value: "admins", child: Text(t("group_permission_admins"))),
                      ],
                      onChanged: isAdmin ? (v) {
                        if (v != null) {
                          setModalState(() => whoCanSendMessages = v);
                          setState(() {
                            whoCanSendMessages = v;
                            closedGroup = v == "admins";
                          });
                          saveSettings();
                        }
                      } : null,
                    ),
                  ),
                  const Divider(color: SyrixColors.border),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t("group_add_members_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(t("group_add_members_desc"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                    trailing: DropdownButton<String>(
                      dropdownColor: SyrixColors.surfaceAlt,
                      value: whoCanAddMembers,
                      underline: const SizedBox(),
                      style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold),
                      items: [
                        DropdownMenuItem(value: "everyone", child: Text(t("group_permission_everyone"))),
                        DropdownMenuItem(value: "admins", child: Text(t("group_permission_admins"))),
                      ],
                      onChanged: isAdmin ? (v) {
                        if (v != null) {
                          setModalState(() => whoCanAddMembers = v);
                          setState(() => whoCanAddMembers = v);
                          saveSettings();
                        }
                      } : null,
                    ),
                  ),
                  const Divider(color: SyrixColors.border),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: SyrixColors.primary,
                    title: Text(t("group_approve_members_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(t("group_approve_members_desc"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                    value: approveNewMembers,
                    onChanged: isAdmin ? (v) {
                      setModalState(() => approveNewMembers = v);
                      setState(() => approveNewMembers = v);
                      saveSettings();
                    } : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final isCommunity = widget.type == "community";
    final title = isCommunity ? t("community_info_title") : t("group_info_title");
    final canEdit = isCreator || isAdmin || whoCanEditInfo == "everyone";

    if (loading) {
      return Scaffold(
        backgroundColor: SyrixColors.background,
        appBar: AppBar(backgroundColor: SyrixColors.surface, title: Text(title)),
        body: const Center(child: CircularProgressIndicator(color: SyrixColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(title, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (canEdit)
            IconButton(
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SyrixColors.primary))
                  : const Icon(Icons.check_rounded, color: SyrixColors.primary),
              onPressed: saving ? null : saveSettings,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: SyrixColors.textPrimary),
            color: SyrixColors.surface,
            onSelected: (val) {
              if (val == "share") copyLink();
              if (val == "qr") showQrCode();
              if (val == "delete") confirmDeleteGroup();
              if (val == "leave") confirmLeaveGroup();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: "share", child: Text(t("group_settings_copy_link"), style: const TextStyle(color: SyrixColors.textPrimary))),
              PopupMenuItem(value: "qr", child: Text(t("group_settings_qr_title"), style: const TextStyle(color: SyrixColors.textPrimary))),
              if (isAdmin || isCreator)
                PopupMenuItem(
                  value: "delete",
                  child: Text(isCommunity ? t("community_delete_action") : t("group_delete_action"), style: const TextStyle(color: SyrixColors.danger)),
                )
              else
                PopupMenuItem(
                  value: "leave",
                  child: Text(t("group_settings_leave"), style: const TextStyle(color: SyrixColors.danger)),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // WhatsApp-style Header Profile Section
            Container(
              padding: const EdgeInsets.all(20),
              color: SyrixColors.surface,
              child: Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: canEdit ? pickPhoto : null,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: SyrixColors.primary.withOpacity(0.4), width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: SyrixColors.surfaceAlt,
                              backgroundImage: pickedPhoto != null
                                  ? FileImage(pickedPhoto!)
                                  : (avatarUrl != null ? NetworkImage(avatarUrl!) : null) as ImageProvider?,
                              child: pickedPhoto == null && avatarUrl == null
                                  ? Icon(isCommunity ? Icons.hub_rounded : Icons.groups_rounded, color: SyrixColors.primary, size: 48)
                                  : null,
                            ),
                          ),
                          if (canEdit)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: SyrixColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Group Name with edit button
                  if (!editingName)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            nameController.text.isNotEmpty ? nameController.text : "Sans nom",
                            style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: SyrixColors.primary, size: 18),
                            onPressed: () => setState(() => editingName = true),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            autofocus: true,
                            style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: SyrixColors.surfaceAlt,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_rounded, color: SyrixColors.primary),
                          onPressed: () {
                            setState(() => editingName = false);
                            saveSettings();
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    t("group_participants_count").replaceAll("{count}", "$memberCount"),
                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // WhatsApp 4 Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickAction(
                        icon: Icons.call_outlined,
                        label: "Audio",
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appel de groupe"))),
                      ),
                      _buildQuickAction(
                        icon: Icons.videocam_outlined,
                        label: "Vidéo",
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appel vidéo de groupe"))),
                      ),
                      _buildQuickAction(
                        icon: Icons.person_add_alt_1_outlined,
                        label: "Ajouter",
                        onTap: () => copyLink(),
                      ),
                      _buildQuickAction(
                        icon: Icons.search_rounded,
                        label: "Chercher",
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Description Section
            Container(
              color: SyrixColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t("group_settings_description"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (canEdit && !editingDescription)
                        GestureDetector(
                          onTap: () => setState(() => editingDescription = true),
                          child: const Icon(Icons.edit_rounded, color: SyrixColors.primary, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!editingDescription)
                    Text(
                      descriptionController.text.isNotEmpty ? descriptionController.text : "Ajouter une description du groupe...",
                      style: TextStyle(
                        color: descriptionController.text.isNotEmpty ? SyrixColors.textPrimary : SyrixColors.textMuted,
                        fontSize: 15,
                        fontStyle: descriptionController.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          autofocus: true,
                          style: const TextStyle(color: SyrixColors.textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: SyrixColors.surfaceAlt,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => editingDescription = false),
                              child: Text(t("profile_cancel")),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => editingDescription = false);
                                saveSettings();
                              },
                              child: Text(t("group_settings_save")),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Media, Links and Docs Tile
            Container(
              color: SyrixColors.surface,
              child: ListTile(
                leading: const Icon(Icons.perm_media_outlined, color: SyrixColors.primary),
                title: Text(t("group_media_links_docs"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Médias et documents du groupe")));
                },
              ),
            ),
            const SizedBox(height: 12),

            // Group Permissions (Style WhatsApp)
            Container(
              color: SyrixColors.surface,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: SyrixColors.primary),
                    title: Text(t("group_permissions_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      whoCanSendMessages == "admins" ? "Seuls les admins peuvent envoyer des messages" : "Tous les membres peuvent envoyer des messages",
                      style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                    onTap: openPermissionsDialog,
                  ),
                  const Divider(color: SyrixColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded, color: SyrixColors.primary),
                    title: const Text("Chiffrement", style: TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w500)),
                    subtitle: Text(t("group_encryption_notice"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Community Specific Controls (if community)
            if (isCommunity) ...[
              const SizedBox(height: 12),
              Container(
                color: SyrixColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t("community_settings_title"), style: const TextStyle(color: SyrixColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group_add_rounded, color: SyrixColors.textPrimary),
                      title: Text(t("community_add_group"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      subtitle: const Text("Créer un sous-groupe pour la communauté", style: TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: SyrixColors.primary),
                      onTap: () => showAddGroupOrChannelDialog(isChannel: false),
                    ),
                    const Divider(color: SyrixColors.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8)),
                      title: Text(t("community_add_channel"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      subtitle: const Text("Canal de diffusion officiel", style: TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8)),
                      onTap: () => showAddGroupOrChannelDialog(isChannel: true),
                    ),
                    const Divider(color: SyrixColors.border, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t("community_who_can_add_groups"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(t("community_who_can_add_groups_desc"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                      trailing: DropdownButton<String>(
                        dropdownColor: SyrixColors.surfaceAlt,
                        value: whoCanAddGroups,
                        underline: const SizedBox(),
                        style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold),
                        items: [
                          DropdownMenuItem(value: "everyone", child: Text(t("group_permission_everyone"))),
                          DropdownMenuItem(value: "admins", child: Text(t("group_permission_admins"))),
                        ],
                        onChanged: isAdmin ? (v) {
                          if (v != null) {
                            setState(() => whoCanAddGroups = v);
                            saveSettings();
                          }
                        } : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Invite link & QR Code
            Container(
              color: SyrixColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t("group_settings_invite_link"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inviteCode ?? "Non disponible",
                          style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: SyrixColors.primary),
                        tooltip: t("group_settings_copy_link"),
                        onPressed: copyLink,
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_rounded, color: SyrixColors.primary),
                        tooltip: t("group_settings_qr_title"),
                        onPressed: showQrCode,
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: SyrixColors.textMuted),
                          tooltip: t("group_settings_regenerate_link"),
                          onPressed: regenerateLink,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Members / Participants List
            Container(
              color: SyrixColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      "${members.length} participants",
                      style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isAdmin || whoCanAddMembers == "everyone")
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: SyrixColors.primary,
                        child: Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(t("group_members_add"), style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                      onTap: () => copyLink(),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(color: SyrixColors.border, height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final isOwner = m["role"] == "owner";
                      final isAdm = m["role"] == "admin" || isOwner;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: SyrixColors.surfaceAlt,
                          backgroundImage: m["avatarUrl"] != null ? NetworkImage(m["avatarUrl"]) : null,
                          child: m["avatarUrl"] == null ? Text((m["username"] ?? "?")[0].toUpperCase(), style: const TextStyle(color: SyrixColors.textPrimary)) : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                m["username"] ?? "",
                                style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (m["id"] == currentUserId)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Text("(Vous)", style: TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          isOwner ? "Propriétaire" : (isAdm ? "Admin du groupe" : "Membre"),
                          style: TextStyle(
                            color: isOwner ? const Color(0xFFF59E0B) : (isAdm ? SyrixColors.primary : SyrixColors.textMuted),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isAdm
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isOwner ? const Color(0xFFF59E0B) : SyrixColors.primary).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOwner ? "Propriétaire" : "Admin",
                                  style: TextStyle(
                                    color: isOwner ? const Color(0xFFF59E0B) : SyrixColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => openMemberActions(m),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Additional features: Leaderboard & Audit log
            Container(
              color: SyrixColors.surface,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.leaderboard_rounded, color: SyrixColors.primary),
                    title: Text(t("group_settings_leaderboard"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupLeaderboardScreen(
                          localeController: widget.localeController,
                          conversationId: widget.conversationId,
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin) ...[
                    const Divider(color: SyrixColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.history_rounded, color: SyrixColors.primary),
                      title: Text(t("group_audit_log_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupAuditLogScreen(
                            localeController: widget.localeController,
                            conversationId: widget.conversationId,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Exit & Delete buttons
            Container(
              color: SyrixColors.surface,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: SyrixColors.danger),
                    title: Text(t("group_settings_leave"), style: const TextStyle(color: SyrixColors.danger, fontWeight: FontWeight.bold)),
                    onTap: confirmLeaveGroup,
                  ),
                  if (isAdmin || isCreator) ...[
                    const Divider(color: SyrixColors.border, height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_rounded, color: SyrixColors.danger),
                      title: Text(
                        isCommunity ? t("community_delete_action") : t("group_delete_action"),
                        style: const TextStyle(color: SyrixColors.danger, fontWeight: FontWeight.bold),
                      ),
                      onTap: confirmDeleteGroup,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SyrixColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: SyrixColors.border),
            ),
            child: Icon(icon, color: SyrixColors.primary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
