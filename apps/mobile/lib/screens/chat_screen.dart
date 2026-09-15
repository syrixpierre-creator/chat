import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "package:record/record.dart";
import "package:path_provider/path_provider.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/offline_cache.dart";
import "../services/ws_client.dart";
import "../widgets/message_bubble.dart";
import "../widgets/gift_sheet.dart";
import "../widgets/verified_badge.dart";
import "group_settings_screen.dart";
import "wallet_screen.dart";
import "call_screen.dart";

class ChatScreen extends StatefulWidget {
  final LocaleController localeController;
  final String conversationId;
  final String title;

  const ChatScreen({
    super.key,
    required this.localeController,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final wsClient = WsClient();
  List<Map<String, dynamic>> messages = [];
  String? currentUserId;
  String conversationType = "private";
  String? conversationAvatarUrl;
  String? conversationTitle;
  int memberCount = 0;
  Map<String, dynamic>? otherUser;
  bool contactAdded = false;
  bool loading = true;
  bool uploadingAttachment = false;
  Map<String, dynamic>? replyingTo;
  final recorder = AudioRecorder();
  bool isRecording = false;
  bool cancelRecording = false;
  int recordSeconds = 0;
  Timer? recordTimer;
  String? recordingPath;
  bool hasText = false;
  int selfDestructSeconds = 0;
  bool closedGroup = false;
  bool offline = false;
  final Map<String, GlobalKey> messageKeys = {};
  String? activeMentionTag;
  List<String> mentionMatchIds = [];
  int mentionIndex = 0;
  bool searchMode = false;
  final searchController = TextEditingController();
  String searchQueryText = "";
  List<String> searchResultIds = [];
  int searchResultIndex = 0;

  void scrollToMessageId(String? id) {
    if (id == null) return;
    final key = messageKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.4);
    }
  }

  void runSearch(String query) {
    setState(() {
      searchQueryText = query;
      if (query.trim().isEmpty) {
        searchResultIds = [];
      } else {
        searchResultIds = messages
            .where((m) => (m["content"] ?? "").toString().toLowerCase().contains(query.toLowerCase()))
            .map((m) => (m["id"] ?? m["_id"]).toString())
            .toList();
      }
      searchResultIndex = 0;
    });
    if (searchResultIds.isNotEmpty) scrollToMessageId(searchResultIds.last);
  }

  void nextSearchResult() {
    if (searchResultIds.isEmpty) return;
    setState(() => searchResultIndex = (searchResultIndex + 1) % searchResultIds.length);
    scrollToMessageId(searchResultIds[searchResultIds.length - 1 - searchResultIndex]);
  }

  void previousSearchResult() {
    if (searchResultIds.isEmpty) return;
    setState(() => searchResultIndex = (searchResultIndex - 1 + searchResultIds.length) % searchResultIds.length);
    scrollToMessageId(searchResultIds[searchResultIds.length - 1 - searchResultIndex]);
  }

  void closeSearch() {
    setState(() {
      searchMode = false;
      searchController.clear();
      searchResultIds = [];
      searchQueryText = "";
    });
  }
  bool isGroupAdmin = false;
  Map<String, Map<String, dynamic>> membersById = {};
  List<Map<String, dynamic>> myQuickReplies = [];
  List<Map<String, dynamic>> quickReplySuggestions = [];

  @override
  void initState() {
    super.initState();
    messageController.addListener(() {
      final next = messageController.text.trim().isNotEmpty;
      if (next != hasText) setState(() => hasText = next);
      final text = messageController.text;
      if (text.startsWith("/") && !text.contains(" ")) {
        final query = text.substring(1).toLowerCase();
        setState(() {
          quickReplySuggestions = myQuickReplies
              .where((q) => "${q["shortcut"]}".toLowerCase().startsWith(query))
              .toList();
        });
      } else if (quickReplySuggestions.isNotEmpty) {
        setState(() => quickReplySuggestions = []);
      }
    });
    loadQuickReplies();
    init();
  }

