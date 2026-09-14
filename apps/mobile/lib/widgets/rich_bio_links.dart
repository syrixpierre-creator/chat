import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../theme/app_theme.dart";

class _PlatformMatch {
  final String url;
  final IconData icon;
  final String label;

  _PlatformMatch(this.url, this.icon, this.label);
}

class RichBioLinks extends StatelessWidget {
  final String bio;

  const RichBioLinks({super.key, required this.bio});

  static const Map<String, List<String>> _platforms = {
    "YouTube": ["youtube.com", "youtu.be"],
    "Instagram": ["instagram.com"],
    "X": ["x.com", "twitter.com"],
    "GitHub": ["github.com"],
    "TikTok": ["tiktok.com"],
    "Facebook": ["facebook.com"],
    "LinkedIn": ["linkedin.com"],
  };

  static const Map<String, IconData> _icons = {
    "YouTube": Icons.smart_display_rounded,
    "Instagram": Icons.camera_alt_rounded,
    "X": Icons.alternate_email_rounded,
    "GitHub": Icons.code_rounded,
    "TikTok": Icons.music_note_rounded,
    "Facebook": Icons.thumb_up_rounded,
    "LinkedIn": Icons.work_rounded,
  };

  List<_PlatformMatch> _extract() {
    final regex = RegExp(r"(https?://[^\s]+)", caseSensitive: false);
    final matches = regex.allMatches(bio);
    final result = <_PlatformMatch>[];
    for (final match in matches) {
      final url = match.group(0)!;
      final uri = Uri.tryParse(url);
      if (uri == null) continue;
      final host = uri.host.toLowerCase();
      String label = uri.host;
      IconData icon = Icons.link_rounded;
      for (final entry in _platforms.entries) {
        if (entry.value.any((domain) => host == domain || host.endsWith(".$domain"))) {
          label = entry.key;
          icon = _icons[entry.key]!;
          break;
        }
      }
      result.add(_PlatformMatch(url, icon, label));
    }
    return result;
  }

  static String stripUrls(String text) {
    return text.replaceAll(RegExp(r"(https?://[^\s]+)", caseSensitive: false), "").trim();
  }

  @override
  Widget build(BuildContext context) {
    final links = _extract();
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: links
          .map(
            (link) => ActionChip(
              backgroundColor: SyrixColors.surfaceAlt,
              side: const BorderSide(color: SyrixColors.border),
              avatar: Icon(link.icon, size: 16, color: SyrixColors.textPrimary),
              label: Text(link.label, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 12)),
              onPressed: () => launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
            ),
          )
          .toList(),
    );
  }
}
