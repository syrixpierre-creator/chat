import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class LanguageSwitch extends StatelessWidget {
  final LocaleController controller;

  const LanguageSwitch({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: SyrixColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: SyrixColors.border),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _langButton(context, "EN", "en"),
              _langButton(context, "FR", "fr"),
            ],
          ),
        );
      },
    );
  }

  Widget _langButton(BuildContext context, String label, String code) {
    final active = controller.locale == code;
    return GestureDetector(
      onTap: () => controller.setLocale(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? SyrixColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : SyrixColors.textMuted,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
