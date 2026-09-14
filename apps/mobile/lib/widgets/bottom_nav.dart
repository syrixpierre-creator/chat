import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class SyrixBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final LocaleController localeController;

  const SyrixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.localeController,
  });

  @override
  Widget build(BuildContext context) {
    final t = localeController.t;
    return Container(
      decoration: const BoxDecoration(
        color: SyrixColors.surface,
        border: Border(top: BorderSide(color: SyrixColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.chat_bubble_rounded, t("nav_home")),
            _navItem(context, 1, Icons.explore_rounded, t("nav_explorer")),
            _liveItem(context, 2, t("nav_live")),
            _navItem(context, 3, Icons.notifications_rounded, t("nav_notifications")),
            _navItem(context, 4, Icons.person_rounded, t("nav_profile")),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int index, IconData icon, String label) {
    final active = currentIndex == index;
    final color = active ? SyrixColors.primary : SyrixColors.textMuted;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _liveItem(BuildContext context, int index, String label) {
    final active = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SyrixColors.accentGradient,
            ),
            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? SyrixColors.primary : SyrixColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
