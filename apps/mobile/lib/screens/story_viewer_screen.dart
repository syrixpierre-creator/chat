import "dart:async";
import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";
import "package:gallery_saver_plus/gallery_saver.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/verified_badge.dart";

class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> storyGroups;
  final int initialGroupIndex;
  final bool currentUserIsPremium;
  final LocaleController localeController;

  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    required this.initialGroupIndex,
    required this.localeController,
    this.currentUserIsPremium = false,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late int groupIndex;
  int itemIndex = 0;
  Timer? timer;
  double progress = 0;
  bool reposting = false;
  bool downloading = false;
  static const Duration itemDuration = Duration(seconds: 5);
  static const Duration tickInterval = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    groupIndex = widget.initialGroupIndex;
    startTimer();
    markViewed();
  }

  List<dynamic> get currentItems => widget.storyGroups[groupIndex]["items"];

  void startTimer() {
    timer?.cancel();
    progress = 0;
    timer = Timer.periodic(tickInterval, (t) {
      setState(() {
        progress += tickInterval.inMilliseconds / itemDuration.inMilliseconds;
      });
      if (progress >= 1) {
        nextItem();
      }
    });
  }

  void markViewed() {
    final story = currentItems[itemIndex];
    ApiClient.markStoryViewed(story["_id"].toString());
  }

  Future<void> repostCurrentStory() async {
    if (!widget.currentUserIsPremium || reposting) return;
    setState(() => reposting = true);
    timer?.cancel();
    try {
      final story = currentItems[itemIndex];
      final response = await ApiClient.repostStory(story["_id"].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 201
                  ? widget.localeController.t("story_repost_success")
                  : widget.localeController.t("story_repost_failed"),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => reposting = false);
      startTimer();
    }
  }

  Future<void> downloadCurrentStory() async {
    if (!widget.currentUserIsPremium || downloading) return;
    setState(() => downloading = true);
    timer?.cancel();
    try {
      final story = currentItems[itemIndex];
      final url = story["mediaUrl"] as String;
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final extension = url.toLowerCase().contains(".mp4") ? "mp4" : "jpg";
      final filePath = "${dir.path}/syrix_story_${DateTime.now().millisecondsSinceEpoch}.$extension";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      if (extension == "mp4") {
        await GallerySaver.saveVideo(filePath);
      } else {
        await GallerySaver.saveImage(filePath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("story_download_success"))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.localeController.t("story_download_failed"))),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = false);
      startTimer();
    }
  }

  void nextItem() {
    if (itemIndex < currentItems.length - 1) {
      setState(() => itemIndex++);
      startTimer();
      markViewed();
    } else {
      nextGroup();
    }
  }

  void previousItem() {
    if (itemIndex > 0) {
      setState(() => itemIndex--);
      startTimer();
      markViewed();
    } else {
      previousGroup();
    }
  }

  void nextGroup() {
    if (groupIndex < widget.storyGroups.length - 1) {
      setState(() {
        groupIndex++;
        itemIndex = 0;
      });
      startTimer();
      markViewed();
    } else {
      Navigator.of(context).pop();
    }
  }

  void previousGroup() {
    if (groupIndex > 0) {
      setState(() {
        groupIndex--;
        itemIndex = currentItems.length - 1;
      });
      startTimer();
      markViewed();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.storyGroups[groupIndex];
    final story = currentItems[itemIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                story["mediaUrl"],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(color: SyrixColors.surfaceAlt),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  for (int i = 0; i < currentItems.length; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: i < itemIndex ? 1 : (i == itemIndex ? progress.clamp(0, 1) : 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: SyrixColors.surfaceAlt,
                    child: Text(
                      (group["username"] as String).isNotEmpty
                          ? (group["username"] as String)[0].toUpperCase()
                          : "?",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  UsernameWithBadge(
                    username: group["username"],
                    isPremium: group["isPremium"] == true,
                    badgeSize: 13,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: previousItem,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: nextItem,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.currentUserIsPremium)
              Positioned(
                bottom: 20,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StoryActionButton(
                      icon: Icons.repeat_rounded,
                      label: widget.localeController.t("story_repost"),
                      loading: reposting,
                      onTap: repostCurrentStory,
                    ),
                    const SizedBox(width: 16),
                    _StoryActionButton(
                      icon: Icons.file_download_rounded,
                      label: widget.localeController.t("story_download"),
                      loading: downloading,
                      onTap: downloadCurrentStory,
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

class _StoryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _StoryActionButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
