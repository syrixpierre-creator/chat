import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: SyrixColors.verifiedBadge,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, color: Colors.white, size: size * 0.7),
    );
  }
}

class UsernameWithBadge extends StatelessWidget {
  final String username;
  final bool isPremium;
  final TextStyle? style;
  final double badgeSize;
  final double spacing;

  const UsernameWithBadge({
    super.key,
    required this.username,
    required this.isPremium,
    this.style,
    this.badgeSize = 14,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return Text(username, style: style, overflow: TextOverflow.ellipsis);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(username, style: style, overflow: TextOverflow.ellipsis)),
        SizedBox(width: spacing),
        VerifiedBadge(size: badgeSize),
      ],
    );
  }
}
