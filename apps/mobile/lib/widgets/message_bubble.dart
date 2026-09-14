import "dart:async";
import "dart:convert";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/gestures.dart";
import "package:audioplayers/audioplayers.dart";
import "package:url_launcher/url_launcher.dart";
import "../theme/app_theme.dart";
import "../i18n/locale_controller.dart";
import "verified_badge.dart";
import "../services/vault_service.dart";
import "../services/personalization_service.dart";

class MessageBubble extends StatefulWidget {
  final String? messageId;
  final String content;
  final bool isMine;
  final String type;
  final bool pinned;
  final bool edited;
  final bool spoiler;
  final bool deletedForEveryone;
  final Map<String, dynamic>? replyTo;
  final int? durationSeconds;
  final String? expireAt;
  final VoidCallback? onExpired;
  final List<Map<String, dynamic>> reactions;
  final String? currentUserId;
  final LocaleController localeController;
  final String? senderName;
  final bool senderIsPremium;
  final bool showSenderName;
  final Future<void> Function(String emoji)? onToggleReaction;
  final Future<void> Function()? onTogglePin;
  final Future<String?> Function()? onEdit;
  final void Function(String username)? onMentionTap;
  final VoidCallback? onForward;
  final Future<String?> Function()? onTranslate;
  final Future<String?> Function()? onTranscribe;
  final VoidCallback? onReply;
  final Future<void> Function()? onDeleteForMe;
  final Future<void> Function()? onDeleteForEveryone;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isMine,
    required this.localeController,
    this.messageId,
    this.type = "text",
    this.pinned = false,
    this.edited = false,
    this.spoiler = false,
    this.deletedForEveryone = false,
    this.replyTo,
    this.durationSeconds,
    this.expireAt,
    this.onExpired,
    this.reactions = const [],
    this.currentUserId,
    this.senderName,
    this.senderIsPremium = false,
    this.showSenderName = false,
    this.onToggleReaction,
    this.onTogglePin,
    this.onEdit,
    this.onMentionTap,
    this.onForward,
    this.onTranslate,
    this.onTranscribe,
    this.onReply,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

const List<String> _quickEmojis = ["\u2764\uFE0F", "\uD83D\uDE02", "\uD83D\uDE2E", "\uD83D\uDE22", "\uD83D\uDC4D", "\uD83D\uDE4F"];

class _MessageBubbleState extends State<MessageBubble> {
  bool revealed = false;
  bool translating = false;
  bool showHeartBurst = false;
  bool downloadingVoice = false;
  String? translatedText;
  bool transcribing = false;
  String? transcript;
  final audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration playbackPosition = Duration.zero;
  Timer? expiryTimer;

