import "dart:convert";
import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:image_picker/image_picker.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

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
  String selectedFilter = "original";
  final previewKey = GlobalKey();

  static const Map<String, List<double>> _filterMatrices = {
    "bw": [
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0, 0, 0, 1, 0,
    ],
    "vivid": [
      1.3, 0, 0, 0, -20,
      0, 1.3, 0, 0, -20,
      0, 0, 1.3, 0, -20,
      0, 0, 0, 1, 0,
    ],
    "retro": [
      0.9, 0.5, 0.1, 0, 0,
      0.3, 0.8, 0.1, 0, 0,
      0.2, 0.3, 0.5, 0, 0,
      0, 0, 0, 1, 0,
    ],
  };

  @override
  void initState() {
    super.initState();
    pickImage(ImageSource.gallery);
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
      if (selectedFilter != "original") {
        final captured = await captureFilteredImage();
        if (captured != null) uploadPath = captured;
      }
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
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();
      final file = File("${pickedFile!.path}_filtered.png");
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  onPressed: () => pickImage(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  onPressed: () => pickImage(ImageSource.gallery),
                ),
              ],
            ),
            Expanded(
              child: pickedFile == null
                  ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
                  : RepaintBoundary(
                      key: previewKey,
                      child: _filterMatrices.containsKey(selectedFilter)
                          ? ColorFiltered(
                              colorFilter: ColorFilter.matrix(_filterMatrices[selectedFilter]!),
                              child: Image.file(pickedFile!, fit: BoxFit.contain),
                            )
                          : Image.file(pickedFile!, fit: BoxFit.contain),
                    ),
            ),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final entry in {
                    "original": t("story_filter_original"),
                    "bw": t("story_filter_bw"),
                    "vivid": t("story_filter_vivid"),
                    "retro": t("story_filter_retro"),
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: selectedFilter == entry.key,
                        onSelected: (_) => setState(() => selectedFilter = entry.key),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: captionController,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: t("story_add_caption"),
                          hintStyle: const TextStyle(color: SyrixColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: pickedFile == null || uploading ? null : publish,
                    child: Text(uploading ? t("story_uploading") : t("story_post")),
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
