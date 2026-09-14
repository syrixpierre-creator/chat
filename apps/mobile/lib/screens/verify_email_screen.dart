import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../theme/app_theme.dart";
import "../widgets/syrix_logo.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/account_service.dart";
import "../services/call_service.dart";
import "main_shell.dart";
import "username_selection_screen.dart";

class VerifyEmailScreen extends StatefulWidget {
  final LocaleController localeController;
  final String email;

  const VerifyEmailScreen({super.key, required this.localeController, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiClient.verifyEmail(widget.email, codeController.text.trim());
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        setState(() => error = widget.localeController.t("error_generic"));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("syrix_token", body["token"]);
      final meResponse = await ApiClient.me();
      if (meResponse.statusCode == 200) {
        final me = jsonDecode(meResponse.body);
        await AccountService.saveActiveAccount(
          id: "${me["id"]}",
          username: me["username"] ?? "",
          avatarUrl: me["avatarUrl"],
          token: body["token"],
        );
      }
      if (!mounted) return;
      CallService.instance.disconnect();
      final usernameSet = body["usernameSet"] == true;
      if (usernameSet) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainShell(localeController: widget.localeController)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => UsernameSelectionScreen(localeController: widget.localeController),
          ),
          (route) => false,
        );
      }
    } catch (_) {
      setState(() => error = widget.localeController.t("error_generic"));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SyrixColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SyrixColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SyrixLogo(withTagline: false),
                  const SizedBox(height: 24),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SyrixColors.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                    ),
                  Text(widget.email, style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: SyrixColors.textPrimary),
                    decoration: const InputDecoration(labelText: "Code"),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: Text(t("signup_submit")),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