  @override
  void initState() {
    super.initState();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => isPlaying = state == PlayerState.playing);
    });
    audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => playbackPosition = position);
    });
    audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playbackPosition = Duration.zero);
    });
    scheduleExpiry();
  }

  void scheduleExpiry() {
    if (widget.expireAt == null) return;
    final expiry = DateTime.tryParse(widget.expireAt!);
    if (expiry == null) return;
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired?.call());
      return;
    }
    expiryTimer = Timer(remaining, () => widget.onExpired?.call());
  }

  Duration? get expiryCountdown {
    if (widget.expireAt == null) return null;
    final expiry = DateTime.tryParse(widget.expireAt!);
    if (expiry == null) return null;
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    expiryTimer?.cancel();
    super.dispose();
  }

  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final r in widget.reactions) {
      final emoji = r["emoji"] as String? ?? "";
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  bool get mineReacted {
    if (widget.currentUserId == null) return false;
    return widget.reactions.any((r) => r["userId"] == widget.currentUserId && r["emoji"] == _quickEmojis[0]);
  }

  Future<void> handleDoubleTap() async {
    if (widget.messageId == null || widget.onToggleReaction == null) return;
    if (!PersonalizationService.batterySaverEnabled) {
      setState(() => showHeartBurst = true);
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted) setState(() => showHeartBurst = false);
      });
    }
    await widget.onToggleReaction!(_quickEmojis[0]);
  }

  Future<void> handleTranslate() async {
    if (widget.onTranslate == null) return;
    setState(() => translating = true);
    final result = await widget.onTranslate!();
    if (!mounted) return;
    setState(() {
      translating = false;
      translatedText = result;
    });
  }

  Future<void> handleTranscribe() async {
    if (widget.onTranscribe == null) return;
    setState(() => transcribing = true);
    final result = await widget.onTranscribe!();
    if (!mounted) return;
    setState(() {
      transcribing = false;
      transcript = result;
    });
  }

  Future<void> togglePlayback() async {
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play(UrlSource(widget.content));
    }
  }

  Future<void> exportAudio() async {
    final uri = Uri.tryParse(widget.content);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void openActionMenu() {
    if (widget.messageId == null || widget.deletedForEveryone) return;
    final t = widget.localeController.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: SyrixColors.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Wrap(
                  spacing: 14,
                  children: _quickEmojis.map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onToggleReaction?.call(emoji);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: SyrixColors.border),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: SyrixColors.textPrimary),
                title: Text(t("chat_reply"), style: const TextStyle(color: SyrixColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReply?.call();
                },
              ),
              if (widget.onForward != null)
                ListTile(
                  leading: const Icon(Icons.forward_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_forward"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onForward?.call();
                  },
                ),
              if (widget.type == "image")
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_save_to_vault"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(context);
                    await VaultService.addItem({"mediaUrl": widget.content});
                  },
                ),
              if (widget.type == "text")
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_translate"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    handleTranslate();
                  },
                ),
              if (widget.type == "voice") ...[
                ListTile(
                  leading: const Icon(Icons.subtitles_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_transcribe"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    handleTranscribe();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_export_audio"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    exportAudio();
                  },
                ),
              ],
              if (widget.isMine && widget.type == "text")
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: SyrixColors.textPrimary),
                  title: Text(t("chat_edit"), style: const TextStyle(color: SyrixColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit?.call();
                  },
                ),
              ListTile(
                leading: Icon(
                  widget.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: SyrixColors.textPrimary,
                ),
                title: Text(
                  widget.pinned ? t("chat_unpin") : t("chat_pin"),
                  style: const TextStyle(color: SyrixColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onTogglePin?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: SyrixColors.danger),
                title: Text(t("chat_delete_for_me"), style: const TextStyle(color: SyrixColors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDeleteForMe?.call();
                },
              ),
              if (widget.isMine)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: SyrixColors.danger),
                  title: Text(t("chat_delete_for_everyone"), style: const TextStyle(color: SyrixColors.danger)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDeleteForEveryone?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildReplyPreview() {
    if (widget.replyTo == null) return const SizedBox.shrink();
    final reply = widget.replyTo!;
    final replyType = reply["type"] as String? ?? "text";
    final replyContent = replyType == "image" ? "\uD83D\uDDBC" : (reply["content"] as String? ?? "");
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: SyrixColors.primary, width: 3)),
      ),
      child: Text(
        replyContent.isEmpty ? " " : replyContent,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: SyrixColors.textPrimary.withOpacity(0.75), fontSize: 12.5),
      ),
    );
  }

  Widget buildReactionRow() {
    final counts = reactionCounts;
    if (counts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SyrixColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SyrixColors.border),
            ),
            child: Text("${entry.key} ${entry.value}", style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget buildExpiryBadge() {
    final remaining = expiryCountdown;
    if (remaining == null) return const SizedBox.shrink();
    String label;
    if (remaining.inDays >= 1) {
      label = "${remaining.inDays}j";
    } else if (remaining.inHours >= 1) {
      label = "${remaining.inHours}h";
    } else if (remaining.inMinutes >= 1) {
      label = "${remaining.inMinutes}min";
    } else {
      label = "${remaining.inSeconds}s";
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: SyrixColors.textPrimary.withOpacity(0.6)),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: SyrixColors.textPrimary.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget buildSenderName() {
    if (!widget.showSenderName || widget.senderName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 2),
      child: UsernameWithBadge(
        username: widget.senderName!,
        isPremium: widget.senderIsPremium,
        badgeSize: 12,
        style: const TextStyle(color: SyrixColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  List<InlineSpan> parseFancySpans(String text) {
    final regex = RegExp(r"\*([^\*\n]+)\*|_([^_\n]+)_|~([^~\n]+)~|`([^`\n]+)`");
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(text: match.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(text: match.group(3), style: const TextStyle(decoration: TextDecoration.lineThrough)));
      } else if (match.group(4) != null) {
        spans.add(
          TextSpan(
            text: match.group(4),
            style: const TextStyle(fontFamily: "monospace", backgroundColor: SyrixColors.surfaceAlt),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Widget buildRichContent() {
    final regex = RegExp(r"(@[a-zA-Z0-9_]{3,20})|(https?://[^\s]+)");
    final matches = regex.allMatches(widget.content);
    if (matches.isEmpty) {
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 15),
          children: parseFancySpans(widget.content),
        ),
      );
    }
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.addAll(parseFancySpans(widget.content.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith("@")) {
        spans.add(
          TextSpan(
            text: token,
            style: const TextStyle(color: SyrixColors.primary, fontWeight: FontWeight.w600),
            recognizer: TapGestureRecognizer()
              ..onTap = () => widget.onMentionTap?.call(token.substring(1)),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token,
            style: const TextStyle(color: SyrixColors.cyan),
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(Uri.parse(token), mode: LaunchMode.externalApplication),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < widget.content.length) {
      spans.addAll(parseFancySpans(widget.content.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 15),
        children: spans,
      ),
    );
  }

  Widget buildPinnedBadge() {
    if (!widget.pinned) return const SizedBox.shrink();
    final t = widget.localeController.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_rounded, size: 12, color: SyrixColors.primary),
          const SizedBox(width: 3),
          Text(t("chat_pinned_badge"), style: const TextStyle(fontSize: 11, color: SyrixColors.primary)),
        ],
      ),
    );
  }

  Widget buildImageBubble(BuildContext context) {
    final t = widget.localeController.t;
    final blurred = widget.spoiler && !revealed;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        widget.content,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          height: 140,
          color: SyrixColors.surfaceAlt,
          child: const Icon(Icons.broken_image_rounded, color: SyrixColors.textMuted),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
      child: Column(
        crossAxisAlignment: widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          buildSenderName(),
          buildPinnedBadge(),
            buildExpiryBadge(),
          buildReplyPreview(),
          Stack(
            alignment: Alignment.center,
            children: [
              if (blurred)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: image,
                  ),
                )
              else
                image,
              if (blurred)
                GestureDetector(
                  onTap: () => setState(() => revealed = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(t("chat_spoiler_tap_to_reveal"), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          buildReactionRow(),
        ],
      ),
    );
  }

  Future<void> downloadVoice() async {
    if (downloadingVoice) return;
    setState(() => downloadingVoice = true);
    try {
      await launchUrl(Uri.parse(widget.content), mode: LaunchMode.externalApplication);
    } catch (_) {
    } finally {
      if (mounted) setState(() => downloadingVoice = false);
    }
  }

  Widget buildVoiceBubble(BuildContext context) {
    final t = widget.localeController.t;
    final totalSeconds = widget.durationSeconds ?? 0;
    final remaining = isPlaying || playbackPosition.inSeconds > 0
        ? (totalSeconds - playbackPosition.inSeconds).clamp(0, totalSeconds)
        : totalSeconds;
    final minutes = (remaining ~/ 60).toString().padLeft(2, "0");
    final seconds = (remaining % 60).toString().padLeft(2, "0");
    final progress = totalSeconds == 0 ? 0.0 : (playbackPosition.inSeconds / totalSeconds).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: widget.isMine ? SyrixColors.primary : SyrixColors.surfaceAlt,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
          bottomRight: Radius.circular(widget.isMine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSenderName(),
          buildPinnedBadge(),
            buildExpiryBadge(),
          buildReplyPreview(),
          Row(
            children: [
              GestureDetector(
                onTap: togglePlayback,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: SyrixColors.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.black.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation(SyrixColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text("$minutes:$seconds", style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 12)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: downloadVoice,
                child: downloadingVoice
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: SyrixColors.textPrimary),
                      )
                    : const Icon(Icons.file_download_outlined, color: SyrixColors.textPrimary, size: 16),
              ),
            ],
          ),
          if (transcribing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t("chat_transcribing"),
                style: TextStyle(color: SyrixColors.textPrimary.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          if (!transcribing && transcript != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(transcript!, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 13)),
            ),
          buildReactionRow(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;

    if (widget.deletedForEveryone) {
      return Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: SyrixColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SyrixColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 14, color: SyrixColors.textMuted),
              const SizedBox(width: 6),
              Text(
                t("chat_message_deleted"),
                style: const TextStyle(color: SyrixColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.type == "gift") {
      Map<String, dynamic> gift = {};
      try {
        gift = Map<String, dynamic>.from(jsonDecode(widget.content));
      } catch (_) {}
      return Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [SyrixColors.primary, SyrixColors.primaryDark]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                "${gift["label"] ?? "Gift"} (${gift["cost"] ?? 0})",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    Widget bubbleContent;
    if (widget.type == "image") {
      bubbleContent = buildImageBubble(context);
    } else if (widget.type == "voice") {
      bubbleContent = buildVoiceBubble(context);
    } else {
      bubbleContent = Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: widget.isMine ? SyrixColors.primary : SyrixColors.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMine ? 16 : 4),
            bottomRight: Radius.circular(widget.isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSenderName(),
            buildPinnedBadge(),
            buildExpiryBadge(),
            buildReplyPreview(),
            buildRichContent(),
            if (widget.edited)
              Text(
                widget.localeController.t("message_edited"),
                style: const TextStyle(color: SyrixColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            if (translating)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t("chat_translating"),
                  style: TextStyle(color: SyrixColors.textPrimary.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            if (!translating && translatedText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () => setState(() => translatedText = null),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 1, color: SyrixColors.textPrimary.withOpacity(0.25)),
                      const SizedBox(height: 6),
                      Text(translatedText!, style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        t("chat_show_original"),
                        style: TextStyle(color: SyrixColors.textPrimary.withOpacity(0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            buildReactionRow(),
          ],
        ),
      );
    }

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: handleDoubleTap,
        onLongPress: openActionMenu,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            bubbleContent,
            if (showHeartBurst)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.4),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (context, scale, child) => Opacity(
                  opacity: (1.4 - scale).clamp(0.0, 1.0) + 0.3,
                  child: Transform.scale(scale: scale, child: child),
                ),
                child: const Icon(Icons.favorite_rounded, color: SyrixColors.cyan, size: 56),
              ),
          ],
        ),
      ),
    );
  }
}
