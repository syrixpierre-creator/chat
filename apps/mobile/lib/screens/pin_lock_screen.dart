import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/pin_service.dart";
import "../widgets/pin_pad.dart";

class PinLockScreen extends StatefulWidget {
  final LocaleController localeController;
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.localeController, required this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String entered = "";
  String? error;

  void addDigit(String digit) {
    if (entered.length >= 6) return;
    setState(() {
      entered += digit;
      error = null;
    });
    if (entered.length == 6) checkPin();
  }

  void removeDigit() {
    if (entered.isEmpty) return;
    setState(() => entered = entered.substring(0, entered.length - 1));
  }

  Future<void> checkPin() async {
    final valid = await PinService.verifyPin(entered);
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() {
        error = widget.localeController.t("pin_incorrect");
        entered = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Material(
      color: SyrixColors.background,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: SyrixColors.primary, size: 40),
              const SizedBox(height: 12),
              Text(
                t("pin_enter_title"),
                style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              PinPad(
                enteredLength: entered.length,
                onDigit: addDigit,
                onBackspace: removeDigit,
                errorText: error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
