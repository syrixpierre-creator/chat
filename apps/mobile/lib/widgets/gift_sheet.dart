import "dart:convert";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

final Map<String, IconData> giftIcons = {
  "rose": Icons.local_florist_rounded,
  "heart": Icons.favorite_rounded,
  "star": Icons.star_rounded,
  "crown": Icons.emoji_events_rounded,
};

Future<bool?> showGiftSheet(
  BuildContext context,
  LocaleController localeController,
  String conversationId, {
  Future<http.Response> Function(String giftId)? sendOverride,
}) async {
  final response = await ApiClient.listGifts();
  if (response.statusCode != 200) return null;
  final gifts = List<Map<String, dynamic>>.from(jsonDecode(response.body));

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: SyrixColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localeController.t("gift_send_title"),
                style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: gifts.length,
                itemBuilder: (context, index) {
                  final gift = gifts[index];
                  return GestureDetector(
                    onTap: () async {
                      final sendResponse = sendOverride != null
                          ? await sendOverride(gift["id"])
                          : await ApiClient.sendGift(conversationId, gift["id"]);
                      if (context.mounted) {
                        Navigator.pop(context, sendResponse.statusCode == 201 ? true : false);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: SyrixColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SyrixColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(giftIcons[gift["icon"]] ?? Icons.card_giftcard_rounded, color: SyrixColors.primary, size: 26),
                          const SizedBox(height: 6),
                          Text(gift["label"], style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600)),
                          Text("${gift["cost"]}", style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
