import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/parental_control_service.dart";
import "../widgets/pin_pad.dart";

class ParentalGateScreen extends StatefulWidget {
  final LocaleController localeController;

  const ParentalGateScreen({super.key, required this.localeController});

  @override
  State<ParentalGateScreen> createState() => _ParentalGateScreenState();
}

class _ParentalGateScreenState extends State<ParentalGateScreen> {
  String entered = "";
  String? error;

  Future<void> addDigit(String digit) async {
    if (entered.length >= 4) return;
    setState(() => entered += digit);
    if (entered.length == 4) {
      final valid = await ParentalControlService.verifyPin(entered);
      if (!mounted) return;
      if (valid) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          error = widget.localeController.t("parental_wrong_pin");
          entered = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: SyrixColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t("parental_gate_title"), style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            PinPad(
              enteredLength: entered.length,
              pinLength: 4,
              errorText: error,
              onDigit: addDigit,
              onBackspace: () => setState(() => entered = entered.isEmpty ? "" : entered.substring(0, entered.length - 1)),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentalControlScreen extends StatefulWidget {
  final LocaleController localeController;

  const ParentalControlScreen({super.key, required this.localeController});

  @override
  State<ParentalControlScreen> createState() => _ParentalControlScreenState();
}

class _ParentalControlScreenState extends State<ParentalControlScreen> {
  bool enabled = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    enabled = await ParentalControlService.isEnabled();
    if (mounted) setState(() => loading = false);
  }

  Future<void> toggle(bool value) async {
    if (value) {
      final pin = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => _ChooseParentalPinScreen(localeController: widget.localeController)),
      );
      if (pin != null && pin.length == 4) {
        await ParentalControlService.setPin(pin);
        setState(() => enabled = true);
      }
    } else {
      await ParentalControlService.disable();
      setState(() => enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("parental_control_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  activeColor: SyrixColors.primary,
                  value: enabled,
                  onChanged: toggle,
                  title: Text(t("parental_enable"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  subtitle: Text(t("parental_enable_hint"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                ),
              ],
            ),
    );
  }
}

class _ChooseParentalPinScreen extends StatefulWidget {
  final LocaleController localeController;

  const _ChooseParentalPinScreen({required this.localeController});

  @override
  State<_ChooseParentalPinScreen> createState() => _ChooseParentalPinScreenState();
}

class _ChooseParentalPinScreenState extends State<_ChooseParentalPinScreen> {
  String entered = "";
  String? firstPin;
  String? error;

  void addDigit(String digit) {
    if (entered.length >= 4) return;
    setState(() => entered += digit);
    if (entered.length == 4) {
      if (firstPin == null) {
        setState(() {
          firstPin = entered;
          entered = "";
        });
      } else if (entered == firstPin) {
        Navigator.of(context).pop(entered);
      } else {
        setState(() {
          error = widget.localeController.t("parental_pin_mismatch");
          firstPin = null;
          entered = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(backgroundColor: SyrixColors.background),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstPin == null ? t("parental_choose_pin") : t("parental_confirm_pin"),
              style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            PinPad(
              enteredLength: entered.length,
              pinLength: 4,
              errorText: error,
              onDigit: addDigit,
              onBackspace: () => setState(() => entered = entered.isEmpty ? "" : entered.substring(0, entered.length - 1)),
            ),
          ],
        ),
      ),
    );
  }
}
