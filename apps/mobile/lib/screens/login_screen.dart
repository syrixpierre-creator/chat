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

  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF281E44), SyrixColors.background],
            radius: 1.2,
            center: Alignment(0, -0.4),
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 16,
                child: LanguageSwitch(controller: widget.localeController),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SyrixLogo(size: 78, withTagline: false, showTitle: true),
                      const SizedBox(height: 24),
                      const Text(
                        "Welcome back!",
                        style: TextStyle(
                          color: SyrixColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Sign in to continue chatting",
                        style: TextStyle(color: SyrixColors.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      if (error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: SyrixColors.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SyrixColors.danger.withOpacity(0.4)),
                          ),
                          child: Text(error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                        ),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          hintText: "example@email.com",
                          prefixIcon: const Icon(Icons.mail_outline_rounded, color: SyrixColors.textMuted, size: 20),
                          filled: true,
                          fillColor: SyrixColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: SyrixColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: SyrixColors.neonPurple.withOpacity(0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: SyrixColors.neonPurple, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: SyrixColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "••••••••",
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: SyrixColors.textMuted, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: SyrixColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                          filled: true,
                          fillColor: SyrixColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: SyrixColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: SyrixColors.neonPurple.withOpacity(0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: SyrixColors.neonPurple, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Password reset instructions sent to email"),
                                backgroundColor: SyrixColors.surface,
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: SyrixColors.neonPurple, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: SyrixColors.accentGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: SyrixColors.neonPurple.withOpacity(0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(26),
                            onTap: loading ? null : submit,
                            child: Center(
                              child: loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text(
                                      "Sign In",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: SyrixColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              "Or continue with",
                              style: TextStyle(color: SyrixColors.textMuted.withOpacity(0.75), fontSize: 13),
                            ),
                          ),
                          const Expanded(child: Divider(color: SyrixColors.border)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(Icons.g_mobiledata_rounded, "Google"),
                          const SizedBox(width: 16),
                          _socialButton(Icons.apple_rounded, "Apple"),
                          const SizedBox(width: 16),
                          _socialButton(Icons.facebook_rounded, "Facebook"),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: TextStyle(color: SyrixColors.textMuted, fontSize: 14)),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => SignupScreen(localeController: widget.localeController)),
                              );
                            },
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(color: SyrixColors.neonPurple, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String provider) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign in with $provider"), backgroundColor: SyrixColors.surface),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SyrixColors.surface,
          border: Border.all(color: SyrixColors.border),
        ),
        child: Center(
          child: Icon(icon, color: SyrixColors.textPrimary, size: 24),
        ),
      ),
    );
  }
}
