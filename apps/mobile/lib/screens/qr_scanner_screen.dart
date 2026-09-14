import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";

class QrScannerScreen extends StatefulWidget {
  final LocaleController localeController;

  const QrScannerScreen({super.key, required this.localeController});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool handled = false;

  void handleDetection(BarcodeCapture capture) {
    if (handled) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;
    handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t("qr_scan_title"), style: const TextStyle(color: Colors.white)),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(onDetect: handleDetection),
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: SyrixColors.primary, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Text(
              t("qr_scan_hint"),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
