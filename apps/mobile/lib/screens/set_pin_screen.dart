import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/pin_service.dart";
import "../widgets/pin_pad.dart";

enum _Step { verifyCurrent, choose, confirm }

class SetPinScreen extends StatefulWidget {
  final LocaleController localeController;
  final bool hasExistingPin;
  final bool removeMode;

  const SetPinScreen({
    super.key,
    required this.localeController,
    required this.hasExistingPin,
    this.removeMode = false,
  });

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  late _Step step;
  String entered = "";
  String? firstPin;
  String? error;

  @override
  void initState() {
    super.initState();
    step = widget.hasExistingPin ? _Step.verifyCurrent : _Step.choose;
  }

  void addDigit(String digit) {
    if (entered.length >= 6) return;
    setState(() {
      entered += digit;
      error = null;
    });
    if (entered.length == 6) handleComplete();
  }

  void removeDigit() {
    if (entered.isEmpty) return;
    setState(() => entered = entered.substring(0, entered.length - 1));
  }

  Future<void> handleComplete() async {
    final t = widget.localeController.t;
    if (step == _Step.verifyCurrent) {
      final valid = await PinService.verifyPin(entered);
      if (!mounted) return;
      if (!valid) {
        setState(() {
          error = t("pin_incorrect");
          entered = "";
        });
        return;
      }
      if (widget.removeMode) {
        await PinService.removePin();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      setState(() {
        step = _Step.choose;
        entered = "";
      });
      return;
    }

    if (step == _Step.choose) {
      setState(() {
        firstPin = entered;
        entered = "";
        step = _Step.confirm;
      });
      return;
    }

    if (entered == firstPin) {
      await PinService.setPin(entered);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        error = t("pin_mismatch");
        entered = "";
        step = _Step.choose;
        firstPin = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    String title;
    switch (step) {
      case _Step.verifyCurrent:
        title = t("pin_enter_current");
        break;
      case _Step.choose:
        title = t("pin_choose_new");
        break;
      case _Step.confirm:
        title = t("pin_confirm_new");
        break;
    }

    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        elevation: 0,
        title: Text(t("pin_screen_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
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
