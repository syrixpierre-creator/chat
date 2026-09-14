import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/personalization_service.dart";

class PersonalizationScreen extends StatefulWidget {
  final LocaleController localeController;

  const PersonalizationScreen({super.key, required this.localeController});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  bool batterySaver = PersonalizationService.batterySaverEnabled;

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("personalization_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: SyrixColors.primary,
            value: batterySaver,
            title: Text(t("personalization_battery_saver"), style: const TextStyle(color: SyrixColors.textPrimary)),
            subtitle: Text(t("personalization_battery_saver_hint"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
            onChanged: (value) async {
              setState(() => batterySaver = value);
              await PersonalizationService.setBatterySaver(value);
            },
          ),
        ],
      ),
    );
  }
}
