import "dart:convert";
import "dart:io";
import "dart:math" as math;
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:image_picker/image_picker.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/offline_cache.dart";

class CreateStoryScreen extends StatefulWidget {
  final LocaleController localeController;

  const CreateStoryScreen({super.key, required this.localeController});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? pickedFile;
  final captionController = TextEditingController();
  bool uploading = false;
  String selectedFilterId = "original";
  final previewKey = GlobalKey();

  // Text overlay features
  String? textOverlay;
  Color textColor = Colors.white;
  Offset textPosition = const Offset(50, 150);
  bool isEditingText = false;

  // Custom filters list loaded from cache
  List<Map<String, dynamic>> customFilters = [];

  // Built-in filter presets
  static const Map<String, Map<String, dynamic>> _presetFilters = {
    "original": {"name": "Original", "matrix": null},
    "bw": {
      "name": "B & W",
      "matrix": [
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0, 0, 0, 1, 0,
      ]
    },
    "vivid": {
      "name": "Vif",
      "matrix": [
        1.3, 0, 0, 0, -15,
        0, 1.3, 0, 0, -15,
        0, 0, 1.3, 0, -15,
        0, 0, 0, 1, 0,
      ]
    },
    "retro": {
      "name": "Rétro",
      "matrix": [
        0.9, 0.5, 0.1, 0, 0,
        0.3, 0.8, 0.1, 0, 0,
        0.2, 0.3, 0.5, 0, 0,
        0, 0, 0, 1, 0,
      ]
    },
    "cyberpunk": {
      "name": "Cyber",
      "matrix": [
        1.2, 0.1, 0.2, 0, 20,
        0.0, 0.9, 0.4, 0, -10,
        0.3, 0.1, 1.5, 0, 30,
        0, 0, 0, 1, 0,
      ]
    },
    "golden": {
      "name": "Golden",
      "matrix": [
        1.3, 0.2, 0.0, 0, 25,
        0.1, 1.1, 0.0, 0, 15,
        0.0, 0.0, 0.8, 0, -10,
        0, 0, 0, 1, 0,
      ]
    },
    "cool": {
      "name": "Cool Ice",
      "matrix": [
        0.8, 0.0, 0.2, 0, -15,
        0.1, 1.0, 0.2, 0, 5,
        0.1, 0.2, 1.4, 0, 35,
        0, 0, 0, 1, 0,
      ]
    },
  };

  @override
  void initState() {
    super.initState();
    loadCustomFilters();
    pickImage(ImageSource.gallery);
  }

  Future<void> loadCustomFilters() async {
    final cached = await OfflineCache.loadJson("user_custom_story_filters");
    if (cached != null && cached is List) {
      setState(() {
        customFilters = List<Map<String, dynamic>>.from(cached);
      });
    }
  }

  Future<void> saveCustomFilter(Map<String, dynamic> filter) async {
    final updated = List<Map<String, dynamic>>.from(customFilters)..add(filter);
    setState(() {
      customFilters = updated;
      selectedFilterId = filter["id"];
    });
    await OfflineCache.saveJson("user_custom_story_filters", updated);
  }

  Future<void> deleteCustomFilter(String id) async {
    final updated = customFilters.where((f) => f["id"] != id).toList();
    setState(() {
      customFilters = updated;
      if (selectedFilterId == id) selectedFilterId = "original";
    });
    await OfflineCache.saveJson("user_custom_story_filters", updated);
  }

  static List<double> computeFilterMatrix({
    double brightness = 0.0, // -50 .. 50
    double contrast = 1.0,   // 0.5 .. 2.0
    double saturation = 1.0, // 0.0 .. 2.5
    double warmth = 0.0,     // -40 .. 40
  }) {
    const lumR = 0.3086;
    const lumG = 0.6094;
    const lumB = 0.0820;

    final sr = (1.0 - saturation) * lumR;
    final sg = (1.0 - saturation) * lumG;
    final sb = (1.0 - saturation) * lumB;

    final cShift = 128.0 * (1.0 - contrast);

    return [
      (sr + saturation) * contrast, sg * contrast, sb * contrast, 0, cShift + brightness + warmth,
      sr * contrast, (sg + saturation) * contrast, sb * contrast, 0, cShift + brightness,
      sr * contrast, sg * contrast, (sb + saturation) * contrast, 0, cShift + brightness - warmth,
      0, 0, 0, 1, 0,
    ];
  }

