import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../widgets/syrix_logo.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "login_screen.dart";
import "verify_email_screen.dart";

class SignupScreen extends StatefulWidget {
  final LocaleController localeController;

  const SignupScreen({super.key, required this.localeController});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  DateTime? birthDate;
  bool loading = false;
  String? error;

  Future<void> pickBirthDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (result != null) {
      setState(() => birthDate = result);
    }
  }

  Future<void> submit() async {
    if (birthDate == null) {
      setState(() => error = widget.localeController.t("signup_birthdate_required"));
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiClient.signup(
        emailController.text.trim(),
        passwordController.text,
        widget.localeController.locale,
        birthDate!,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode != 201) {
        setState(() {
          if (body["error"] == "user_exists") {
            error = widget.localeController.t("error_user_exists");
          } else if (body["error"] == "underage") {
            error = widget.localeController.t("error_underage");
          } else {
            error = widget.localeController.t("error_generic");
          }
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            localeController: widget.localeController,
            email: emailController.text.trim(),
          ),
        ),
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
                    decoration: InputDecoration(labelText: t("signup_email")),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: SyrixColors.textPrimary),
                    decoration: InputDecoration(labelText: t("signup_password")),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: pickBirthDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_rounded, color: SyrixColors.textMuted, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            birthDate == null
                                ? t("signup_birthdate")
                                : "${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}",
                            style: TextStyle(
                              color: birthDate == null ? SyrixColors.textMuted : SyrixColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: Text(t("signup_submit")),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t("signup_switch"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14)),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => LoginScreen(localeController: widget.localeController)),
                          );
                        },
                        child: Text(t("signup_switch_action")),
                      ),
                    ],
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