  Future<void> loadQuickReplies() async {
    final response = await ApiClient.getBusinessTools();
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          myQuickReplies = List<Map<String, dynamic>>.from(body["quickReplies"] ?? []);
        });
      }
    }
  }

  Future<void> init() async {
    try {
      final meResponse = await ApiClient.me().timeout(const Duration(seconds: 8));
      if (meResponse.statusCode == 200) {
        currentUserId = jsonDecode(meResponse.body)["id"];
      }

      final detailsResponse = await ApiClient.getConversationDetails(widget.conversationId).timeout(const Duration(seconds: 8));
      if (detailsResponse.statusCode == 200) {
        final body = jsonDecode(detailsResponse.body);
        conversationType = body["type"] ?? "private";
        conversationAvatarUrl = body["avatarUrl"];
        conversationTitle = body["name"] ?? widget.title;
        memberCount = body["memberCount"] ?? 0;
        selfDestructSeconds = body["selfDestructSeconds"] ?? 0;
        closedGroup = body["closedGroup"] ?? false;
        isGroupAdmin = body["isAdmin"] ?? false;
        if (conversationType == "private") {
          otherUser = body["otherUser"];
          if (conversationAvatarUrl == null && otherUser?["avatarUrl"] != null) {
            conversationAvatarUrl = otherUser!["avatarUrl"];
          }
        }
      }

      if (conversationType == "group" || conversationType == "community") {
        final membersResponse = await ApiClient.listMembers(widget.conversationId).timeout(const Duration(seconds: 8));
        if (membersResponse.statusCode == 200) {
          final membersBody = jsonDecode(membersResponse.body);
          for (final member in List<Map<String, dynamic>>.from(membersBody["members"] ?? [])) {
            membersById[member["id"]] = member;
          }
        }
      }

      final response = await ApiClient.listMessages(widget.conversationId).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        messages = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        await OfflineCache.saveJson("messages_${widget.conversationId}", messages);
      }
      offline = false;
    } catch (_) {
      final cached = await OfflineCache.loadJson("messages_${widget.conversationId}");
      if (cached != null) {
        messages = List<Map<String, dynamic>>.from(cached);
      }
      offline = true;
    }
    if (mounted) setState(() => loading = false);
    scrollToBottom();

    try {
      await wsClient.connect();
    } catch (_) {
      return;
    }
    wsClient.messages.listen((incoming) {
      if (incoming["messageEvent"] != null) {
        if (incoming["conversationId"] != widget.conversationId) return;
        if (incoming["messageEvent"] == "conversationAvatarUpdated") {
          setState(() => conversationAvatarUrl = incoming["avatarUrl"]);
          return;
        }
        if (incoming["messageEvent"] == "conversationUpdated") {
          setState(() {
            if (incoming["name"] != null) conversationTitle = incoming["name"];
            if (incoming["avatarUrl"] != null) conversationAvatarUrl = incoming["avatarUrl"];
          });
          return;
        }
        if (incoming["messageEvent"] == "selfDestructChanged") {
          setState(() => selfDestructSeconds = incoming["selfDestructSeconds"] ?? 0);
          return;
        }
        if (incoming["messageEvent"] == "closedGroupChanged") {
          setState(() => closedGroup = incoming["closedGroup"] ?? false);
          return;
        }
        if (incoming["messageEvent"] == "ownerTransferred") {
          if (incoming["newOwnerId"] == currentUserId) {
            setState(() => isGroupAdmin = true);
          }
          return;
        }
        if (incoming["messageEvent"] == "memberUpdate") {
          final memberId = incoming["memberId"];
          final action = incoming["action"];
          if (memberId == currentUserId && (action == "kicked" || action == "banned")) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.localeController.t("group_removed_$action"))),
              );
              Navigator.of(context).pop();
            }
          }
          return;
        }
        final messageId = incoming["messageId"];
        final index = messages.indexWhere((m) => (m["id"] ?? m["_id"]) == messageId);
        if (index == -1) return;
        setState(() {
          if (incoming["messageEvent"] == "pin") {
            messages[index]["pinned"] = incoming["pinned"];
          } else if (incoming["messageEvent"] == "react") {
            messages[index]["reactions"] = incoming["reactions"];
          } else if (incoming["messageEvent"] == "delete") {
            messages[index]["deletedForEveryone"] = incoming["deletedForEveryone"];
            messages[index]["content"] = "";
          } else if (incoming["messageEvent"] == "edit") {
            messages[index]["content"] = incoming["content"];
            messages[index]["edited"] = true;
          }
        });
        return;
      }
      if (incoming["conversationId"] == widget.conversationId) {
        setState(() => messages.add(incoming));
        scrollToBottom();
      }
    });
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    await ApiClient.reactToMessage(widget.conversationId, messageId, emoji);
  }

  Future<void> openMentionedProfile(String username) async {
    final regex = RegExp("@$username\\b", caseSensitive: false);
    final matches = <String>[];
    for (final m in messages) {
      final id = (m["id"] ?? m["_id"])?.toString();
      if (id != null && regex.hasMatch(m["content"] ?? "")) {
        matches.add(id);
      }
    }
    if (matches.isEmpty) return;
    setState(() {
      activeMentionTag = username;
      mentionMatchIds = matches;
      mentionIndex = 0;
    });
    scrollToMention();
  }

  void scrollToMention() {
    if (mentionMatchIds.isEmpty) return;
    scrollToMessageId(mentionMatchIds[mentionIndex]);
  }

  void nextMention() {
    if (mentionMatchIds.isEmpty) return;
    setState(() => mentionIndex = (mentionIndex + 1) % mentionMatchIds.length);
    scrollToMention();
  }

  void previousMention() {
    if (mentionMatchIds.isEmpty) return;
    setState(() => mentionIndex = (mentionIndex - 1 + mentionMatchIds.length) % mentionMatchIds.length);
    scrollToMention();
  }

  void closeMentionNav() {
    setState(() {
      activeMentionTag = null;
      mentionMatchIds = [];
    });
  }

  Future<void> forwardMessage(String content) async {
    final t = widget.localeController.t;
    final response = await ApiClient.listChats();
    if (response.statusCode != 200 || !mounted) return;
    final chats = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    final target = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t("chat_forward_to"), style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w700)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: chats
                    .map(
                      (c) => ListTile(
                        title: Text(c["name"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                        onTap: () => Navigator.pop(context, c),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null) return;
    await ApiClient.sendMessage(target["id"].toString(), content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t("chat_forward_sent"))));
    }
  }

  Future<void> togglePin(String messageId) async {
    await ApiClient.togglePinMessage(widget.conversationId, messageId);
  }

  Future<void> editMessage(String messageId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(widget.localeController.t("chat_edit"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(color: SyrixColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.localeController.t("profile_cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(widget.localeController.t("contact_rename_save")),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == currentContent) return;
    final response = await ApiClient.editMessage(widget.conversationId, messageId, result);
    if (response.statusCode != 200) return;
    final index = messages.indexWhere((m) => (m["id"] ?? m["_id"]) == messageId);
    if (index != -1 && mounted) {
      setState(() {
        messages[index]["content"] = result;
        messages[index]["edited"] = true;
      });
    }
  }

  Future<String?> translateMessage(String messageId) async {
    final response = await ApiClient.translateMessage(
      widget.conversationId,
      messageId,
      widget.localeController.locale,
    );
    if (response.statusCode != 200) return widget.localeController.t("chat_translate_failed");
    final body = jsonDecode(response.body);
    return body["translated"] as String?;
  }

  void startReply(Map<String, dynamic> message) {
    setState(() => replyingTo = message);
  }

  void cancelReply() {
    setState(() => replyingTo = null);
  }

  Future<void> deleteForMe(String messageId) async {
    final response = await ApiClient.deleteMessage(widget.conversationId, messageId, "me");
    if (response.statusCode == 200 && mounted) {
      setState(() => messages.removeWhere((m) => (m["id"] ?? m["_id"]) == messageId));
    }
  }

  Future<void> deleteForEveryone(String messageId) async {
    final response = await ApiClient.deleteMessage(widget.conversationId, messageId, "everyone");
    if (response.statusCode == 200 && mounted) {
      final index = messages.indexWhere((m) => (m["id"] ?? m["_id"]) == messageId);
      if (index != -1) {
        setState(() {
          messages[index]["deletedForEveryone"] = true;
          messages[index]["content"] = "";
        });
      }
    }
  }

  Future<void> startRecording() async {
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("chat_mic_permission_denied"))),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/syrix_voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
    recordTimer?.cancel();
    setState(() {
      isRecording = true;
      cancelRecording = false;
      recordSeconds = 0;
      recordingPath = filePath;
    });
    recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => recordSeconds += 1);
    });
  }

  Future<void> finishRecording() async {
    recordTimer?.cancel();
    final path = await recorder.stop();
    final wasCancelled = cancelRecording;
    final duration = recordSeconds;
    if (mounted) {
      setState(() {
        isRecording = false;
        cancelRecording = false;
      });
    }
    if (wasCancelled || path == null) {
      final file = File(path ?? "");
      if (await file.exists()) await file.delete();
      return;
    }
    await sendVoiceMessage(path, duration);
  }

  Future<void> sendVoiceMessage(String filePath, int durationSeconds) async {
    setState(() => uploadingAttachment = true);
    try {
      final uploadResponse = await ApiClient.uploadChatMedia(filePath);
      final body = jsonDecode(await uploadResponse.stream.bytesToString());
      if (uploadResponse.statusCode != 201) return;

      final url = body["url"];
      final sendResponse = await ApiClient.sendMessage(
        widget.conversationId,
        url,
        type: "voice",
        durationSeconds: durationSeconds,
      );
      if (sendResponse.statusCode == 402) {
        if (mounted) showInsufficientBalanceDialog();
        return;
      }
      setState(() {
        messages.add({
          "senderId": currentUserId,
          "content": url,
          "type": "voice",
          "conversationId": widget.conversationId,
          "pinned": false,
          "reactions": [],
          "durationSeconds": durationSeconds,
          if (selfDestructSeconds > 0)
            "expireAt": DateTime.now().add(Duration(seconds: selfDestructSeconds)).toIso8601String(),
        });
      });
      scrollToBottom();
    } finally {
      if (mounted) setState(() => uploadingAttachment = false);
    }
  }

  Future<String?> transcribeMessage(String messageId) async {
    final response = await ApiClient.transcribeMessage(widget.conversationId, messageId);
    if (response.statusCode != 200) return widget.localeController.t("chat_transcribe_failed");
    final body = jsonDecode(response.body);
    return body["transcript"] as String?;
  }

  Future<void> setSelfDestruct(int seconds) async {
    final response = await ApiClient.updateSelfDestruct(widget.conversationId, seconds);
    if (response.statusCode == 200 && mounted) {
      setState(() => selfDestructSeconds = seconds);
    }
  }

  void openChatMenu() {
    final t = widget.localeController.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) {
        final options = <int, String>{
          0: t("chat_self_destruct_off"),
          60: t("chat_self_destruct_1m"),
          3600: t("chat_self_destruct_1h"),
          86400: t("chat_self_destruct_1d"),
          604800: t("chat_self_destruct_1w"),
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: SyrixColors.textPrimary),
                    const SizedBox(width: 10),
                    Text(
                      t("chat_self_destruct_title"),
                      style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              ...options.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value, style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: selfDestructSeconds == entry.key
                      ? const Icon(Icons.check_rounded, color: SyrixColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setSelfDestruct(entry.key);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> send() async {
    final content = messageController.text.trim();
    if (content.isEmpty) return;
    final replyToId = (replyingTo?["id"] ?? replyingTo?["_id"])?.toString();
    final replySnapshot = replyingTo;
    messageController.clear();
    final response = await ApiClient.sendMessage(
      widget.conversationId,
      content,
      replyToId: replyToId,
    );
    if (response.statusCode == 402) {
      if (mounted) showInsufficientBalanceDialog();
      return;
    }
    if (response.statusCode == 403) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("group_closed_banner"))),
        );
      }
      return;
    }
    if (response.statusCode == 422) {
      if (mounted) {
        final body = jsonDecode(response.body);
        final category = body["category"] ?? "spam";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("chat_message_blocked_$category"))),
        );
      }
      return;
    }
    setState(() {
      messages.add({
        "senderId": currentUserId,
        "content": content,
        "type": "text",
        "conversationId": widget.conversationId,
        "pinned": false,
        "reactions": [],
        if (selfDestructSeconds > 0)
          "expireAt": DateTime.now().add(Duration(seconds: selfDestructSeconds)).toIso8601String(),
        if (replySnapshot != null)
          "replyTo": {
            "messageId": replyToId,
            "senderId": replySnapshot["senderId"],
            "content": replySnapshot["content"],
            "type": replySnapshot["type"] ?? "text",
          },
      });
      replyingTo = null;
    });
    scrollToBottom();
  }

  Future<void> pickAndSendAttachment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => uploadingAttachment = true);
    try {
      final uploadResponse = await ApiClient.uploadChatMedia(picked.path);
      final body = jsonDecode(await uploadResponse.stream.bytesToString());
      if (uploadResponse.statusCode != 201) return;

      final url = body["url"];
      final sendResponse = await ApiClient.sendMessage(widget.conversationId, url, type: "image");
      if (sendResponse.statusCode == 402) {
        if (mounted) showInsufficientBalanceDialog();
        return;
      }
      setState(() {
        messages.add({
          "senderId": currentUserId,
          "content": url,
          "type": "image",
          "conversationId": widget.conversationId,
          "pinned": false,
          "reactions": [],
          "spoiler": false,
          if (selfDestructSeconds > 0)
            "expireAt": DateTime.now().add(Duration(seconds: selfDestructSeconds)).toIso8601String(),
        });
      });
      scrollToBottom();
    } finally {
      if (mounted) setState(() => uploadingAttachment = false);
    }
  }

  Future<void> openGiftSheet() async {
    final sent = await showGiftSheet(context, widget.localeController, widget.conversationId);
    if (sent == false && mounted) {
      showInsufficientBalanceDialog();
    }
  }

  void showInsufficientBalanceDialog() {
    final t = widget.localeController.t;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SyrixColors.surface,
          title: Text(t("chat_insufficient_balance"), style: const TextStyle(color: SyrixColors.textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t("profile_cancel")),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WalletScreen(localeController: widget.localeController)),
                );
              },
              child: Text(t("chat_top_up_now")),
            ),
          ],
        );
      },
    );
  }

  Future<void> addContact() async {
    if (otherUser == null) return;
    final t = widget.localeController.t;
    final aliasController = TextEditingController(text: otherUser!["username"] ?? "");
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("contact_add_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("@${otherUser!["username"] ?? ""}", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: aliasController,
              autofocus: true,
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, aliasController.text.trim()),
            child: Text(t("contact_add_save")),
          ),
        ],
      ),
    );
    if (alias == null) return;
    final response = await ApiClient.addContact(otherUser!["id"], alias: alias.isNotEmpty ? alias : null);
    if (response.statusCode == 201 && mounted) {
      setState(() => contactAdded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t("contact_add_success"))),
      );
    }
  }

  Future<void> startCall(String mode) async {
    if (otherUser == null) return;
    final response = await ApiClient.initiateCall(widget.conversationId, mode);
    if (response.statusCode != 201 || !mounted) return;
    final body = jsonDecode(response.body);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          localeController: widget.localeController,
          roomName: body["roomName"],
          token: body["token"],
          url: body["url"],
          mode: mode,
          otherUserId: otherUser!["id"],
          otherUsername: otherUser!["username"] ?? "",
        ),
      ),
    );
  }

  void openGroupSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupSettingsScreen(
          localeController: widget.localeController,
          conversationId: widget.conversationId,
          type: conversationType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    wsClient.disconnect();
    recordTimer?.cancel();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final isGroup = conversationType == "group" || conversationType == "community";
    final isBot = otherUser?["isBot"] == true;
    final dmPrice = otherUser?["dmPrice"] ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        titleSpacing: 0,
        title: searchMode
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: SyrixColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t("chat_search_hint"),
                  border: InputBorder.none,
                ),
                onChanged: runSearch,
              )
            : GestureDetector(
                onTap: isGroup
                    ? openGroupSettings
                    : () {
                        if (otherUser != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: otherUser!["id"],
                                localeController: widget.localeController,
                              ),
                            ),
                          );
                        }
                      },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: SyrixColors.surfaceAlt,
                      backgroundImage: conversationAvatarUrl != null ? NetworkImage(conversationAvatarUrl!) : null,
                      child: conversationAvatarUrl == null
                          ? Icon(isGroup ? Icons.groups_rounded : Icons.person_rounded, size: 20, color: SyrixColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            conversationTitle ?? widget.title,
                            style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isGroup
                                ? (memberCount > 0 ? "$memberCount participants" : "Groupe")
                                : (otherUser?["username"] != null ? "@${otherUser!["username"]}" : "En ligne"),
                            style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        actions: searchMode
            ? [
                if (searchResultIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        "${searchResultIndex + 1}/${searchResultIds.length}",
                        style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
                IconButton(icon: const Icon(Icons.keyboard_arrow_up_rounded), onPressed: previousSearchResult),
                IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: nextSearchResult),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: closeSearch),
              ]
            : [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => setState(() => searchMode = true),
          ),
          if (isGroup)
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: openGroupSettings,
            )
          else ...[
            if (!isBot && !contactAdded)
              IconButton(
                icon: const Icon(Icons.person_add_rounded),
                tooltip: t("chat_add_contact"),
                onPressed: addContact,
              ),
            if (!isBot) ...[
              IconButton(
                icon: const Icon(Icons.call_rounded),
                onPressed: () => startCall("voice"),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_rounded),
                onPressed: () => startCall("video"),
              ),
            ],
          ],
          IconButton(
            icon: Icon(
              selfDestructSeconds > 0 ? Icons.timer_rounded : Icons.more_vert_rounded,
              color: selfDestructSeconds > 0 ? SyrixColors.primary : SyrixColors.textPrimary,
            ),
            onPressed: openChatMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            Container(
              width: double.infinity,
              color: SyrixColors.danger.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 14, color: SyrixColors.danger),
                  const SizedBox(width: 6),
                  Text(t("offline_banner"), style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11)),
                ],
              ),
            ),
          if (!loading && !isGroup && dmPrice > 0)
            Container(
              width: double.infinity,
              color: SyrixColors.primary.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                t("chat_dm_price_banner").replaceAll("{price}", "$dmPrice"),
                style: const TextStyle(color: SyrixColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
            loading
                ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final messageId = (message["id"] ?? message["_id"])?.toString();
                      messageKeys.putIfAbsent(messageId ?? "$index", () => GlobalKey());
                      final isMine = message["senderId"] == currentUserId;
                      final isGroupChat = conversationType == "group" || conversationType == "community";
                      final sender = membersById[message["senderId"]];
                      return KeyedSubtree(
                        key: messageKeys[messageId ?? "$index"],
                        child: MessageBubble(
                        messageId: messageId,
                        content: message["content"] ?? "",
                        isMine: isMine,
                        showSenderName: isGroupChat && !isMine,
                        senderName: sender?["username"],
                        senderIsPremium: sender?["isPremium"] == true,
                        type: message["type"] ?? "text",
                        pinned: message["pinned"] == true,
                        edited: message["edited"] == true,
                        spoiler: message["spoiler"] == true,
                        deletedForEveryone: message["deletedForEveryone"] == true,
                        durationSeconds: message["durationSeconds"] is int
                            ? message["durationSeconds"]
                            : int.tryParse("${message["durationSeconds"] ?? ''}"),
                        replyTo: message["replyTo"] == null
                            ? null
                            : Map<String, dynamic>.from(message["replyTo"]),
                        expireAt: message["expireAt"] as String?,
                        onExpired: () => setState(() {
                          messages.removeWhere((m) => identical(m, message));
                        }),
                        reactions: List<Map<String, dynamic>>.from(message["reactions"] ?? const []),
                        currentUserId: currentUserId,
                        localeController: widget.localeController,
                        onToggleReaction: messageId == null
                            ? null
                            : (emoji) => toggleReaction(messageId, emoji),
                        onTogglePin: messageId == null ? null : () => togglePin(messageId),
                        onTranslate: messageId == null ? null : () => translateMessage(messageId),
                        onReply: () => startReply(message),
                        onDeleteForMe: messageId == null ? null : () => deleteForMe(messageId),
                        onDeleteForEveryone: messageId == null ? null : () => deleteForEveryone(messageId),
                        onTranscribe: messageId == null ? null : () => transcribeMessage(messageId),
                        onEdit: messageId == null ? null : () => editMessage(messageId, message["content"] ?? ""),
                        onMentionTap: (username) => openMentionedProfile(username),
                        onForward: messageId == null ? null : () => forwardMessage(message["content"] ?? ""),
                      ),
                      );
                    },
                  ),
            if (activeMentionTag != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: SyrixColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: SyrixColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, color: SyrixColors.textPrimary),
                        onPressed: previousMention,
                      ),
                      Expanded(
                        child: Text(
                          "@$activeMentionTag  ${mentionIndex + 1}/${mentionMatchIds.length}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: SyrixColors.textPrimary),
                        onPressed: nextMention,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: SyrixColors.textMuted, size: 18),
                        onPressed: closeMentionNav,
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: SyrixColors.surface,
                border: Border(top: BorderSide(color: SyrixColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (quickReplySuggestions.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: quickReplySuggestions
                            .map(
                              (q) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.bolt_rounded, color: SyrixColors.primary, size: 18),
                                title: Text("/${q["shortcut"]}", style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 13)),
                                subtitle: Text(q["text"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11)),
                                onTap: () {
                                  messageController.text = q["text"] ?? "";
                                  messageController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: messageController.text.length),
                                  );
                                  setState(() => quickReplySuggestions = []);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (replyingTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(left: BorderSide(color: SyrixColors.primary, width: 3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t("chat_replying_to"),
                                  style: const TextStyle(color: SyrixColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  replyingTo!["type"] == "image"
                                      ? "\uD83D\uDDBC"
                                      : (replyingTo!["content"] ?? ""),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: SyrixColors.textMuted),
                            onPressed: cancelReply,
                          ),
                        ],
                      ),
                    ),
                  if (closedGroup && (conversationType == "group" || conversationType == "community") && !isGroupAdmin)
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: SyrixColors.textMuted),
                          const SizedBox(width: 8),
                          Text(t("group_closed_banner"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  else if (isRecording)
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: cancelRecording
                            ? SyrixColors.danger.withOpacity(0.15)
                            : SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: SyrixColors.danger, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "${(recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(recordSeconds % 60).toString().padLeft(2, '0')}",
                            style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            cancelRecording ? t("chat_slide_to_cancel") : t("chat_release_to_send"),
                            style: TextStyle(
                              color: cancelRecording ? SyrixColors.danger : SyrixColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          icon: uploadingAttachment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: SyrixColors.primary),
                                )
                              : const Icon(Icons.attach_file_rounded, color: SyrixColors.textMuted),
                          onPressed: uploadingAttachment ? null : pickAndSendAttachment,
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: SyrixColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: SyrixColors.border),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: messageController,
                              style: const TextStyle(color: SyrixColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: t("chat_message_hint"),
                                hintStyle: const TextStyle(color: SyrixColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onSubmitted: (_) => send(),
                            ),
                          ),
                        ),
                        if (!isGroup)
                          IconButton(
                            icon: const Icon(Icons.card_giftcard_rounded, color: SyrixColors.textMuted),
                            onPressed: openGiftSheet,
                          ),
                        if (hasText)
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: SyrixColors.primary),
                            onPressed: send,
                          )
                        else
                          GestureDetector(
                            onLongPressStart: (_) => startRecording(),
                            onLongPressMoveUpdate: (details) {
                              final cancelled = details.localOffsetFromOrigin.dx < -60;
                              if (cancelled != cancelRecording) {
                                setState(() => cancelRecording = cancelled);
                              }
                            },
                            onLongPressEnd: (_) => finishRecording(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: const Icon(Icons.mic_rounded, color: SyrixColors.primary),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
