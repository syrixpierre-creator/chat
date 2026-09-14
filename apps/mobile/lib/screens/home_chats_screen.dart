import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/story_bar.dart";
import "../widgets/chat_list_item.dart";
import "../widgets/create_sheet.dart";
import "../widgets/account_switcher_sheet.dart";
import "../services/account_service.dart";
import "../services/offline_cache.dart";
import "chat_screen.dart";
import "community_screen.dart";
import "archived_chats_screen.dart";
import "story_viewer_screen.dart";
import "create_story_screen.dart";
import "notes_screen.dart";
import "qr_scanner_screen.dart";
import "../utils/invite_code.dart";
import "user_profile_screen.dart";

class HomeChatsScreen extends StatefulWidget {
  final LocaleController localeController;

  const HomeChatsScreen({super.key, required this.localeController});

  @override
  State<HomeChatsScreen> createState() => _HomeChatsScreenState();
}

class _HomeChatsScreenState extends State<HomeChatsScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> stories = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> folders = [];
  String? selectedFolderId;
  String messageFilter = "all";
  bool loading = true;
  bool offline = false;
  bool searching = false;
  bool currentUserIsPremium = false;
  String? currentUserId;
  Map<String, dynamic>? activeAccount;

  @override
  void initState() {
    super.initState();
    loadData();
    loadActiveAccount();
    loadCurrentUser();
  }

  Future<void> loadCurrentUser() async {
    final response = await ApiClient.me();
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          currentUserIsPremium = body["isPremium"] == true;
          currentUserId = "${body["id"]}";
        });
      }
    }
  }

  Future<void> loadActiveAccount() async {
    final id = await AccountService.activeAccountId();
    final accounts = await AccountService.listAccounts();
    if (!mounted) return;
    setState(() {
      activeAccount = accounts.where((a) => a["id"] == id).isNotEmpty
          ? accounts.firstWhere((a) => a["id"] == id)
          : null;
    });
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    try {
      final chatsResponse = await ApiClient.listChats().timeout(const Duration(seconds: 8));
      final storiesResponse = await ApiClient.listStories().timeout(const Duration(seconds: 8));
      final foldersResponse = await ApiClient.listFolders().timeout(const Duration(seconds: 8));
      if (chatsResponse.statusCode == 200) {
        chats = List<Map<String, dynamic>>.from(jsonDecode(chatsResponse.body));
        await OfflineCache.saveJson("chats", chats);
      }
      if (storiesResponse.statusCode == 200) {
        stories = List<Map<String, dynamic>>.from(jsonDecode(storiesResponse.body));
      }
      if (foldersResponse.statusCode == 200) {
        folders = List<Map<String, dynamic>>.from(jsonDecode(foldersResponse.body));
      }
      offline = false;
    } catch (_) {
      final cached = await OfflineCache.loadJson("chats");
      if (cached != null) {
        chats = List<Map<String, dynamic>>.from(cached);
      }
      offline = true;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> onSearchChanged(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        searching = false;
        searchResults = [];
      });
      return;
    }
    setState(() => searching = true);
    final response = await ApiClient.searchUsers(value.trim());
    if (response.statusCode == 200) {
      setState(() => searchResults = List<Map<String, dynamic>>.from(jsonDecode(response.body)));
    }
  }

  Future<void> startChatWith(String userId, String username) async {
    final response = await ApiClient.startPrivateChat(userId);
    searchController.clear();
    setState(() {
      searching = false;
      searchResults = [];
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      openChat(body["id"].toString(), username);
    }
    loadData();
  }

  Future<void> scanAndJoin() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => QrScannerScreen(localeController: widget.localeController)),
    );
    if (scanned == null || scanned.isEmpty) return;
    if (isProfileQrCode(scanned)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            localeController: widget.localeController,
            userId: extractUserIdFromProfileQr(scanned),
          ),
        ),
      );
      return;
    }
    final code = extractInviteCode(scanned);
    final response = await ApiClient.joinByInviteCode(code);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      loadData();
      if (mounted) openChat(body["id"].toString(), body["name"] ?? "");
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.localeController.t("join_group_error"))),
      );
    }
  }

  void openChat(String conversationId, String title, {String type = "private"}) {
    if (type == "community") {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityScreen(
            communityId: conversationId,
            communityName: title,
            localeController: widget.localeController,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          localeController: widget.localeController,
          conversationId: conversationId,
          title: title,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get filteredChats {
    List<Map<String, dynamic>> base = chats;
    if (selectedFolderId != null) {
      final folder = folders.where((f) => f["_id"] == selectedFolderId).toList();
      if (folder.isNotEmpty) {
        final ids = List<String>.from(folder.first["conversationIds"] ?? []);
        base = base.where((c) => ids.contains(c["id"].toString())).toList();
      }
    }
    switch (messageFilter) {
      case "unread":
        return base.where((c) => c["unread"] == true).toList();
      case "read":
        return base.where((c) => c["unread"] != true).toList();
      case "group":
        return base.where((c) => c["type"] == "group").toList();
      case "community":
        return base.where((c) => c["type"] == "community").toList();
      default:
        return base;
    }
  }

  Future<void> createFolder() async {
    final t = widget.localeController.t;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("folders_new"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SyrixColors.textPrimary),
          decoration: InputDecoration(hintText: t("folders_name_hint")),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t("folders_new")),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ApiClient.createFolder(name);
    loadData();
  }

  Future<void> manageFolder(Map<String, dynamic> folder) async {
    final t = widget.localeController.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: SyrixColors.textPrimary),
                title: Text(t("folders_rename"), style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController(text: folder["name"]);
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: SyrixColors.surface,
                      title: Text(t("folders_rename"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                          child: Text(t("developer_bots_save")),
                        ),
                      ],
                    ),
                  );
                  if (name != null && name.isNotEmpty) {
                    await ApiClient.renameFolder(folder["_id"], name);
                    loadData();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: SyrixColors.danger),
                title: Text(t("folders_delete"), style: const TextStyle(color: SyrixColors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: SyrixColors.surface,
                      title: Text(t("folders_delete"), style: const TextStyle(color: SyrixColors.textPrimary)),
                      content: Text(t("folders_delete_confirm"), style: const TextStyle(color: SyrixColors.textMuted)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t("profile_cancel"))),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(t("folders_delete"), style: const TextStyle(color: SyrixColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ApiClient.deleteFolder(folder["_id"]);
                    if (selectedFolderId == folder["_id"]) selectedFolderId = null;
                    loadData();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void openAddToFolderSheet(Map<String, dynamic> chat) {
    final t = widget.localeController.t;
    final conversationId = chat["id"].toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  t("chat_add_to_folder"),
                  style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
              ...folders.map((folder) {
                final included = List<String>.from(folder["conversationIds"] ?? []).contains(conversationId);
                return CheckboxListTile(
                  activeColor: SyrixColors.primary,
                  value: included,
                  title: Text(folder["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                  onChanged: (value) async {
                    if (value == true) {
                      await ApiClient.addConversationToFolder(folder["_id"], conversationId);
                    } else {
                      await ApiClient.removeConversationFromFolder(folder["_id"], conversationId);
                    }
                    Navigator.pop(context);
                    loadData();
                  },
                );
              }),
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: const LinearGradient(colors: [SyrixColors.primary, SyrixColors.primaryDark]),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "SYRIX CHAT",
                    style: TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.archive_outlined, color: SyrixColors.textPrimary),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArchivedChatsScreen(localeController: widget.localeController),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: SyrixColors.textPrimary),
                    onPressed: scanAndJoin,
                  ),
                  GestureDetector(
                    onTap: () async {
                      await showAccountSwitcherSheet(context, widget.localeController);
                      loadActiveAccount();
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: SyrixColors.surfaceAlt,
                      backgroundImage: activeAccount?["avatarUrl"] != null
                          ? NetworkImage(activeAccount!["avatarUrl"])
                          : null,
                      child: activeAccount?["avatarUrl"] == null
                          ? Text(
                              (activeAccount?["username"] ?? "").isNotEmpty
                                  ? activeAccount!["username"][0].toUpperCase()
                                  : "?",
                              style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (offline)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SyrixColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 16, color: SyrixColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t("offline_banner"),
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: SyrixColors.textMuted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: t("home_search_hint"),
                          hintStyle: const TextStyle(color: SyrixColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
                  : searching
                      ? _buildSearchResults()
                      : RefreshIndicator(
                          onRefresh: loadData,
                          color: SyrixColors.primary,
                          child: ListView(
                            children: [
                              StoryBar(
                                stories: stories,
                                currentUserId: currentUserId,
                                localeController: widget.localeController,
                                onMyStoryTap: () async {
                                  final posted = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => CreateStoryScreen(localeController: widget.localeController),
                                    ),
                                  );
                                  if (posted == true) loadData();
                                },
                                onStoryGroupTap: (index) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StoryViewerScreen(
                                        storyGroups: stories,
                                        initialGroupIndex: index,
                                        localeController: widget.localeController,
                                        currentUserIsPremium: currentUserIsPremium,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: SyrixColors.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bookmark_rounded, color: SyrixColors.primary),
                                ),
                                title: Text(
                                  t("home_notes"),
                                  style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NotesScreen(localeController: widget.localeController),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                height: 40,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  children: [
                                    ChoiceChip(
                                      label: Text(t("folders_all")),
                                      selected: selectedFolderId == null,
                                      onSelected: (_) => setState(() => selectedFolderId = null),
                                    ),
                                    for (final folder in folders)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: GestureDetector(
                                          onLongPress: () => manageFolder(folder),
                                          child: ChoiceChip(
                                            label: Text(folder["name"] ?? ""),
                                            selected: selectedFolderId == folder["_id"],
                                            onSelected: (_) => setState(() => selectedFolderId = folder["_id"]),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: ActionChip(
                                        avatar: const Icon(Icons.add_rounded, size: 16, color: SyrixColors.textMuted),
                                        label: Text(t("folders_new")),
                                        onPressed: createFolder,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  children: [
                                    for (final entry in {
                                      "all": "filter_all",
                                      "unread": "filter_unread",
                                      "read": "filter_read",
                                      "group": "filter_groups",
                                      "community": "filter_communities",
                                    }.entries)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ChoiceChip(
                                          label: Text(t(entry.value)),
                                          selected: messageFilter == entry.key,
                                          onSelected: (_) => setState(() => messageFilter = entry.key),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (filteredChats.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 60),
                                  child: Center(
                                    child: Text(
                                      t("home_empty_chats"),
                                      style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14),
                                    ),
                                  ),
                                ),
                              for (final chat in filteredChats)
                                Dismissible(
                                  key: ValueKey(chat["id"]),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    color: SyrixColors.primary,
                                    child: const Icon(Icons.archive_rounded, color: Colors.white),
                                  ),
                                  confirmDismiss: (_) async {
                                    await ApiClient.archiveConversation(chat["id"].toString());
                                    setState(() => chats.removeWhere((c) => c["id"] == chat["id"]));
                                    return false;
                                  },
                                  child: ChatListItem(
                                    name: chat["name"] ?? "",
                                    lastMessage: chat["lastMessage"]?["content"],
                                    avatarUrl: chat["avatarUrl"],
                                    isBot: chat["isBot"] == true,
                                    isPremium: chat["isPremium"] == true,
                                    type: chat["type"] ?? "private",
                                    unread: chat["unread"] == true,
                                    onTap: () => openChat(chat["id"].toString(), chat["name"] ?? "", type: chat["type"] ?? "private"),
                                    onLongPress: () => openAddToFolderSheet(chat),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SyrixColors.primary,
        onPressed: () => showCreateSheet(context, widget.localeController, loadData),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      children: [
        for (final user in searchResults)
          ChatListItem(
            name: user["username"] ?? "",
            lastMessage: null,
            avatarUrl: user["avatarUrl"],
            isBot: user["isBot"] == true,
            isPremium: user["isPremium"] == true,
            onTap: () => startChatWith(user["id"], user["username"] ?? ""),
          ),
      ],
    );
  }
}
