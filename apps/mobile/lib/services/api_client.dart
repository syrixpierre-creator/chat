import "dart:convert";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class ApiClient {
  // Surchargeable au build sans toucher ce fichier :
  //   flutter build apk --release \
  //     --dart-define=API_BASE_URL=http://TON_IP:3000/api \
  //     --dart-define=WS_URL=ws://TON_IP:3000/ws
  // scripts/build_release.sh le fait automatiquement s'il trouve
  // apps/mobile/.env.build (voir .env.build.example).
  static const String baseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:4000/api",
  );

  static String get publicOrigin => baseUrl.replaceFirst(RegExp(r"/api/?$"), "");

  static String profileLink(String username) => "$publicOrigin/u/$username";

  static String liveLink(String liveId) => "$publicOrigin/live/$liveId";
  static const String wsUrl = String.fromEnvironment(
    "WS_URL",
    defaultValue: "ws://localhost:4000/ws",
  );

  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = {"Content-Type": "application/json"};
    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("syrix_token");
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  static Future<http.Response> signup(
    String email,
    String password,
    String locale,
    DateTime birthDate,
  ) {
    return http.post(
      Uri.parse("$baseUrl/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "locale": locale,
        "birthDate": birthDate.toIso8601String(),
      }),
    );
  }

  static Future<http.Response> verifyEmail(String email, String code) {
    return http.post(
      Uri.parse("$baseUrl/auth/verify-email"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "code": code}),
    );
  }

  static Future<http.Response> checkUsername(String username) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/auth/check-username"),
      headers: headers,
      body: jsonEncode({"username": username}),
    );
  }

  static Future<http.Response> setUsername(String username) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/auth/set-username"),
      headers: headers,
      body: jsonEncode({"username": username}),
    );
  }

  static Future<http.Response> login(String email, String password) {
    return http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
  }

  static Future<http.Response> me() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/auth/me"), headers: headers);
  }

  static Future<http.Response> listChats() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats"), headers: headers);
  }

  static Future<http.Response> listStories() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/stories"), headers: headers);
  }

  static Future<http.Response> searchUsers(String query) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/users/search?q=$query"), headers: headers);
  }

  static Future<http.Response> getUserProfileById(String userId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/users/$userId/profile"), headers: headers);
  }

  static Future<http.Response> startPrivateChat(String targetUserId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/private"),
      headers: headers,
      body: jsonEncode({"targetUserId": targetUserId}),
    );
  }

  static Future<http.Response> createGroup(
    String name,
    String type,
    List<String> participantIds, {
    String? communityId,
  }) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/group"),
      headers: headers,
      body: jsonEncode({
        "name": name,
        "type": type,
        "participantIds": participantIds,
        if (communityId != null) "communityId": communityId,
      }),
    );
  }

  static Future<http.Response> listCommunityGroups(String communityId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$communityId/groups"), headers: headers);
  }

  static Future<http.Response> getNearbySuggestions() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/users/nearby"), headers: headers);
  }

  static Future<http.Response> listSessions() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/auth/sessions"), headers: headers);
  }

  static Future<http.Response> revokeSession(String sessionId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/auth/sessions/$sessionId"), headers: headers);
  }

  static Future<http.Response> revokeOtherSessions() async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/auth/sessions/revoke-others"), headers: headers);
  }

  static Future<http.Response> listCatalog(String userId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/catalog/$userId"), headers: headers);
  }

  static Future<http.Response> createProduct({
    required String name,
    String? description,
    num? price,
    String? imageUrl,
    String? launchDate,
  }) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/catalog"),
      headers: headers,
      body: jsonEncode({
        "name": name,
        "description": description,
        "price": price,
        "imageUrl": imageUrl,
        "launchDate": launchDate,
      }),
    );
  }

  static Future<http.Response> deleteProduct(String productId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/catalog/$productId"), headers: headers);
  }

  static Future<http.Response> getBusinessTools() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/users/business-tools"), headers: headers);
  }

  static Future<http.Response> updateBusinessTools({
    bool? awayEnabled,
    String? awayMessage,
    List<Map<String, String>>? quickReplies,
  }) async {
    final headers = await _headers(withAuth: true);
    final body = <String, dynamic>{};
    if (awayEnabled != null) body["awayEnabled"] = awayEnabled;
    if (awayMessage != null) body["awayMessage"] = awayMessage;
    if (quickReplies != null) body["quickReplies"] = quickReplies;
    return http.patch(
      Uri.parse("$baseUrl/users/business-tools"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> renameContact(String contactId, {String? alias, String? tag}) async {
    final headers = await _headers(withAuth: true);
    final body = <String, dynamic>{};
    if (alias != null) body["alias"] = alias;
    if (tag != null) body["tag"] = tag;
    return http.patch(
      Uri.parse("$baseUrl/contacts/$contactId"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> archiveConversation(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/archive"), headers: headers);
  }

  static Future<http.Response> unarchiveConversation(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/unarchive"), headers: headers);
  }

  static Future<http.Response> listArchivedConversations() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/archived"), headers: headers);
  }

  static Future<http.Response> listNotifications() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/notifications"), headers: headers);
  }

  static Future<http.Response> markAllNotificationsRead() async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/notifications/read-all"), headers: headers);
  }

  static Future<http.Response> listMessages(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$conversationId/messages"), headers: headers);
  }

  static Future<http.Response> sendMessage(
    String conversationId,
    String content, {
    String type = "text",
    bool spoiler = false,
    String? replyToId,
    int? durationSeconds,
  }) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/messages"),
      headers: headers,
      body: jsonEncode({
        "content": content,
        "type": type,
        "spoiler": spoiler,
        if (replyToId != null) "replyToId": replyToId,
        if (durationSeconds != null) "durationSeconds": durationSeconds,
      }),
    );
  }

  static Future<http.Response> transcribeMessage(String conversationId, String messageId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId/transcribe"),
      headers: headers,
    );
  }

  static Future<http.Response> deleteMessage(String conversationId, String messageId, String scope) async {
    final headers = await _headers(withAuth: true);
    return http.delete(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId"),
      headers: headers,
      body: jsonEncode({"scope": scope}),
    );
  }

  static Future<http.Response> editMessage(String conversationId, String messageId, String content) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId"),
      headers: headers,
      body: jsonEncode({"content": content}),
    );
  }

  static Future<http.Response> togglePinMessage(String conversationId, String messageId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId/pin"),
      headers: headers,
    );
  }

  static Future<http.Response> reactToMessage(String conversationId, String messageId, String emoji) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId/react"),
      headers: headers,
      body: jsonEncode({"emoji": emoji}),
    );
  }

  static Future<http.Response> translateMessage(String conversationId, String messageId, String targetLocale) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/messages/$messageId/translate"),
      headers: headers,
      body: jsonEncode({"targetLocale": targetLocale}),
    );
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("syrix_token");
  }

  static Future<http.StreamedResponse> uploadStoryMedia(String filePath) async {
    final headers = await _headers(withAuth: true);
    headers.remove("Content-Type");
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/stories/upload"));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    return request.send();
  }

  static Future<http.Response> createStory(String mediaUrl, String? caption) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/stories"),
      headers: headers,
      body: jsonEncode({"mediaUrl": mediaUrl, "caption": caption}),
    );
  }

  static Future<http.Response> markStoryViewed(String storyId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/stories/$storyId/view"), headers: headers);
  }

  static Future<http.Response> repostStory(String storyId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/stories/$storyId/repost"), headers: headers);
  }

  static Future<http.Response> listLive() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/live"), headers: headers);
  }

  static Future<http.Response> startLive(String title) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/live/start"),
      headers: headers,
      body: jsonEncode({"title": title}),
    );
  }

  static Future<http.Response> endLive(String liveId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/live/$liveId/end"), headers: headers);
  }

  static Future<http.Response> getLiveToken(String liveId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/live/$liveId/token"), headers: headers);
  }

  static Future<http.Response> sendLiveChatMessage(String liveId, String content) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/live/$liveId/chat"),
      headers: headers,
      body: jsonEncode({"content": content}),
    );
  }

  static Future<http.Response> listLiveChatMessages(String liveId, {String? since}) async {
    final headers = await _headers(withAuth: true);
    final uri = Uri.parse("$baseUrl/live/$liveId/chat").replace(
      queryParameters: since != null ? {"since": since} : null,
    );
    return http.get(uri, headers: headers);
  }

  static Future<http.Response> sendLiveReaction(String liveId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/live/$liveId/reaction"), headers: headers);
  }

  static Future<http.Response> sendLiveGift(String liveId, String giftId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/live/$liveId/gift"),
      headers: headers,
      body: jsonEncode({"giftId": giftId}),
    );
  }

  static Future<http.Response> updateProfile({
    String? bio,
    String? locale,
    String? profileVisibility,
    String? birthDateVisibility,
    String? storyVisibility,
    int? dmPrice,
    String? location,
  }) async {
    final headers = await _headers(withAuth: true);
    final body = <String, dynamic>{};
    if (bio != null) body["bio"] = bio;
    if (locale != null) body["locale"] = locale;
    if (profileVisibility != null) body["profileVisibility"] = profileVisibility;
    if (birthDateVisibility != null) body["birthDateVisibility"] = birthDateVisibility;
    if (storyVisibility != null) body["storyVisibility"] = storyVisibility;
    if (dmPrice != null) body["dmPrice"] = dmPrice;
    if (location != null) body["location"] = location;
    return http.patch(
      Uri.parse("$baseUrl/users/me"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.StreamedResponse> uploadAvatar(String filePath) async {
    final headers = await _headers(withAuth: true);
    headers.remove("Content-Type");
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/users/me/avatar"));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    return request.send();
  }

  static Future<http.StreamedResponse> uploadBanner(String filePath) async {
    final headers = await _headers(withAuth: true);
    headers.remove("Content-Type");
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/users/me/banner"));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    return request.send();
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("syrix_token");
  }

  static Future<http.Response> listWalletPackages() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/wallet/packages"), headers: headers);
  }

  static Future<http.Response> listWalletTransactions() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/wallet/transactions"), headers: headers);
  }

  static Future<http.Response> createWalletCheckout(String packageId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/wallet/checkout"),
      headers: headers,
      body: jsonEncode({"packageId": packageId}),
    );
  }

  static Future<http.Response> createPremiumCheckout() async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/wallet/premium-checkout"), headers: headers);
  }

  static Future<http.Response> getConversationDetails(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$conversationId"), headers: headers);
  }

  static Future<http.Response> updateConversationSettings(
    String conversationId, {
    String? name,
    bool? isPrivate,
    int? messagePrice,
    String? description,
  }) async {
    final headers = await _headers(withAuth: true);
    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (isPrivate != null) body["isPrivate"] = isPrivate;
    if (messagePrice != null) body["messagePrice"] = messagePrice;
    if (description != null) body["description"] = description;
    return http.patch(
      Uri.parse("$baseUrl/chats/$conversationId/settings"),
      headers: headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.StreamedResponse> uploadGroupPhoto(String conversationId, String filePath) async {
    final headers = await _headers(withAuth: true);
    headers.remove("Content-Type");
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/chats/$conversationId/photo"));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    return request.send();
  }

  static Future<http.Response> updateSelfDestruct(String conversationId, int seconds) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/chats/$conversationId/self-destruct"),
      headers: headers,
      body: jsonEncode({"seconds": seconds}),
    );
  }

  static Future<http.Response> updateModeration(String conversationId, bool enabled) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/chats/$conversationId/moderation"),
      headers: headers,
      body: jsonEncode({"enabled": enabled}),
    );
  }

  static Future<http.Response> updateClosedGroup(String conversationId, bool closed) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/chats/$conversationId/closed"),
      headers: headers,
      body: jsonEncode({"closed": closed}),
    );
  }

  static Future<http.Response> listMembers(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$conversationId/members"), headers: headers);
  }

  static Future<http.Response> promoteMember(String conversationId, String memberId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/members/$memberId/promote"), headers: headers);
  }

  static Future<http.Response> demoteMember(String conversationId, String memberId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/members/$memberId/demote"), headers: headers);
  }

  static Future<http.Response> kickMember(String conversationId, String memberId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/members/$memberId/kick"), headers: headers);
  }

  static Future<http.Response> banMember(String conversationId, String memberId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/members/$memberId/ban"), headers: headers);
  }

  static Future<http.Response> leaveGroup(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/leave"), headers: headers);
  }

  static Future<http.Response> transferOwnership(String conversationId, String newOwnerId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/chats/$conversationId/transfer-ownership"),
      headers: headers,
      body: jsonEncode({"newOwnerId": newOwnerId}),
    );
  }

  static Future<http.Response> getAuditLog(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$conversationId/audit-log"), headers: headers);
  }

  static Future<http.Response> getLeaderboard(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/chats/$conversationId/leaderboard"), headers: headers);
  }

  static Future<http.Response> listBots() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/bots"), headers: headers);
  }

  static Future<http.Response> createBot(String name) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/bots"),
      headers: headers,
      body: jsonEncode({"name": name}),
    );
  }

  static Future<http.Response> updateBotWebhook(String botId, String? webhookUrl) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/bots/$botId/webhook"),
      headers: headers,
      body: jsonEncode({"webhookUrl": webhookUrl}),
    );
  }

  static Future<http.Response> regenerateBotToken(String botId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/bots/$botId/regenerate-token"), headers: headers);
  }

  static Future<http.Response> deleteBot(String botId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/bots/$botId"), headers: headers);
  }

  static Future<http.Response> listNotes() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/notes"), headers: headers);
  }

  static Future<http.Response> createNote(String content) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/notes"), headers: headers, body: jsonEncode({"content": content}));
  }

  static Future<http.Response> updateNote(String noteId, String content) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/notes/$noteId"),
      headers: headers,
      body: jsonEncode({"content": content}),
    );
  }

  static Future<http.Response> deleteNote(String noteId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/notes/$noteId"), headers: headers);
  }

  static Future<http.Response> listFolders() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/folders"), headers: headers);
  }

  static Future<http.Response> createFolder(String name) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/folders"), headers: headers, body: jsonEncode({"name": name}));
  }

  static Future<http.Response> renameFolder(String folderId, String name) async {
    final headers = await _headers(withAuth: true);
    return http.patch(
      Uri.parse("$baseUrl/folders/$folderId"),
      headers: headers,
      body: jsonEncode({"name": name}),
    );
  }

  static Future<http.Response> deleteFolder(String folderId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/folders/$folderId"), headers: headers);
  }

  static Future<http.Response> addConversationToFolder(String folderId, String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/folders/$folderId/conversations/$conversationId"), headers: headers);
  }

  static Future<http.Response> removeConversationFromFolder(String folderId, String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/folders/$folderId/conversations/$conversationId"), headers: headers);
  }

  static Future<http.Response> regenerateInviteLink(String conversationId) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/$conversationId/invite/regenerate"), headers: headers);
  }

  static Future<http.Response> joinByInviteCode(String inviteCode) async {
    final headers = await _headers(withAuth: true);
    return http.post(Uri.parse("$baseUrl/chats/join/$inviteCode"), headers: headers);
  }

  static Future<http.Response> addContact(String contactId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/contacts"),
      headers: headers,
      body: jsonEncode({"contactId": contactId}),
    );
  }

  static Future<http.Response> removeContact(String contactId) async {
    final headers = await _headers(withAuth: true);
    return http.delete(Uri.parse("$baseUrl/contacts/$contactId"), headers: headers);
  }

  static Future<http.Response> listContacts() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/contacts"), headers: headers);
  }

  static Future<http.Response> getUserPublicProfile(String userId) async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/users/$userId/profile"), headers: headers);
  }

  static Future<http.StreamedResponse> uploadChatMedia(String filePath) async {
    final headers = await _headers(withAuth: true);
    headers.remove("Content-Type");
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/uploads/chat-media"));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    return request.send();
  }

  static Future<http.Response> listGifts() async {
    final headers = await _headers(withAuth: true);
    return http.get(Uri.parse("$baseUrl/gifts"), headers: headers);
  }

  static Future<http.Response> sendGift(String conversationId, String giftId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/gifts/send"),
      headers: headers,
      body: jsonEncode({"conversationId": conversationId, "giftId": giftId}),
    );
  }

  static Future<http.Response> initiateCall(String conversationId, String mode) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/calls/initiate"),
      headers: headers,
      body: jsonEncode({"conversationId": conversationId, "mode": mode}),
    );
  }

  static Future<http.Response> answerCall(String roomName) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/calls/answer"),
      headers: headers,
      body: jsonEncode({"roomName": roomName}),
    );
  }

  static Future<http.Response> declineCall(String roomName, String toUserId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/calls/decline"),
      headers: headers,
      body: jsonEncode({"roomName": roomName, "toUserId": toUserId}),
    );
  }

  static Future<http.Response> endCall(String roomName, String toUserId) async {
    final headers = await _headers(withAuth: true);
    return http.post(
      Uri.parse("$baseUrl/calls/end"),
      headers: headers,
      body: jsonEncode({"roomName": roomName, "toUserId": toUserId}),
    );
  }
}
