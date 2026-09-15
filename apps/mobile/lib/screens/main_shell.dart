import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "../i18n/locale_controller.dart";
import "../widgets/bottom_nav.dart";
import "../services/call_service.dart";
import "../services/api_client.dart";
import "../services/pin_service.dart";
import "../services/parental_control_service.dart";
import "parental_control_screen.dart";
import "home_chats_screen.dart";
import "notifications_screen.dart";
import "groups_screen.dart";
import "live_screen.dart";
import "profile_screen.dart";
import "call_screen.dart";
import "pin_lock_screen.dart";

class MainShell extends StatefulWidget {
  final LocaleController localeController;

  const MainShell({super.key, required this.localeController});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int currentIndex = 0;
  StreamSubscription? callSub;
  bool dialogShowing = false;
  bool locked = false;

  Future<void> selectTab(int index) async {
    if (index == 2 && await ParentalControlService.isEnabled()) {
      final unlocked = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ParentalGateScreen(localeController: widget.localeController)),
      );
      if (unlocked != true) return;
    }
    setState(() => currentIndex = index);
  }
  bool pinChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CallService.instance.connect();
    callSub = CallService.instance.callEvents.listen(handleCallEvent);
    checkLockOnStart();
  }

  Future<void> checkLockOnStart() async {
    final hasPin = await PinService.hasPin();
    if (mounted) {
      setState(() {
        locked = hasPin;
        pinChecked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && pinChecked) {
      PinService.hasPin().then((hasPin) {
        if (hasPin && mounted) setState(() => locked = true);
      });
    }
  }

  void handleCallEvent(Map<String, dynamic> event) {
    if (event["callEvent"] == "invite" && !dialogShowing) {
      showIncomingCall(event);
    } else if (event["callEvent"] == "declined" || event["callEvent"] == "ended") {
      if (dialogShowing && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShowing = false;
      }
    }
  }

  Future<void> showIncomingCall(Map<String, dynamic> event) async {
    final t = widget.localeController.t;
    dialogShowing = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16213A),
          title: Text(
            event["mode"] == "video" ? t("call_incoming_video") : t("call_incoming_voice"),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            event["fromUsername"] ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t("call_decline")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t("call_accept")),
            ),
          ],
        );
      },
    );
    dialogShowing = false;

    if (accepted == true) {
      final response = await ApiClient.answerCall(event["roomName"]);
      if (response.statusCode == 200 && mounted) {
        final body = jsonDecode(response.body);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              localeController: widget.localeController,
              roomName: body["roomName"],
              token: body["token"],
              url: body["url"],
              mode: event["mode"],
              otherUserId: event["fromUserId"],
              otherUsername: event["fromUsername"] ?? "",
            ),
          ),
        );
      }
    } else {
      await ApiClient.declineCall(event["roomName"], event["fromUserId"]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.localeController.t;
    final screens = [
      HomeChatsScreen(localeController: widget.localeController),
      GroupsScreen(localeController: widget.localeController),
      LiveScreen(localeController: widget.localeController),
      NotificationsScreen(localeController: widget.localeController),
      ProfileScreen(localeController: widget.localeController),
    ];

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: currentIndex, children: screens),
          bottomNavigationBar: SyrixBottomNav(
            currentIndex: currentIndex,
            onTap: (index) => selectTab(index),
            localeController: widget.localeController,
          ),
        ),
        if (locked)
          PinLockScreen(
            localeController: widget.localeController,
            onUnlocked: () => setState(() => locked = false),
          ),
      ],
    );
  }
}
