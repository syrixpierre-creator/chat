import "dart:convert";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class WalletScreen extends StatefulWidget {
  final LocaleController localeController;

  const WalletScreen({super.key, required this.localeController});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int balance = 0;
  List<Map<String, dynamic>> packages = [];
  List<Map<String, dynamic>> transactions = [];
  bool loading = true;
  bool openingCheckout = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final meResponse = await ApiClient.me();
    final packagesResponse = await ApiClient.listWalletPackages();
    final transactionsResponse = await ApiClient.listWalletTransactions();

    if (meResponse.statusCode == 200) {
      balance = jsonDecode(meResponse.body)["walletBalance"] ?? 0;
    }
    if (packagesResponse.statusCode == 200) {
      packages = List<Map<String, dynamic>>.from(jsonDecode(packagesResponse.body));
    }
    if (transactionsResponse.statusCode == 200) {
      transactions = List<Map<String, dynamic>>.from(jsonDecode(transactionsResponse.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> startCheckout(String packageId) async {
    setState(() => openingCheckout = true);
    try {
      final response = await ApiClient.createWalletCheckout(packageId);
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final url = Uri.parse(body["url"]);
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => openingCheckout = false);
    }
  }

  String transactionLabel(String type) {
    final t = widget.localeController.t;
    switch (type) {
      case "topup":
        return t("wallet_topup_type");
      case "gift_sent":
        return t("wallet_gift_sent_type");
      case "gift_received":
        return t("wallet_gift_received_type");
      case "message_payment_sent":
        return t("wallet_message_payment_sent_type");
      case "message_payment_received":
        return t("wallet_message_payment_received_type");
      default:
        return type;
    }
  }

  bool isDebit(String type) {
    return type == "message_payment_sent" || type == "gift_sent";
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("wallet_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : RefreshIndicator(
              onRefresh: load,
              color: SyrixColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [SyrixColors.primary, SyrixColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t("wallet_balance"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          "$balance ${t("wallet_credits")}",
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(t("wallet_top_up"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];
                      return GestureDetector(
                        onTap: openingCheckout ? null : () => startCheckout(pkg["id"]),
                        child: Container(
                          decoration: BoxDecoration(
                            color: SyrixColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: SyrixColors.border),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${pkg["credits"]} ${t("wallet_credits")}",
                                style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "\$${pkg["amountUsd"]}",
                                style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (openingCheckout) ...[
                    const SizedBox(height: 12),
                    Text(t("wallet_opening_checkout"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 28),
                  Text(t("wallet_history"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: Text(t("wallet_no_transactions"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
                      ),
                    ),
                  for (final tx in transactions)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: SyrixColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDebit(tx["type"])
                                ? Icons.remove_circle_rounded
                                : tx["type"] == "topup"
                                    ? Icons.add_circle_rounded
                                    : Icons.card_giftcard_rounded,
                            color: isDebit(tx["type"]) ? SyrixColors.danger : SyrixColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              transactionLabel(tx["type"]),
                              style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 14),
                            ),
                          ),
                          Text(
                            "${isDebit(tx["type"]) ? '-' : '+'}${tx["amount"]}",
                            style: TextStyle(
                              color: isDebit(tx["type"]) ? SyrixColors.danger : SyrixColors.textPrimary,
                              fontWeight: FontWeight.w700,
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
