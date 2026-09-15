import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:qr_flutter/qr_flutter.dart";
import "../utils/invite_code.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/pin_service.dart";
import "../services/account_service.dart";
import "../widgets/language_switch.dart";
import "../widgets/verified_badge.dart";
import "../widgets/rich_bio_links.dart";
import "login_screen.dart";
import "edit_profile_screen.dart";
import "wallet_screen.dart";
import "set_pin_screen.dart";
import "developer_bots_screen.dart";
import "contacts_screen.dart";
import "business_tools_screen.dart";
import "catalog_screen.dart";
import "sessions_screen.dart";
import "parental_control_screen.dart";
import "vault_screen.dart";
import "personalization_screen.dart";

class ProfileScreen extends StatefulWidget {
  final LocaleController localeController;

  const ProfileScreen({super.key, required this.localeController});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? username;
  String? userId;
  String? bio;
  String? avatarUrl;
  String? bannerUrl;
  String? location;
  bool isPremium = false;
  String profileVisibility = "everyone";
  String birthDateVisibility = "hidden";
  String storyVisibility = "everyone";
  int dmPrice = 0;
  int walletBalance = 0;
  bool loading = true;
  bool pinEnabled = false;
  String userStatus = "online"; // online, idle, dnd, invisible

  void openStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Statut de présence",
                  style: TextStyle(
                    color: SyrixColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _statusTile("online", "En ligne", const Color(0xFF10B981)),
                _statusTile("idle", "Absent", const Color(0xFFF59E0B)),
                _statusTile("dnd", "Ne pas déranger", const Color(0xFFEF4444)),
                _statusTile("invisible", "Invisible", const Color(0xFF6B7280)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusTile(String code, String label, Color color) {
    final selected = userStatus == code;
    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
          ],
        ),
      ),
      title: Text(label, style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
      trailing: selected ? const Icon(Icons.check_rounded, color: SyrixColors.cyan) : null,
      onTap: () {
        setState(() => userStatus = code);
        Navigator.pop(context);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    load();
    loadPinState();
  }

  Future<void> loadPinState() async {
    final has = await PinService.hasPin();
    if (mounted) setState(() => pinEnabled = has);
  }

  Future<void> goPremium() async {
    final response = await ApiClient.createPremiumCheckout();
    if (response.statusCode != 201) return;
    final body = jsonDecode(response.body);
    final url = Uri.tryParse(body["url"] ?? "");
    if (url != null) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void showMyQrCode() {
    if (userId == null) return;
    final t = widget.localeController.t;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("profile_my_qr_code"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: QrImageView(data: "$profileQrPrefix$userId", size: 200),
            ),
            const SizedBox(height: 12),
            Text(
              t("profile_qr_hint"),
              textAlign: TextAlign.center,
              style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ApiClient.profileLink(username ?? "")));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t("profile_link_copied"))),
                );
              },
              icon: const Icon(Icons.link_rounded, size: 16),
              label: Text(t("profile_copy_link")),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> openPinScreen({required bool removeMode}) async {    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetPinScreen(
          localeController: widget.localeController,
          hasExistingPin: pinEnabled,
          removeMode: removeMode,
        ),
      ),
    );
    if (result == true) loadPinState();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("syrix_token");
    if (token == null) {
      redirectToLogin();
      return;
    }
    final response = await ApiClient.me();
    if (response.statusCode != 200) {
      redirectToLogin();
      return;
    }
    final body = jsonDecode(response.body);
    if (!mounted) return;
    setState(() {
      username = body["username"];
      userId = "${body["id"]}";
      bio = body["bio"];
      avatarUrl = body["avatarUrl"];
      bannerUrl = body["bannerUrl"];
      location = body["location"];
      isPremium = body["isPremium"] == true;
      profileVisibility = body["profileVisibility"] ?? "everyone";
      birthDateVisibility = body["birthDateVisibility"] ?? "hidden";
      storyVisibility = body["storyVisibility"] ?? "everyone";
      dmPrice = body["dmPrice"] ?? 0;
      walletBalance = body["walletBalance"] ?? 0;
      loading = false;
    });
  }

  void redirectToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(localeController: widget.localeController)),
      (route) => false,
    );
  }

  Future<void> openEditProfile() async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          localeController: widget.localeController,
          username: username ?? "",
          bio: bio,
          avatarUrl: avatarUrl,
          bannerUrl: bannerUrl,
          location: location,
          isPremium: isPremium,
          profileVisibility: profileVisibility,
          birthDateVisibility: birthDateVisibility,
          storyVisibility: storyVisibility,
          dmPrice: dmPrice,
        ),
      ),
    );
    if (updated == true) load();
  }

  Future<void> confirmLogout() async {
    final t = widget.localeController.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SyrixColors.surface,
          title: Text(t("profile_logout"), style: const TextStyle(color: SyrixColors.textPrimary)),
          content: Text(t("profile_logout_confirm"), style: const TextStyle(color: SyrixColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t("profile_cancel")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t("profile_logout")),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ApiClient.logout();
      if (userId != null) await AccountService.removeAccount(userId!);
      redirectToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: SyrixColors.primary));
    }
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (bannerUrl != null)
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(image: NetworkImage(bannerUrl!), fit: BoxFit.cover),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, SyrixColors.background.withOpacity(0.85)],
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, bannerUrl != null ? 0 : 20, 20, 0),
            child: Column(
              children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: SyrixColors.surfaceAlt,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(
                          (username ?? "").isNotEmpty ? username![0].toUpperCase() : "?",
                          style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                UsernameWithBadge(
                  username: username ?? "",
                  isPremium: isPremium,
                  badgeSize: 16,
                  style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                // Status selector pill
                GestureDetector(
                  onTap: openStatusPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SyrixColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SyrixColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: userStatus == "online"
                                ? const Color(0xFF10B981)
                                : userStatus == "idle"
                                    ? const Color(0xFFF59E0B)
                                    : userStatus == "dnd"
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          userStatus == "online"
                              ? "En ligne"
                              : userStatus == "idle"
                                  ? "Absent"
                                  : userStatus == "dnd"
                                      ? "Ne pas déranger"
                                      : "Invisible",
                          style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: SyrixColors.textMuted),
                      ],
                    ),
                  ),
                ),
                if (!isPremium) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: SyrixColors.primary)),
                    onPressed: goPremium,
                    icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: SyrixColors.primary),
                    label: Text(t("profile_go_premium"), style: const TextStyle(color: SyrixColors.primary)),
                  ),
                ],
                if (bio != null && bio!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    RichBioLinks.stripUrls(bio!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
                  ),
                ],
                if (location != null && location!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place_rounded, size: 14, color: SyrixColors.textMuted),
                      const SizedBox(width: 4),
                      Text(location!, style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ],
                if (bio != null && bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  RichBioLinks(bio: bio!),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: openEditProfile,
                      child: Text(t("profile_edit")),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: showMyQrCode,
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: Text(t("profile_my_qr_code")),
                    ),
                  ],
                ),
              ],
            ),
            ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
          GestureDetector(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WalletScreen(localeController: widget.localeController)),
              );
              load();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SyrixColors.primary, SyrixColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t("profile_wallet"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  Text("$walletBalance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(t("profile_security"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.pin_rounded, color: SyrixColors.textMuted),
                  title: Text(
                    pinEnabled ? t("profile_pin_change") : t("profile_pin_enable"),
                    style: const TextStyle(color: SyrixColors.textPrimary),
                  ),
                  subtitle: Text(t("profile_pin_hint"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                  onTap: () => openPinScreen(removeMode: false),
                ),
                if (pinEnabled) ...[
                  const Divider(height: 1, color: SyrixColors.border),
                  ListTile(
                    leading: const Icon(Icons.lock_open_rounded, color: SyrixColors.danger),
                    title: Text(t("profile_pin_disable"), style: const TextStyle(color: SyrixColors.danger)),
                    onTap: () => openPinScreen(removeMode: true),
                  ),
                ],
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.devices_rounded, color: SyrixColors.textMuted),
                  title: Text(t("sessions_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SessionsScreen(localeController: widget.localeController)),
                    );
                  },
                ),
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.family_restroom_rounded, color: SyrixColors.textMuted),
                  title: Text(t("parental_control_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ParentalControlScreen(localeController: widget.localeController)),
                    );
                  },
                ),
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.lock_rounded, color: SyrixColors.textMuted),
                  title: Text(t("vault_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => VaultGateScreen(localeController: widget.localeController)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: SyrixColors.textMuted),
              title: Text(t("contacts_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ContactsScreen(localeController: widget.localeController)),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.storefront_rounded, color: SyrixColors.textMuted),
              title: Text(t("business_tools_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BusinessToolsScreen(localeController: widget.localeController)),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined, color: SyrixColors.textMuted),
              title: Text(t("catalog_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
              onTap: () {
                if (userId == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CatalogScreen(localeController: widget.localeController, userId: userId!, isOwner: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(t("profile_developer"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.smart_toy_rounded, color: SyrixColors.textMuted),
              title: Text(t("developer_bots_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DeveloperBotsScreen(localeController: widget.localeController)),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(t("profile_settings"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: SyrixColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SyrixColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded, color: SyrixColors.cyan),
                  title: const Text("Thème de l'application", style: TextStyle(color: SyrixColors.textPrimary)),
                  subtitle: const Text("Sombre Néon Cyber (#13111C)", style: TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SyrixColors.neonPurple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SyrixColors.neonPurple.withOpacity(0.5)),
                    ),
                    child: const Text("ACTIF", style: TextStyle(color: SyrixColors.cyan, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: SyrixColors.textMuted),
                  title: Text(t("personalization_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SyrixColors.textMuted),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PersonalizationScreen(localeController: widget.localeController)),
                    );
                  },
                ),
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: SyrixColors.textMuted),
                  title: Text(t("profile_language"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  trailing: LanguageSwitch(controller: widget.localeController),
                ),
                const Divider(height: 1, color: SyrixColors.border),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: SyrixColors.danger),
                  title: Text(t("profile_logout"), style: const TextStyle(color: SyrixColors.danger)),
                  onTap: confirmLogout,
                ),
              ],
            ),
          ),
        ],
          ),
        ),
        ],
      ),
    );
  }
}
