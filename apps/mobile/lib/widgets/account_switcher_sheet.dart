import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/account_service.dart";
import "../services/call_service.dart";
import "../screens/login_screen.dart";
import "../screens/main_shell.dart";

Future<void> showAccountSwitcherSheet(BuildContext context, LocaleController localeController) async {
  final t = localeController.t;
  final accounts = await AccountService.listAccounts();
  final activeId = await AccountService.activeAccountId();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: SyrixColors.surface,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    t("account_switcher_title"),
                    style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            ...accounts.map((account) {
              final isActive = account["id"] == activeId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: SyrixColors.surfaceAlt,
                  backgroundImage: account["avatarUrl"] != null ? NetworkImage(account["avatarUrl"]) : null,
                  child: account["avatarUrl"] == null
                      ? Text(
                          (account["username"] ?? "").isNotEmpty ? account["username"][0].toUpperCase() : "?",
                          style: const TextStyle(color: SyrixColors.textPrimary),
                        )
                      : null,
                ),
                title: Text(account["username"] ?? "", style: const TextStyle(color: SyrixColors.textPrimary)),
                trailing: isActive
                    ? const Icon(Icons.check_circle_rounded, color: SyrixColors.primary)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: SyrixColors.textMuted, size: 18),
                        onPressed: () async {
                          await AccountService.removeAccount(account["id"]);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                onTap: isActive
                    ? null
                    : () async {
                        final switched = await AccountService.switchTo(account["id"]);
                        if (switched && context.mounted) {
                          CallService.instance.disconnect();
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => MainShell(localeController: localeController)),
                            (route) => false,
                          );
                        }
                      },
              );
            }),
            const Divider(height: 1, color: SyrixColors.border),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: SyrixColors.primary),
              title: Text(t("account_switcher_add"), style: const TextStyle(color: SyrixColors.primary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LoginScreen(localeController: localeController)),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
