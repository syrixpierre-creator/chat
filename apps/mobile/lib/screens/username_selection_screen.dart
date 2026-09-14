import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../theme/app_theme.dart";
import "../widgets/syrix_logo.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../services/account_service.dart";
import "main_shell.dart";

class UsernameSelectionScreen extends StatefulWidget {
  final LocaleController localeController;
  final bool isOnboarding;
  final String? currentUsername;

  const UsernameSelectionScreen({
    super.key,
    required this.localeController,
    this.isOnboarding = true,
    this.currentUsername,
  });

  @override
  State<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends State<UsernameSelectionScreen> {
  final controller = TextEditingController();
  Timer? _debounce;
  bool checking = false;
  bool? available;
  List<String> suggestions = [];
  bool submitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.currentUsername != null) {
      controller.text = widget.currentUsername!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      available = null;
      suggestions = [];
      error = null;
    });
    final candidate = value.trim();
    if (candidate.length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => checkUsername(candidate));
  }

  Future<void> checkUsername(String candidate) async {
    setState(() => checking = true);
    try {
      final response = await ApiClient.checkUsername(candidate);
      final body = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          available = false;
          suggestions = [];
        });
        return;
      }
      setState(() {
        available = body["available"] == true;
        suggestions = (body["suggestions"] as List?)?.map((e) => e.toString()).toList() ?? [];
      });
    } catch (_) {
      if (mounted) setState(() => available = null);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  void pickSuggestion(String suggestion) {
    controller.text = suggestion;
    controller.selection = TextSelection.fromPosition(TextPosition(offset: suggestion.length));
    setState(() {
      available = true;
      suggestions = [];
    });
  }

  Future<void> submit() async {
    if (available != true || submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final response = await ApiClient.setUsername(controller.text.trim());
      final body = jsonDecode(response.body);
      if (response.statusCode != 200) {
        setState(() {
          if (body["error"] == "username_taken") {
            available = false;
            suggestions = (body["suggestions"] as List?)?.map((e) => e.toString()).toList() ?? [];
          } else {
            error = widget.localeController.t("error_generic");
          }
        });
        return;
      }
      await AccountService.updateActiveUsername(body["username"]);
      if (!mounted) return;
      if (widget.isOnboarding) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainShell(localeController: widget.localeController)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(body["username"]);
      }
    } catch (_) {
      setState(() => error = widget.localeController.t("error_generic"));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    Widget? suffixIcon;
    if (checking) {
      suffixIcon = const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: SyrixColors.primary),
        ),
      );
    } else if (available == true) {
      suffixIcon = const Icon(Icons.check_circle, color: SyrixColors.success);
    } else if (available == false) {
      suffixIcon = const Icon(Icons.cancel, color: SyrixColors.danger);
    }

    return Scaffold(
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              backgroundColor: SyrixColors.background,
              title: Text(t("username_screen_title")),
            ),
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
                  if (widget.isOnboarding) ...[
                    const SyrixLogo(withTagline: false),
                    const SizedBox(height: 16),
                    Text(
                      t("username_screen_title"),
                      style: const TextStyle(
                        color: SyrixColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    t("username_screen_subtitle"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
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
                  TextField(
                    controller: controller,
                    onChanged: onChanged,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9_]")),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    style: const TextStyle(color: SyrixColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText: "@",
                      labelText: t("username_hint"),
                      suffixIcon: suffixIcon,
                    ),
                  ),
                  if (available == false && suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(t("username_taken"),
                          style: const TextStyle(color: SyrixColors.danger, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .map(
                            (s) => ActionChip(
                              backgroundColor: SyrixColors.surfaceAlt,
                              side: const BorderSide(color: SyrixColors.border),
                              label: Text("@$s", style: const TextStyle(color: SyrixColors.textPrimary)),
                              onPressed: () => pickSuggestion(s),
                            ),
                          )
                          .toList(),
                    ),
                  ] else if (available == false) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(t("username_taken"),
                          style: const TextStyle(color: SyrixColors.danger, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (available == true && !submitting) ? submit : null,
                      child: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t("username_confirm")),
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
