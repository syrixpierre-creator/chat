import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/verified_badge.dart";
import "username_selection_screen.dart";

class EditProfileScreen extends StatefulWidget {
  final LocaleController localeController;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? location;
  final bool isPremium;
  final String profileVisibility;
  final String birthDateVisibility;
  final String storyVisibility;
  final int dmPrice;

  const EditProfileScreen({
    super.key,
    required this.localeController,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.bannerUrl,
    this.location,
    this.isPremium = false,
    this.profileVisibility = "everyone",
    this.birthDateVisibility = "hidden",
    this.storyVisibility = "everyone",
    this.dmPrice = 0,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController bioController;
  late final TextEditingController dmPriceController;
  late final TextEditingController locationController;
  late String profileVisibility;
  late String birthDateVisibility;
  late String storyVisibility;
  late String username;
  String? avatarUrl;
  String? bannerUrl;
  File? pickedAvatar;
  File? pickedBanner;
  bool saving = false;
  List<String> locationSuggestions = [];
  Timer? locationDebounce;

  Future<void> searchLocation(String query) async {
    locationDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => locationSuggestions = []);
      return;
    }
    locationDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final uri = Uri.parse(
          "https://nominatim.openstreetmap.org/search?format=json&limit=5&addressdetails=1&q=${Uri.encodeComponent(query)}",
        );
        final response = await http.get(uri, headers: {"User-Agent": "SyrixChat/1.0"});
        if (response.statusCode != 200) return;
        final results = List<dynamic>.from(jsonDecode(response.body));
        final names = results
            .map((r) {
              final address = r["address"] ?? {};
              final city = address["city"] ?? address["town"] ?? address["village"] ?? address["county"];
              final country = address["country"];
              if (city != null && country != null) return "$city, $country";
              return r["display_name"]?.toString().split(",").take(2).join(",").trim();
            })
            .whereType<String>()
            .toSet()
            .toList();
        if (mounted) setState(() => locationSuggestions = names);
      } catch (_) {}
    });
  }

  @override
  void initState() {
    super.initState();
    bioController = TextEditingController(text: widget.bio ?? "");
    dmPriceController = TextEditingController(text: widget.dmPrice.toString());
    locationController = TextEditingController(text: widget.location ?? "");
    profileVisibility = widget.profileVisibility;
    birthDateVisibility = widget.birthDateVisibility;
    storyVisibility = widget.storyVisibility;
    avatarUrl = widget.avatarUrl;
    bannerUrl = widget.bannerUrl;
    username = widget.username;
  }

  Future<void> pickBanner() async {
    if (!widget.isPremium) return;
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (result == null) return;
    setState(() => pickedBanner = File(result.path));
  }

  Future<void> changeUsername() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UsernameSelectionScreen(
          localeController: widget.localeController,
          isOnboarding: false,
          currentUsername: username,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => username = result);
    }
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (result == null) return;
    setState(() => pickedAvatar = File(result.path));
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      if (pickedAvatar != null) {
        final uploadResponse = await ApiClient.uploadAvatar(pickedAvatar!.path);
        final body = jsonDecode(await uploadResponse.stream.bytesToString());
        if (uploadResponse.statusCode == 201) {
          avatarUrl = body["avatarUrl"];
        }
      }
      if (pickedBanner != null && widget.isPremium) {
        final uploadResponse = await ApiClient.uploadBanner(pickedBanner!.path);
        final body = jsonDecode(await uploadResponse.stream.bytesToString());
        if (uploadResponse.statusCode == 201) {
          bannerUrl = body["bannerUrl"];
        }
      }
      final dmPrice = int.tryParse(dmPriceController.text.trim()) ?? 0;
      await ApiClient.updateProfile(
        bio: bioController.text.trim(),
        profileVisibility: profileVisibility,
        birthDateVisibility: birthDateVisibility,
        storyVisibility: storyVisibility,
        dmPrice: dmPrice,
        location: widget.isPremium ? locationController.text.trim() : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("profile_edit"), style: const TextStyle(color: SyrixColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: Text(t("profile_save")),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GestureDetector(
              onTap: widget.isPremium ? pickBanner : null,
              child: Container(
                height: 120,
                width: double.infinity,
                color: SyrixColors.surfaceAlt,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pickedBanner != null)
                      Image.file(pickedBanner!, fit: BoxFit.cover)
                    else if (bannerUrl != null)
                      Image.network(bannerUrl!, fit: BoxFit.cover),
                    if (widget.isPremium)
                      const Positioned(
                        bottom: 8,
                        right: 8,
                        child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      )
                    else
                      Center(
                        child: Text(
                          t("profile_banner_premium_only"),
                          style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
            Center(
              child: GestureDetector(
                onTap: pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: SyrixColors.surfaceAlt,
                      backgroundImage: pickedAvatar != null
                          ? FileImage(pickedAvatar!)
                          : (avatarUrl != null ? NetworkImage(avatarUrl!) : null) as ImageProvider?,
                      child: pickedAvatar == null && avatarUrl == null
                          ? Text(
                              widget.username.isNotEmpty ? widget.username[0].toUpperCase() : "?",
                              style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: SyrixColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(t("profile_change_photo"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
            ),
            const SizedBox(height: 28),
            Text(t("username_hint"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: changeUsername,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: SyrixColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SyrixColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text("@$username", style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 15)),
                    ),
                    const Icon(Icons.edit_rounded, color: SyrixColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(t("profile_bio_label"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: bioController,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                hintText: t("profile_bio_hint"),
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(t("profile_location_label"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
                if (widget.isPremium) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 12),
                ],
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: locationController,
              enabled: widget.isPremium,
              onChanged: widget.isPremium ? searchLocation : null,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.isPremium ? t("profile_location_hint") : t("profile_banner_premium_only"),
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
              ),
            ),
            if (locationSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: locationSuggestions
                    .map(
                      (s) => ActionChip(
                        backgroundColor: SyrixColors.surfaceAlt,
                        side: const BorderSide(color: SyrixColors.border),
                        label: Text(s, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 12)),
                        onPressed: () {
                          locationController.text = s;
                          setState(() => locationSuggestions = []);
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(t("profile_visibility"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: "everyone",
                    groupValue: profileVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_everyone"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => profileVisibility = value!),
                  ),
                  RadioListTile<String>(
                    value: "contacts",
                    groupValue: profileVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_contacts"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => profileVisibility = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(t("privacy_birthdate"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: "hidden",
                    groupValue: birthDateVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("privacy_hidden"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => birthDateVisibility = value!),
                  ),
                  RadioListTile<String>(
                    value: "contacts",
                    groupValue: birthDateVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_contacts"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => birthDateVisibility = value!),
                  ),
                  RadioListTile<String>(
                    value: "everyone",
                    groupValue: birthDateVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_everyone"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => birthDateVisibility = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(t("privacy_stories"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: SyrixColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SyrixColors.border),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: "everyone",
                    groupValue: storyVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_everyone"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => storyVisibility = value!),
                  ),
                  RadioListTile<String>(
                    value: "contacts",
                    groupValue: storyVisibility,
                    activeColor: SyrixColors.primary,
                    title: Text(t("profile_visibility_contacts"), style: const TextStyle(color: SyrixColors.textPrimary)),
                    onChanged: (value) => setState(() => storyVisibility = value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(t("profile_dm_price"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: dmPriceController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: SyrixColors.textPrimary),
              decoration: InputDecoration(
                hintText: t("profile_dm_price_hint"),
                filled: true,
                fillColor: SyrixColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: SyrixColors.border)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t("profile_dm_price_helper"),
              style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
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
