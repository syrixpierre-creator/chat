import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class SyrixLogo extends StatelessWidget {
  final bool withTagline;
  final String tagline;

  const SyrixLogo({super.key, this.withTagline = true, this.tagline = "Made in by Syrix Vision"});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [SyrixColors.primary, SyrixColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 10),
        const Text(
          "SYRIX CHAT",
          style: TextStyle(color: SyrixColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        if (withTagline) ...[
          const SizedBox(height: 4),
          Text(
            tagline,
            style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11, letterSpacing: 1.2),
          ),
        ],
      ],
    );
  }
}
