import "package:flutter/material.dart";
import "theme/app_theme.dart";
import "i18n/locale_controller.dart";
import "screens/splash_screen.dart";
import "services/personalization_service.dart";

void main() {
  runApp(const SyrixApp());
}

class SyrixApp extends StatefulWidget {
  const SyrixApp({super.key});

  @override
  State<SyrixApp> createState() => _SyrixAppState();
}

class _SyrixAppState extends State<SyrixApp> {
  final localeController = LocaleController();

  @override
  void initState() {
    super.initState();
    localeController.load();
    PersonalizationService.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "SYRIX CHAT",
      debugShowCheckedModeBanner: false,
      theme: buildSyrixTheme(),
      home: SplashScreen(localeController: localeController),
    );
  }
}
