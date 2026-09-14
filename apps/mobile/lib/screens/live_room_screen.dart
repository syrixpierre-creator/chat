import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:livekit_client/livekit_client.dart" as lk;
import "package:permission_handler/permission_handler.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";
import "../widgets/gift_sheet.dart";

class LiveRoomScreen extends StatefulWidget {
  final LocaleController localeController;
  final String liveId;
  final String title;
  final bool isHost;

  const LiveRoomScreen({
    super.key,
    required this.localeController,
    required this.liveId,
    required this.title,
    required this.isHost,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  lk.Room? room;
  lk.EventsListener<lk.RoomEvent>? listener;
  List<lk.Participant> participants = [];
  bool connecting = true;
  bool micEnabled = true;
  bool cameraEnabled = true;
  String? error;
  List<Map<String, dynamic>> chatMessages = [];
  String? lastChatFetch;
  Timer? chatPollTimer;
  final chatController = TextEditingController();
  int reactionCount = 0;
  int giftTotal = 0;
  bool showHeartPulse = false;

  @override
  void initState() {
    super.initState();
    connect();
    chatPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => pollChat());
  }

  Future<void> pollChat() async {
    final response = await ApiClient.listLiveChatMessages(widget.liveId, since: lastChatFetch);
    if (response.statusCode != 200 || !mounted) return;
    final body = jsonDecode(response.body);
    final newMessages = List<Map<String, dynamic>>.from(body["messages"] ?? []);
    if (newMessages.isNotEmpty) {
      lastChatFetch = newMessages.last["createdAt"];
      setState(() => chatMessages.addAll(newMessages));
    }
    final count = body["reactionCount"] ?? 0;
    if (count != reactionCount) {
      setState(() => reactionCount = count);
    }
    final gifts = body["giftTotal"] ?? 0;
    if (gifts != giftTotal) {
      setState(() => giftTotal = gifts);
    }
  }

  Future<void> sendChatMessage() async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;
    chatController.clear();
    await ApiClient.sendLiveChatMessage(widget.liveId, text);
    pollChat();
  }

