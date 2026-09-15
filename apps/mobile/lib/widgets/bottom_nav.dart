import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class SyrixBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final LocaleController localeController;
  final int unreadNotificationsCount;

  const SyrixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.localeController,
    this.unreadNotificationsCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final t = localeController.t;
    return Container(
      decoration: const BoxDecoration(
        color: SyrixColors.surface,
        border: Border(
          top: BorderSide(color: SyrixColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildItem(
                  index: 0,
                  icon: Icons.chat_bubble_rounded,
                  label: t("nav_home"),
                ),
              ),
              Expanded(
                child: _buildItem(
                  index: 1,
                  icon: Icons.groups_rounded,
                  label: "Groupes",
                ),
              ),
              // Elevated Center Floating Live Button
              SizedBox(
                width: 72,
                child: _buildCenterLiveButton(),
              ),
              Expanded(
                child: _buildItem(
                  index: 3,
                  icon: Icons.notifications_rounded,
                  label: "Alertes",
                  badgeCount: unreadNotificationsCount,
                ),
              ),
              Expanded(
                child: _buildItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  label: "Profil",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final active = currentIndex == index;
    final color = active ? SyrixColors.cyan : SyrixColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: SyrixColors.cyan.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active top indicator bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 22 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: SyrixColors.cyan,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: SyrixColors.cyan.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 5),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: color,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: SyrixColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterLiveButton() {
    final active = currentIndex == 2;
    return GestureDetector(
      onTap: () => onTap(2),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SyrixColors.accentGradient,
                border: Border.all(
                  color: active ? Colors.white : SyrixColors.surface,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A52F3).withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: SyrixColors.cyan.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.sensors_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Text(
              "Live",
              style: TextStyle(
                fontSize: 11,
                color: active ? SyrixColors.cyan : SyrixColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
