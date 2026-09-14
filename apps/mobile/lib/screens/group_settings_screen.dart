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
  String? avatarUrl;
  File? pickedPhoto;
  final descriptionController = TextEditingController();

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
    }
    final meResponse = await ApiClient.me();
    if (meResponse.statusCode == 200) {
      currentUserId = "${jsonDecode(meResponse.body)["id"]}";
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      if (pickedPhoto != null) {
        final uploadResponse = await ApiClient.uploadGroupPhoto(widget.conversationId, pickedPhoto!.path);
        final body = jsonDecode(await uploadResponse.stream.bytesToString());
        if (uploadResponse.statusCode == 201) {
          avatarUrl = body["avatarUrl"];
        }
      }
      await ApiClient.updateConversationSettings(
        widget.conversationId,
        name: nameController.text.trim(),
        isPrivate: isPrivate,
        messagePrice: int.tryParse(priceController.text.trim()) ?? 0,
        description: descriptionController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickPhoto() async {
    if (!isCreator) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (result == null) return;
    setState(() => pickedPhoto = File(result.path));
  }

  Future<void> toggleModeration(bool value) async {
    setState(() => aiModerationEnabled = value);
    final response = await ApiClient.updateModeration(widget.conversationId, value);
    if (response.statusCode != 200 && mounted) {
      setState(() => aiModerationEnabled = !value);
    }
  }

  Future<void> toggleClosedGroup(bool value) async {
    setState(() => closedGroup = value);
    final response = await ApiClient.updateClosedGroup(widget.conversationId, value);
    if (response.statusCode != 200 && mounted) {
      setState(() => closedGroup = !value);
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t("group_settings_leave"))),
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

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final title = widget.type == "community" ? t("community_settings_title") : t("group_settings_title");

    if (loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: SyrixColors.surface, title: Text(title)),
        body: const Center(child: CircularProgressIndicator(color: SyrixColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(title, style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          if (isCreator)
            TextButton(
              onPressed: saving ? null : save,
              child: Text(t("group_settings_save")),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text("$memberCount ${t("group_settings_members")}", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: SyrixColors.surfaceAlt,
                      backgroundImage: pickedPhoto != null
                          ? FileImage(pickedPhoto!)
                          : (avatarUrl != null ? NetworkImage(avatarUrl!) : null) as ImageProvider?,
                      child: pickedPhoto == null && avatarUrl == null
                          ? const Icon(Icons.groups_rounded, color: SyrixColors.textMuted, size: 32)
                          : null,
                    ),
                    if (isCreator)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: SyrixColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(t("group_settings_name"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            if (!isCreator || !editingName)
              GestureDetector(
                onTap: isCreator ? () => setState(() => editingName = true) : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: SyrixColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SyrixColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(nameController.text, style: const TextStyle(color: SyrixColors.textPrimary)),
                      ),
                      if (isCreator)
                        const Icon(Icons.edit_rounded, color: SyrixColors.textMuted, size: 18),
                    ],
                  ),
                ),
              )
            else
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: SyrixColors.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_rounded, color: SyrixColors.primary),
                    onPressed: () => setState(() => editingName = false),
                  ),
                ),
                onSubmitted: (_) => setState(() => editingName = false),
              ),
            const SizedBox(height: 20),
            Text(t("group_settings_description"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              enabled: isCreator,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
              ),
            ),
            const SizedBox(height: 20),
            Text(t("group_settings_privacy"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    groupValue: isPrivate,
                    activeColor: SyrixColors.primary,
                    title: Text(t("group_settings_private"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: isCreator ? (value) => setState(() => isPrivate = value!) : null,
                  ),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: isPrivate,
                    activeColor: SyrixColors.primary,
                    title: Text(t("group_settings_public"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: isCreator ? (value) => setState(() => isPrivate = value!) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(t("group_settings_message_price"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: priceController,
              enabled: isCreator,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
              ),
            ),
            const SizedBox(height: 6),
            Text(t("group_settings_message_price_helper"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.group_rounded, color: SyrixColors.textPrimary),
                title: Text(t("group_settings_members_action"), style: const TextStyle(color: SyrixColors.textPrimary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                onTap: () async {
                  final response = await ApiClient.me();
                  final myId = response.statusCode == 200 ? "${jsonDecode(response.body)["id"]}" : "";
                  if (!mounted) return;
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupMembersScreen(
                        localeController: widget.localeController,
                        conversationId: widget.conversationId,
                        isAdmin: isAdmin,
                        isOwner: isCreator,
                        currentUserId: myId,
                      ),
                    ),
                  );
                  if (result == true) load();
                },
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.leaderboard_rounded, color: SyrixColors.textPrimary),
                title: Text(t("group_settings_leaderboard"), style: const TextStyle(color: SyrixColors.textPrimary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupLeaderboardScreen(
                        localeController: widget.localeController,
                        conversationId: widget.conversationId,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                child: SwitchListTile(
                  activeColor: SyrixColors.primary,
                  value: closedGroup,
                  onChanged: toggleClosedGroup,
                  title: Text(t("group_settings_closed_group"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  subtitle: Text(
                    t("group_settings_closed_group_hint"),
                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.history_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("group_audit_log_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupAuditLogScreen(
                          localeController: widget.localeController,
                          conversationId: widget.conversationId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (isCreator) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                child: SwitchListTile(
                  activeColor: SyrixColors.primary,
                  value: aiModerationEnabled,
                  onChanged: toggleModeration,
                  title: Text(t("group_settings_moderation"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  subtitle: Text(
                    t("group_settings_moderation_hint"),
                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(t("group_settings_invite_link"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        inviteCode ?? "",
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: SyrixColors.primary, size: 18),
                      onPressed: copyLink,
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_rounded, color: SyrixColors.primary, size: 18),
                      onPressed: showQrCode,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: regenerateLink,
                child: Text(t("group_settings_regenerate_link")),
              ),
            ],
            if (!isCreator) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: SyrixColors.danger, side: const BorderSide(color: SyrixColors.danger)),
                onPressed: confirmLeaveGroup,
                child: Text(t("group_settings_leave")),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
