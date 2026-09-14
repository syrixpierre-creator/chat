import "dart:convert";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "live_room_screen.dart";

class LiveScreen extends StatefulWidget {
  final LocaleController localeController;

  const LiveScreen({super.key, required this.localeController});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<Map<String, dynamic>> lives = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final response = await ApiClient.listLive();
    if (response.statusCode == 200) {
      lives = List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> openGoLiveDialog() async {
    final t = widget.localeController.t;
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SyrixColors.surface,
          title: Text(t("live_go_live"), style: const TextStyle(color: SyrixColors.textPrimary)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: SyrixColors.textPrimary),
            decoration: InputDecoration(hintText: t("live_title_hint")),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                final response = await ApiClient.startLive(controller.text.trim());
                if (context.mounted) Navigator.pop(context);
                if (response.statusCode == 201) {
                  final body = jsonDecode(response.body);
                  load();
                  if (context.mounted) {
                    openLiveRoom(context, body["id"].toString(), controller.text.trim(), isHost: true);
                  }
                }
              },
              child: Text(t("live_start")),
            ),
          ],
        );
      },
    );
  }

  void openLiveRoom(BuildContext context, String liveId, String title, {required bool isHost}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(
          localeController: widget.localeController,
          liveId: liveId,
          title: title,
          isHost: isHost,
        ),
      ),
    ).then((_) => load());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: SyrixColors.primary))
            : RefreshIndicator(
                onRefresh: load,
                color: SyrixColors.primary,
                child: lives.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                t("live_no_active"),
                                style: const TextStyle(color: SyrixColors.textMuted, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: lives.length,
                        itemBuilder: (context, index) {
                          final live = lives[index];
                          return GestureDetector(
                            onTap: () => openLiveRoom(context, live["id"].toString(), live["title"], isHost: false),
                            child: Container(
                              decoration: BoxDecoration(
                                color: SyrixColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: SyrixColors.border),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: SyrixColors.danger,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "LIVE",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    live["title"] ?? "",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: SyrixColors.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${live["hostUsername"]}",
                                    style: const TextStyle(color: SyrixColors.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: SyrixColors.primary,
        onPressed: openGoLiveDialog,
        child: const Icon(Icons.videocam_rounded, color: Colors.white),
      ),
    );
  }
}
