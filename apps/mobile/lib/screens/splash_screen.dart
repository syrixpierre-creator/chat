import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../theme/app_theme.dart";
import "../widgets/syrix_logo.dart";
import "login_screen.dart";
import "signup_screen.dart";
import "main_shell.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class SplashScreen extends StatefulWidget {
  final LocaleController localeController;

  const SplashScreen({super.key, required this.localeController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool showOnboarding = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
    checkSession();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("syrix_token");
    final hasSeenIntro = prefs.getBool("syrix_has_seen_intro") ?? false;

    if (token != null && token.isNotEmpty) {
      try {
        final response = await ApiClient.me().timeout(const Duration(seconds: 5));
        if (response.statusCode == 401) {
          await prefs.remove("syrix_token");
          _goToLoginOrIntro(hasSeenIntro);
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MainShell(localeController: widget.localeController),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => MainShell(localeController: widget.localeController),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    } else {
      _goToLoginOrIntro(hasSeenIntro);
    }
  }

  void _goToLoginOrIntro(bool hasSeenIntro) {
    if (!mounted) return;
    if (hasSeenIntro) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(localeController: widget.localeController),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => showOnboarding = true);
    }
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("syrix_has_seen_intro", true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LoginScreen(localeController: widget.localeController),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showOnboarding) {
      return _buildOnboardingView();
    }
    return _buildSplashView();
  }

  Widget _buildSplashView() {
    return Scaffold(
      backgroundColor: SyrixColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF231B38), SyrixColors.background],
            radius: 1.1,
            center: Alignment(0, -0.1),
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SyrixLogo(
                  size: 96,
                  withTagline: true,
                  tagline: "MADE IN BY SYRIX VISION",
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(SyrixColors.cyan),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingView() {
    final t = widget.localeController.t;
    final pages = [
      {
        "title": "Fast & Secure Chat",
        "subtitle": "Connect with friends and colleagues instantly with end-to-end encryption and futuristic dark design.",
        "icon": Icons.chat_bubble_rounded,
        "color": SyrixColors.neonPurple,
      },
      {
        "title": "Communities & Channels",
        "subtitle": "Organize teams with structured communities, nested channels, and one-tap instant access.",
        "icon": Icons.groups_rounded,
        "color": SyrixColors.cyan,
      },
      {
        "title": "Live Streaming & Audio",
        "subtitle": "Go live, share stories, broadcast high-definition video, and react in real-time.",
        "icon": Icons.sensors_rounded,
        "color": const Color(0xFFE056FD),
      },
    ];

    return Scaffold(
      backgroundColor: SyrixColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SyrixLogo(size: 38, showTitle: false, withTagline: false),
                  TextButton(
                    onPressed: finishOnboarding,
                    child: Text(
                      "Skip",
                      style: TextStyle(color: SyrixColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final p = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SyrixColors.surface,
                            border: Border.all(color: (p["color"] as Color).withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: (p["color"] as Color).withOpacity(0.25),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(p["icon"] as IconData, size: 54, color: p["color"] as Color),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          p["title"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SyrixColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p["subtitle"] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SyrixColors.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: _currentPage == i ? SyrixColors.accentGradient : null,
                    color: _currentPage == i ? null : SyrixColors.border,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: SyrixColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: SyrixColors.neonPurple.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (_currentPage < pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            finishOnboarding();
                          }
                        },
                        child: Center(
                          child: Text(
                            _currentPage < pages.length - 1 ? "Next" : "Get Started",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: finishOnboarding,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 14),
                        children: [
                          TextSpan(text: "Already have an account? ", style: TextStyle(color: SyrixColors.textMuted)),
                          TextSpan(text: "Sign In", style: TextStyle(color: SyrixColors.cyan, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
