import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/vault_service.dart";
import "../widgets/pin_pad.dart";

class VaultGateScreen extends StatefulWidget {
  final LocaleController localeController;

  const VaultGateScreen({super.key, required this.localeController});

  @override
  State<VaultGateScreen> createState() => _VaultGateScreenState();
}

class _VaultGateScreenState extends State<VaultGateScreen> {
  String entered = "";
  String? error;
  bool needsSetup = false;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final hasPin = await VaultService.hasPin();
    setState(() {
      needsSetup = !hasPin;
      checking = false;
    });
  }

  Future<void> addDigit(String digit) async {
    if (entered.length >= 4) return;
    setState(() => entered += digit);
    if (entered.length == 4) {
      if (needsSetup) {
        await VaultService.setPin(entered);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => VaultScreen(localeController: widget.localeController)),
        );
        return;
      }
      final valid = await VaultService.verifyPin(entered);
      if (!mounted) return;
      if (valid) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => VaultScreen(localeController: widget.localeController)),
        );
      } else {
        setState(() {
          error = widget.localeController.t("vault_wrong_pin");
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: checking
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    needsSetup ? t("vault_setup_title") : t("vault_gate_title"),
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

class VaultScreen extends StatefulWidget {
  final LocaleController localeController;

  const VaultScreen({super.key, required this.localeController});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final list = await VaultService.listItems();
    if (mounted) setState(() => items = list);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        title: Text(t("vault_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: items.isEmpty
          ? Center(child: Text(t("vault_empty"), style: const TextStyle(color: SyrixColors.textMuted)))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onLongPress: () async {
                    await VaultService.removeItem(item["mediaUrl"]);
                    load();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item["mediaUrl"], fit: BoxFit.cover),
                  ),
                );
              },
            ),
    );
  }
}
