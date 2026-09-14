import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/verified_badge.dart";
import "../widgets/rich_bio_links.dart";
import "catalog_screen.dart";
import "chat_screen.dart";

class UserProfileScreen extends StatefulWidget {
  final LocaleController localeController;
  final String userId;

  const UserProfileScreen({super.key, required this.localeController, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;
  bool contactAdded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.getUserProfileById(widget.userId);
    if (response.statusCode == 200) {
      profile = jsonDecode(response.body);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> addContact() async {
    final response = await ApiClient.addContact(widget.userId);
    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() => contactAdded = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("chat_contact_added"))),
        );
      }
    }
  }

  Future<void> startChat() async {
    final response = await ApiClient.startPrivateChat(widget.userId);
    if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
      final body = jsonDecode(response.body);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            localeController: widget.localeController,
            conversationId: body["id"].toString(),
            title: profile?["username"] ?? "",
          ),
        ),
      );
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
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : profile == null
              ? Center(child: Text(t("join_group_error"), style: const TextStyle(color: SyrixColors.textMuted)))
              : SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (profile!["bannerUrl"] != null)
                        Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            image: DecorationImage(image: NetworkImage(profile!["bannerUrl"]), fit: BoxFit.cover),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: SyrixColors.surfaceAlt,
                          backgroundImage: profile!["avatarUrl"] != null ? NetworkImage(profile!["avatarUrl"]) : null,
                          child: profile!["avatarUrl"] == null
                              ? Text(
                                  (profile!["username"] ?? "").isNotEmpty ? profile!["username"][0].toUpperCase() : "?",
                                  style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 32),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        UsernameWithBadge(
                          username: "@${profile!["username"] ?? ""}",
                          isPremium: profile!["isPremium"] == true,
                          badgeSize: 16,
                          style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        if (profile!["bio"] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            RichBioLinks.stripUrls(profile!["bio"]),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: SyrixColors.textMuted),
                          ),
                        ],
                        if (profile!["location"] != null && (profile!["location"] as String).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded, size: 14, color: SyrixColors.textMuted),
                              const SizedBox(width: 4),
                              Text(profile!["location"], style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ],
                        if (profile!["bio"] != null) ...[
                          const SizedBox(height: 10),
                          RichBioLinks(bio: profile!["bio"]),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: startChat,
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: Text(t("user_profile_message")),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: contactAdded ? null : addContact,
                              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                              label: Text(contactAdded ? t("chat_contact_added") : t("chat_add_contact")),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CatalogScreen(localeController: widget.localeController, userId: widget.userId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.storefront_outlined, size: 16),
                          label: Text(t("catalog_title")),
                        ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
