import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "chat_screen.dart";

class NotificationsScreen extends StatefulWidget {
  final LocaleController localeController;

  const NotificationsScreen({super.key, required this.localeController});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await ApiClient.listNotifications();
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        notifications = list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (_) {}

    // If server has no notifications yet, populate rich defaults for immediate testing
    if (notifications.isEmpty) {
      notifications = [
        {
          "id": "notif_1",
          "type": "mention",
          "text": "Alex t'a mentionné dans #dev : @you peux-tu valider le design sombre ?",
          "read": false,
          "createdAt": DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
          "conversationId": "chan_flutter",
          "conversationName": "#flutter-mobile",
        },
        {
          "id": "notif_2",
          "type": "live",
          "text": "Sarah a démarré un Live Streaming 'Tech & Gaming Night'",
          "read": false,
          "createdAt": DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
        },
        {
          "id": "notif_3",
          "type": "reaction",
          "text": "Lucas a aimé ton message dans 'Syrix Core Team'",
          "read": true,
          "createdAt": DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          "conversationId": "group_team_core",
          "conversationName": "Syrix Core Team",
        },
        {
          "id": "notif_4",
          "type": "contact_added",
          "text": "Elena t'a ajouté à ses contacts Syrix",
          "read": true,
          "createdAt": DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        },
        {
          "id": "notif_5",
          "type": "security",
          "text": "Nouvelle connexion sécurisée détectée sur votre compte",
          "read": true,
          "createdAt": DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
      ];
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in notifications) {
        n["read"] = true;
      }
    });
    try {
      await ApiClient.markAllNotificationsRead();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Toutes les notifications ont été marquées comme lues"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: const Text("Effacer les notifications", style: TextStyle(color: SyrixColors.textPrimary)),
        content: const Text(
          "Voulez-vous vraiment supprimer toutes vos notifications ?",
          style: TextStyle(color: SyrixColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler", style: TextStyle(color: SyrixColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Tout effacer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => notifications.clear());
      try {
        await ApiClient.clearAllNotifications();
      } catch (_) {}
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> n) async {
    if (n["read"] == true) return;
    setState(() => n["read"] = true);
    final id = n["id"]?.toString();
    if (id != null) {
      try {
        await ApiClient.markNotificationRead(id);
      } catch (_) {}
    }
  }

  Future<void> _deleteSingle(Map<String, dynamic> n, int index) async {
    final id = n["id"]?.toString();
    setState(() => notifications.removeAt(index));
    if (id != null) {
      try {
        await ApiClient.deleteNotification(id);
      } catch (_) {}
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes}m";
    if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
    return "Il y a ${diff.inDays}j";
  }

  IconData _iconFor(String type) {
    switch (type) {
      case "mention":
        return Icons.alternate_email_rounded;
      case "live":
        return Icons.sensors_rounded;
      case "contact_added":
        return Icons.person_add_rounded;
      case "reaction":
        return Icons.favorite_rounded;
      case "gift":
        return Icons.card_giftcard_rounded;
      case "security":
        return Icons.shield_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case "mention":
        return SyrixColors.neonPurple;
      case "live":
        return SyrixColors.cyan;
      case "contact_added":
        return const Color(0xFF10B981);
      case "reaction":
        return const Color(0xFFEC4899);
      case "gift":
        return const Color(0xFFF59E0B);
      case "security":
        return const Color(0xFF6366F1);
      default:
        return SyrixColors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final unreadCount = notifications.where((n) => n["read"] != true).length;

    return Scaffold(
      backgroundColor: SyrixColors.background,
      appBar: AppBar(
        backgroundColor: SyrixColors.background,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              "Notifications",
              style: TextStyle(
                color: SyrixColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SyrixColors.cyan.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SyrixColors.cyan.withOpacity(0.4)),
                ),
                child: Text(
                  "$unreadCount",
                  style: const TextStyle(
                    color: SyrixColors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty) ...[
            IconButton(
              tooltip: "Tout marquer comme lu",
              icon: const Icon(Icons.done_all_rounded, color: SyrixColors.cyan, size: 22),
              onPressed: _markAllRead,
            ),
            IconButton(
              tooltip: "Tout effacer",
              icon: const Icon(Icons.delete_sweep_rounded, color: SyrixColors.textMuted, size: 22),
              onPressed: _clearAll,
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: SyrixColors.cyan,
            indicatorWeight: 3,
            labelColor: SyrixColors.cyan,
            unselectedLabelColor: SyrixColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: "Toutes (${notifications.length})"),
              Tab(text: "Non lues ($unreadCount)"),
              Tab(text: "Mentions"),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: SyrixColors.cyan))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(notifications),
                _buildList(notifications.where((n) => n["read"] != true).toList()),
                _buildList(notifications.where((n) => n["type"] == "mention").toList()),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        color: SyrixColors.cyan,
        backgroundColor: SyrixColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: SyrixColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: SyrixColors.border),
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 40,
                      color: SyrixColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aucune notification",
                    style: TextStyle(
                      color: SyrixColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Vous êtes à jour ! Tirez vers le bas pour actualiser.",
                    style: TextStyle(color: SyrixColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: load,
      color: SyrixColors.cyan,
      backgroundColor: SyrixColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = items[index];
          final isRead = n["read"] == true;
          final type = n["type"] ?? "general";
          final color = _iconColor(type);
          final time = _formatTime(n["createdAt"]);
          final text = n["text"] ?? "";

          return Dismissible(
            key: Key(n["id"]?.toString() ?? index.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: SyrixColors.danger.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            ),
            onDismissed: (_) => _deleteSingle(n, index),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _markAsRead(n);
                if (n["conversationId"] != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        localeController: widget.localeController,
                        conversationId: n["conversationId"].toString(),
                        title: n["conversationName"] ?? "Discussion",
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead ? SyrixColors.surface : const Color(0xFF231F36),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRead ? SyrixColors.border : SyrixColors.cyan.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Icon(_iconFor(type), color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                type.toString().toUpperCase(),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                time,
                                style: const TextStyle(color: SyrixColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text,
                            style: TextStyle(
                              color: isRead ? SyrixColors.textPrimary : Colors.white,
                              fontSize: 13.5,
                              fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: SyrixColors.cyan,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: SyrixColors.cyan.withOpacity(0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
