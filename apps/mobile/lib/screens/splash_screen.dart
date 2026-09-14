import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../theme/app_theme.dart";
import "login_screen.dart";
import "main_shell.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class SplashScreen extends StatefulWidget {
  final LocaleController localeController;

  const SplashScreen({super.key, required this.localeController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 900));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("syrix_token");

    Widget destination;
    if (token == null || token.isEmpty) {
      destination = LoginScreen(localeController: widget.localeController);
    } else {
      try {
        final response = await ApiClient.me().timeout(const Duration(seconds: 6));
        if (response.statusCode == 401) {
          await prefs.remove("syrix_token");
          destination = LoginScreen(localeController: widget.localeController);
        } else {
          destination = MainShell(localeController: widget.localeController);
        }
      } catch (_) {
        destination = MainShell(localeController: widget.localeController);
      }
    }

    await minDelay;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [SyrixColors.surfaceAlt, SyrixColors.background],
            radius: 1.2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [SyrixColors.primary, SyrixColors.primaryDark],
                  ),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                "SYRIX CHAT",
                style: TextStyle(color: SyrixColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              const Text(
                "MADE IN BY SYRIX VISION",
                style: TextStyle(color: SyrixColors.textMuted, fontSize: 12, letterSpacing: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
