import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class PlaceholderScreen extends StatelessWidget {
  final LocaleController localeController;
  final String label;

  const PlaceholderScreen({super.key, required this.localeController, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            localeController.t("coming_soon"),
            style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
