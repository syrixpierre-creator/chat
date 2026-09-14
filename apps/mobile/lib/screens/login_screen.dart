import "dart:convert";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../theme/app_theme.dart";
import "../widgets/syrix_logo.dart";
import "../widgets/language_switch.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/account_service.dart";
import "../services/call_service.dart";
import "signup_screen.dart";
import "main_shell.dart";

class LoginScreen extends StatefulWidget {
  final LocaleController localeController;

  const LoginScreen({super.key, required this.localeController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiClient.login(emailController.text.trim(), passwordController.text);
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        setState(() {
          error = body["error"] == "invalid_credentials"
              ? widget.localeController.t("error_invalid_credentials")
              : widget.localeController.t("error_generic");
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("syrix_token", body["token"]);
      final user = body["user"] ?? {};
      await AccountService.saveActiveAccount(
        id: "${user["id"]}",
        username: user["username"] ?? "",
        avatarUrl: user["avatarUrl"],
        token: body["token"],
      );
      if (!mounted) return;
      CallService.instance.disconnect();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MainShell(localeController: widget.localeController)),
        (route) => false,
      );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SyrixColors.background, Color(0xFF241B3D), SyrixColors.background],
          ),
        ),
        child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              right: 16,
              child: LanguageSwitch(controller: widget.localeController),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: SyrixColors.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SyrixColors.primary.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(color: SyrixColors.primary.withOpacity(0.12), blurRadius: 30, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SyrixLogo(),
                      const SizedBox(height: 24),
                      if (error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SyrixColors.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SyrixColors.danger.withOpacity(0.4)),
                          ),
                          child: Text(error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                        ),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(labelText: t("login_email")),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(labelText: t("login_password")),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: SyrixColors.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: SyrixColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: loading ? null : submit,
                              child: Center(
                                child: loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        t("login_submit"),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t("login_switch"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14)),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => SignupScreen(localeController: widget.localeController)),
                              );
                            },
                            child: Text(t("login_switch_action")),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
