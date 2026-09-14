import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class StoryBar extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  final String? currentUserId;
  final LocaleController localeController;
  final VoidCallback onMyStoryTap;
  final ValueChanged<int> onStoryGroupTap;

  const StoryBar({
    super.key,
    required this.stories,
    this.currentUserId,
    required this.localeController,
    required this.onMyStoryTap,
    required this.onStoryGroupTap,
  });

  bool _allViewed(Map<String, dynamic> story) {
    if (currentUserId == null) return false;
    final items = List<Map<String, dynamic>>.from(story["items"] ?? []);
    if (items.isEmpty) return false;
    return items.every((item) => List<String>.from(item["viewedBy"] ?? []).contains(currentUserId));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAvatar(
              onTap: onMyStoryTap,
              label: localeController.t("story_my_story"),
              initial: "+",
              gradient: false,
              showAddBadge: true,
            );
          }
          final story = stories[index - 1];
          return _buildAvatar(
            onTap: () => onStoryGroupTap(index - 1),
            label: story["username"] ?? "",
            initial: (story["username"] as String).isNotEmpty
                ? (story["username"] as String)[0].toUpperCase()
                : "?",
            avatarUrl: story["avatarUrl"],
            gradient: !_allViewed(story),
            showAddBadge: false,
          );
        },
      ),
    );
  }

  Widget _buildAvatar({
    required VoidCallback onTap,
    required String label,
    required String initial,
    String? avatarUrl,
    required bool gradient,
    required bool showAddBadge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient ? SyrixColors.accentGradient : null,
                    border: gradient ? null : Border.all(color: SyrixColors.border),
                  ),
                  child: CircleAvatar(
                    backgroundColor: SyrixColors.surfaceAlt,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                if (showAddBadge)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: SyrixColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
