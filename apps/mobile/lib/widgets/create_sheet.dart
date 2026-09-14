import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

Future<void> showCreateSheet(
  BuildContext context,
  LocaleController localeController,
  VoidCallback onCreated, {
  String? communityId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: SyrixColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.groups_rounded, color: SyrixColors.primary),
                title: Text(localeController.t("home_new_group"), style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _openCreateDialog(context, localeController, "group", onCreated, communityId: communityId);
                },
              ),
              if (communityId == null)
                ListTile(
                  leading: const Icon(Icons.diversity_3_rounded, color: SyrixColors.primary),
                  title: Text(localeController.t("home_new_community"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _openCreateDialog(context, localeController, "community", onCreated);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

void _openCreateDialog(
  BuildContext context,
  LocaleController localeController,
  String type,
  VoidCallback onCreated, {
  String? communityId,
}) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(
          type == "group" ? localeController.t("create_group_title") : localeController.t("create_community_title"),
          style: const TextStyle(color: SyrixColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: SyrixColors.textPrimary),
          decoration: InputDecoration(
            hintText: type == "group"
                ? localeController.t("group_name_hint")
                : localeController.t("community_name_hint"),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await ApiClient.createGroup(controller.text.trim(), type, [], communityId: communityId);
              if (context.mounted) Navigator.pop(context);
              onCreated();
            },
            child: Text(localeController.t("create_action")),
          ),
        ],
      );
    },
  );
}