  Future<void> sendReaction() async {
    setState(() => showHeartPulse = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => showHeartPulse = false);
    });
    await ApiClient.sendLiveReaction(widget.liveId);
  }

  Future<void> shareLive() async {
    final t = widget.localeController.t;
    final link = ApiClient.liveLink(widget.liveId);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SyrixColors.surface,
        title: Text(t("live_share_title"), style: const TextStyle(color: SyrixColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: link, size: 180),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.link_rounded, size: 16),
              label: Text(t("profile_copy_link")),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> connect() async {
    if (widget.isHost) {
      final camera = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!camera.isGranted || !mic.isGranted) {
        setState(() {
          connecting = false;
          error = widget.localeController.t("live_permission_denied");
        });
        return;
      }
    }

    final tokenResponse = await ApiClient.getLiveToken(widget.liveId);
    if (tokenResponse.statusCode != 200) {
      setState(() {
        connecting = false;
        error = widget.localeController.t("live_connection_error");
      });
      return;
    }

    final body = jsonDecode(tokenResponse.body);
    final newRoom = lk.Room();
    final newListener = newRoom.createListener();

    try {
      await newRoom.connect(body["url"], body["token"]);
    } catch (_) {
      setState(() {
        connecting = false;
        error = widget.localeController.t("live_connection_error");
      });
      return;
    }

    if (widget.isHost) {
      await newRoom.localParticipant?.setCameraEnabled(true);
      await newRoom.localParticipant?.setMicrophoneEnabled(true);
    }

    newListener
      ..on<lk.ParticipantConnectedEvent>((_) => refreshParticipants())
      ..on<lk.ParticipantDisconnectedEvent>((_) => refreshParticipants())
      ..on<lk.TrackSubscribedEvent>((_) => refreshParticipants())
      ..on<lk.TrackUnsubscribedEvent>((_) => refreshParticipants())
      ..on<lk.LocalTrackPublishedEvent>((_) => refreshParticipants())
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (mounted) Navigator.of(context).pop();
      });

    if (!mounted) return;
    setState(() {
      room = newRoom;
      listener = newListener;
      connecting = false;
    });
    refreshParticipants();
  }

  void refreshParticipants() {
    if (room == null || !mounted) return;
    final all = <lk.Participant>[];
    final local = room!.localParticipant;
    if (local != null) all.add(local);
    all.addAll(room!.remoteParticipants.values);
    setState(() => participants = all);
  }

  lk.VideoTrack? videoTrackOf(lk.Participant participant) {
    for (final publication in participant.videoTrackPublications) {
      if (publication.subscribed && publication.track != null) {
        return publication.track as lk.VideoTrack;
      }
    }
    return null;
  }

  Future<void> toggleMic() async {
    final local = room?.localParticipant;
    if (local == null) return;
    micEnabled = !micEnabled;
    await local.setMicrophoneEnabled(micEnabled);
    setState(() {});
  }

  Future<void> toggleCamera() async {
    final local = room?.localParticipant;
    if (local == null) return;
    cameraEnabled = !cameraEnabled;
    await local.setCameraEnabled(cameraEnabled);
    setState(() {});
  }

  Future<void> leave() async {
    if (widget.isHost) {
      await ApiClient.endLive(widget.liveId);
    }
    await listener?.dispose();
    await room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    chatPollTimer?.cancel();
    listener?.dispose();
    room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: SyrixColors.danger, borderRadius: BorderRadius.circular(6)),
                    child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  if (giftTotal > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.card_giftcard_rounded, color: SyrixColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text("$giftTotal", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_rounded, color: Colors.white),
                    onPressed: shareLive,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: leave,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  connecting
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: SyrixColors.primary),
                              const SizedBox(height: 12),
                              Text(t("live_connecting"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        )
                      : error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
                                ),
                              ),
                            )
                          : buildParticipantsGrid(t),
                  if (!connecting && error == null) ...[
                    Positioned(
                      left: 12,
                      right: 90,
                      bottom: 12,
                      child: SizedBox(
                        height: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: ListView(
                                shrinkWrap: true,
                                reverse: true,
                                children: chatMessages.reversed
                                    .take(30)
                                    .map(
                                      (m) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: "${m["senderUsername"]}  ",
                                                style: const TextStyle(color: SyrixColors.cyan, fontWeight: FontWeight.w700, fontSize: 12),
                                              ),
                                              TextSpan(
                                                text: m["content"] ?? "",
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: TextField(
                                      controller: chatController,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: t("live_chat_hint"),
                                        hintStyle: const TextStyle(color: Colors.white54),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onSubmitted: (_) => sendChatMessage(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                  onPressed: sendChatMessage,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 60,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: sendReaction,
                            child: AnimatedScale(
                              scale: showHeartPulse ? 1.4 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                                child: const Icon(Icons.favorite_rounded, color: SyrixColors.danger, size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text("$reactionCount", style: const TextStyle(color: Colors.white, fontSize: 11)),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => showGiftSheet(
                              context,
                              widget.localeController,
                              widget.liveId,
                              sendOverride: (giftId) => ApiClient.sendLiveGift(widget.liveId, giftId),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                              child: const Icon(Icons.card_giftcard_rounded, color: SyrixColors.primary, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isHost && !connecting && error == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: toggleMic,
                        icon: Icon(micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded, color: SyrixColors.textPrimary),
                        label: Text(
                          micEnabled ? t("live_mute") : t("live_unmute"),
                          style: const TextStyle(color: SyrixColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: toggleCamera,
                        icon: Icon(
                          cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          color: SyrixColors.textPrimary,
                        ),
                        label: Text(
                          cameraEnabled ? t("live_camera_off") : t("live_camera_on"),
                          style: const TextStyle(color: SyrixColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.isHost && !connecting && error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: SyrixColors.danger),
                    onPressed: leave,
                    child: Text(t("live_end")),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildParticipantsGrid(String Function(String) t) {
    if (participants.isEmpty) {
      return Center(
        child: Text(t("live_waiting_host"), style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13)),
      );
    }

    final crossAxisCount = participants.length <= 1 ? 1 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final videoTrack = videoTrackOf(participant);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: SyrixColors.surfaceAlt,
            child: videoTrack != null
                ? lk.VideoTrackRenderer(videoTrack)
                : Center(
                    child: Text(
                      participant.name.isNotEmpty ? participant.name : participant.identity,
                      style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