  List<double>? get currentMatrix {
    if (_presetFilters.containsKey(selectedFilterId)) {
      final m = _presetFilters[selectedFilterId]!["matrix"];
      return m != null ? List<double>.from(m) : null;
    }
    final match = customFilters.firstWhere((f) => f["id"] == selectedFilterId, orElse: () => {});
    if (match.isNotEmpty) {
      return computeFilterMatrix(
        brightness: (match["brightness"] as num?)?.toDouble() ?? 0.0,
        contrast: (match["contrast"] as num?)?.toDouble() ?? 1.0,
        saturation: (match["saturation"] as num?)?.toDouble() ?? 1.0,
        warmth: (match["warmth"] as num?)?.toDouble() ?? 0.0,
      );
    }
    return null;
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: source, imageQuality: 85);
    if (result == null) {
      if (pickedFile == null && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => pickedFile = File(result.path));
  }

  Future<void> publish() async {
    if (pickedFile == null) return;
    setState(() => uploading = true);
    try {
      String uploadPath = pickedFile!.path;
      final captured = await captureFilteredImage();
      if (captured != null) uploadPath = captured;

      final uploadResponse = await ApiClient.uploadStoryMedia(uploadPath);
      final body = jsonDecode(await uploadResponse.stream.bytesToString());
      if (uploadResponse.statusCode != 201) return;
      await ApiClient.createStory(body["url"], captionController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<String?> captureFilteredImage() async {
    try {
      final boundary = previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();
      final file = File("${pickedFile!.path}_story_export.png");
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void openCreateFilterDialog() {
    final t = widget.localeController.t;
    double brightness = 0;
    double contrast = 1.0;
    double saturation = 1.0;
    double warmth = 0;
    final nameCtrl = TextEditingController(text: "Mon Filtre ${customFilters.length + 1}");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final liveMatrix = computeFilterMatrix(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            warmth: warmth,
          );

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2028),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t("story_custom_filter_title"),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Mini Live Preview
                  if (pickedFile != null)
                    Center(
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SyrixColors.primary, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(liveMatrix),
                          child: Image.file(pickedFile!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: t("story_filter_name_hint"),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.palette_rounded, color: SyrixColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Luminosité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t("story_brightness"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text("${brightness.toInt()}", style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: brightness,
                    min: -50,
                    max: 50,
                    activeColor: SyrixColors.primary,
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setModalState(() => brightness = v),
                  ),

                  // Contraste
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t("story_contrast"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(contrast.toStringAsFixed(2), style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: contrast,
                    min: 0.5,
                    max: 2.0,
                    activeColor: SyrixColors.primary,
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setModalState(() => contrast = v),
                  ),

                  // Saturation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t("story_saturation"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(saturation.toStringAsFixed(2), style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: saturation,
                    min: 0.0,
                    max: 2.5,
                    activeColor: SyrixColors.primary,
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setModalState(() => saturation = v),
                  ),

                  // Chaleur
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t("story_warmth"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text("${warmth.toInt()}", style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: warmth,
                    min: -40,
                    max: 40,
                    activeColor: Colors.orangeAccent,
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setModalState(() => warmth = v),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SyrixColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final filterName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : "Filtre Perso";
                        final newFilter = {
                          "id": "custom_${DateTime.now().millisecondsSinceEpoch}",
                          "name": filterName,
                          "brightness": brightness,
                          "contrast": contrast,
                          "saturation": saturation,
                          "warmth": warmth,
                        };
                        saveCustomFilter(newFilter);
                        Navigator.pop(context);
                      },
                      child: Text(t("story_apply_filter"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void openTextEditor() {
    final t = widget.localeController.t;
    final textCtrl = TextEditingController(text: textOverlay ?? "");
    Color selectedColor = textColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2028),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t("story_text_prompt"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          textOverlay = textCtrl.text.trim().isNotEmpty ? textCtrl.text.trim() : null;
                          textColor = selectedColor;
                        });
                        Navigator.pop(context);
                      },
                      child: Text(t("story_text_done"), style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                TextField(
                  controller: textCtrl,
                  autofocus: true,
                  style: TextStyle(color: selectedColor, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Écrivez ici...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                // Color palette
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final c in [Colors.white, SyrixColors.primary, const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFEF4444), const Color(0xFFEC4899), const Color(0xFF8B5CF6)])
                      GestureDetector(
                        onTap: () => setModalState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == c ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final activeMatrix = currentMatrix;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Image Preview with matrix filter & draggable text overlay
            Positioned.fill(
              child: pickedFile == null
                  ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
                  : RepaintBoundary(
                      key: previewKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          activeMatrix != null
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.matrix(activeMatrix),
                                  child: Image.file(pickedFile!, fit: BoxFit.contain),
                                )
                              : Image.file(pickedFile!, fit: BoxFit.contain),

                          // Text Overlay
                          if (textOverlay != null && textOverlay!.isNotEmpty)
                            Positioned(
                              left: textPosition.dx,
                              top: textPosition.dy,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    textPosition = Offset(
                                      (textPosition.dx + details.delta.dx).clamp(10, 300),
                                      (textPosition.dy + details.delta.dy).clamp(60, 500),
                                    );
                                  });
                                },
                                onTap: openTextEditor,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: textColor.withOpacity(0.4), width: 1.5),
                                  ),
                                  child: Text(
                                    textOverlay!,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),

            // Top Floating Navigation & Action Bar (WhatsApp / Instagram style)
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _buildCircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _buildCircleButton(
                    icon: Icons.title_rounded,
                    tooltip: t("story_text_tool"),
                    onTap: openTextEditor,
                  ),
                  const SizedBox(width: 8),
                  _buildCircleButton(
                    icon: Icons.tune_rounded,
                    tooltip: t("story_filter_custom_create"),
                    onTap: openCreateFilterDialog,
                  ),
                  const SizedBox(width: 8),
                  _buildCircleButton(
                    icon: Icons.camera_alt_rounded,
                    onTap: () => pickImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 8),
                  _buildCircleButton(
                    icon: Icons.photo_library_rounded,
                    onTap: () => pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),

            // Bottom Filter Carousel & Caption Publisher
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Horizontal Filter Bar with "+ Créer" chip
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        children: [
                          // "+ Créer filtre" Action Button
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              backgroundColor: SyrixColors.primary.withOpacity(0.2),
                              side: const BorderSide(color: SyrixColors.primary, width: 1.5),
                              avatar: const Icon(Icons.add_rounded, color: SyrixColors.primary, size: 18),
                              label: Text(
                                t("story_filter_custom_create"),
                                style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: openCreateFilterDialog,
                            ),
                          ),

                          // Built-in presets
                          for (final entry in _presetFilters.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(entry.value["name"]),
                                selected: selectedFilterId == entry.key,
                                selectedColor: SyrixColors.primary,
                                backgroundColor: Colors.white12,
                                labelStyle: TextStyle(
                                  color: selectedFilterId == entry.key ? Colors.white : Colors.white70,
                                  fontWeight: selectedFilterId == entry.key ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => selectedFilterId = entry.key),
                              ),
                            ),

                          // User Custom Filters
                          for (final custom in customFilters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: SyrixColors.surface,
                                      title: Text(custom["name"] ?? "Filtre", style: const TextStyle(color: SyrixColors.textPrimary)),
                                      content: const Text("Supprimer ce filtre personnalisé ?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: Text(t("profile_cancel"))),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.danger),
                                          onPressed: () {
                                            deleteCustomFilter(custom["id"]);
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Supprimer"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: ChoiceChip(
                                  avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.amberAccent),
                                  label: Text(custom["name"] ?? "Filtre"),
                                  selected: selectedFilterId == custom["id"],
                                  selectedColor: const Color(0xFFF59E0B),
                                  backgroundColor: Colors.white12,
                                  labelStyle: TextStyle(
                                    color: selectedFilterId == custom["id"] ? Colors.black : Colors.white70,
                                    fontWeight: selectedFilterId == custom["id"] ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => setState(() => selectedFilterId = custom["id"]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Caption and Send button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white24),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: captionController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: t("story_add_caption"),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: pickedFile == null || uploading ? null : publish,
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [SyrixColors.primary, SyrixColors.primary.withOpacity(0.8)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: SyrixColors.primary.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: uploading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap, String? tooltip}) {
    return Tooltip(
      message: tooltip ?? "",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
