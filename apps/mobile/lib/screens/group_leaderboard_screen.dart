import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class GroupLeaderboardScreen extends StatefulWidget {
  final LocaleController localeController;
  final String conversationId;

  const GroupLeaderboardScreen({
    super.key,
    required this.localeController,
    required this.conversationId,
  });

  @override
  State<GroupLeaderboardScreen> createState() => _GroupLeaderboardScreenState();
}

class _GroupLeaderboardScreenState extends State<GroupLeaderboardScreen> {
  List<Map<String, dynamic>> leaderboard = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final response = await ApiClient.getLeaderboard(widget.conversationId);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      leaderboard = List<Map<String, dynamic>>.from(body["leaderboard"] ?? []);
    }
    if (mounted) setState(() => loading = false);
  }

  Widget rankBadge(int rank) {
    if (rank == 0) return const Text("🥇", style: TextStyle(fontSize: 20));
    if (rank == 1) return const Text("🥈", style: TextStyle(fontSize: 20));
    if (rank == 2) return const Text("🥉", style: TextStyle(fontSize: 20));
    return Text(
      "${rank + 1}",
      style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.surface,
        iconTheme: const IconThemeData(color: SyrixColors.textPrimary),
        title: Text(t("group_leaderboard_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
          : leaderboard.isEmpty
              ? Center(
                  child: Text(t("group_leaderboard_empty"), style: const TextStyle(color: SyrixColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: leaderboard.length,
                  itemBuilder: (context, index) {
                    final entry = leaderboard[index];
                    final level = entry["level"] ?? 1;
                    final xpIntoLevel = (entry["xp"] ?? 0) % 100;
                    return ListTile(
                      leading: SizedBox(width: 32, child: Center(child: rankBadge(index))),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry["username"] ?? "",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t("badge_${entry["badge"]}"),
                            style: const TextStyle(color: SyrixColors.primary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: xpIntoLevel / 100,
                              minHeight: 4,
                              backgroundColor: SyrixColors.surfaceAlt,
                              valueColor: const AlwaysStoppedAnimation(SyrixColors.primary),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        t("group_leaderboard_level").replaceAll("{level}", "$level"),
                        style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                      ),
                    );
                  },
                ),
    );
  }
}
