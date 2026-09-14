import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "verified_badge.dart";

class ChatListItem extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final String? avatarUrl;
  final bool isBot;
  final bool isPremium;
  final String type;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatListItem({
    super.key,
    required this.name,
    this.lastMessage,
    this.avatarUrl,
    this.isBot = false,
    this.isPremium = false,
    this.type = "private",
    this.unread = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: SyrixColors.surfaceAlt,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl != null
            ? null
            : isBot
                ? const Icon(Icons.smart_toy_rounded, color: SyrixColors.textPrimary)
                : type == "community"
                    ? const Icon(Icons.diversity_3_rounded, color: SyrixColors.textPrimary)
                    : type == "group"
                        ? const Icon(Icons.groups_rounded, color: SyrixColors.textPrimary)
                        : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w700),
                          ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (isPremium) ...[
            const SizedBox(width: 4),
            const VerifiedBadge(size: 13),
          ],
          if (isBot) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SyrixColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "AI",
                style: TextStyle(color: SyrixColors.primary, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        lastMessage ?? "",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? SyrixColors.textPrimary : SyrixColors.textMuted,
          fontSize: 13,
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: SyrixColors.verifiedBadge, shape: BoxShape.circle),
            )
          : null,
    );
  }
}
