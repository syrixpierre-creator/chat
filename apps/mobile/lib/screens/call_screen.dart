import "package:flutter/material.dart";
import "package:livekit_client/livekit_client.dart" as lk;
import "package:permission_handler/permission_handler.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "../services/api_client.dart";

class CallScreen extends StatefulWidget {
  final LocaleController localeController;
  final String roomName;
  final String token;
  final String url;
  final String mode;
  final String otherUserId;
  final String otherUsername;

  const CallScreen({
    super.key,
    required this.localeController,
    required this.roomName,
    required this.token,
    required this.url,
    required this.mode,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  lk.Room? room;
  lk.EventsListener<lk.RoomEvent>? listener;
  lk.Participant? remoteParticipant;
  bool connecting = true;
  bool micEnabled = true;
  bool cameraEnabled = true;
  String? error;

  bool get isVideo => widget.mode == "video";

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    final permissions = isVideo
        ? await [Permission.camera, Permission.microphone].request()
        : await [Permission.microphone].request();

    final denied = permissions.values.any((status) => !status.isGranted);
    if (denied) {
      setState(() {
        connecting = false;
        error = widget.localeController.t("live_permission_denied");
      });
      return;
    }

    final newRoom = lk.Room();
    final newListener = newRoom.createListener();

    try {
      await newRoom.connect(widget.url, widget.token);
    } catch (_) {
      setState(() {
        connecting = false;
        error = widget.localeController.t("live_connection_error");
      });
      return;
    }

    await newRoom.localParticipant?.setMicrophoneEnabled(true);
    if (isVideo) {
      await newRoom.localParticipant?.setCameraEnabled(true);
    }

    newListener
      ..on<lk.ParticipantConnectedEvent>((_) => refreshRemote())
      ..on<lk.ParticipantDisconnectedEvent>((_) {
        if (mounted) Navigator.of(context).pop();
      })
      ..on<lk.TrackSubscribedEvent>((_) => refreshRemote())
      ..on<lk.TrackUnsubscribedEvent>((_) => refreshRemote())
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (mounted) Navigator.of(context).pop();
      });

    if (!mounted) return;
    setState(() {
      room = newRoom;
      listener = newListener;
      connecting = false;
    });
    refreshRemote();
  }

  void refreshRemote() {
    if (room == null || !mounted) return;
    setState(() {
      remoteParticipant = room!.remoteParticipants.values.isNotEmpty
          ? room!.remoteParticipants.values.first
          : null;
    });
  }

  lk.VideoTrack? videoTrackOf(lk.Participant? participant) {
    if (participant == null) return null;
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

  Future<void> hangUp() async {
    await ApiClient.endCall(widget.roomName, widget.otherUserId);
    await listener?.dispose();
    await room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    listener?.dispose();
    room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final remoteVideo = videoTrackOf(remoteParticipant);
    final localVideo = isVideo ? videoTrackOf(room?.localParticipant) : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: connecting
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: SyrixColors.primary),
                          const SizedBox(height: 12),
                          Text(t("live_connecting"), style: const TextStyle(color: SyrixColors.textMuted)),
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
                              style: const TextStyle(color: SyrixColors.textMuted),
                            ),
                          ),
                        )
                      : remoteVideo != null
                          ? lk.VideoTrackRenderer(remoteVideo)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundColor: SyrixColors.surfaceAlt,
                                    child: Text(
                                      widget.otherUsername.isNotEmpty ? widget.otherUsername[0].toUpperCase() : "?",
                                      style: const TextStyle(color: Colors.white, fontSize: 30),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(widget.otherUsername, style: const TextStyle(color: Colors.white, fontSize: 18)),
                                ],
                              ),
                            ),
            ),
            if (isVideo && localVideo != null)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SyrixColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: lk.VideoTrackRenderer(localVideo),
                ),
              ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _controlButton(
                    icon: micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                    onTap: toggleMic,
                  ),
                  const SizedBox(width: 20),
                  _controlButton(
                    icon: Icons.call_end_rounded,
                    onTap: hangUp,
                    background: SyrixColors.danger,
                  ),
                  if (isVideo) ...[
                    const SizedBox(width: 20),
                    _controlButton(
                      icon: cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      onTap: toggleCamera,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, required VoidCallback onTap, Color? background}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: background ?? SyrixColors.surfaceAlt,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
