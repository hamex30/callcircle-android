import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallCircleApp());
}

class CallCircleApp extends StatelessWidget {
  const CallCircleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CallCircle',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF206055)),
        home: const CallCircleHome(),
      );
}

class CallCircleHome extends StatefulWidget {
  const CallCircleHome({super.key});

  @override
  State<CallCircleHome> createState() => _CallCircleHomeState();
}

class _CallCircleHomeState extends State<CallCircleHome> {
  static const _storageKey = 'callcircle_contacts';
  final _notifications = FlutterLocalNotificationsPlugin();
  WebViewController? _web;
  SharedPreferences? _preferences;
  bool _ready = false;
  bool _notificationReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _preferences = await SharedPreferences.getInstance();
    await _initializeNotifications();
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF4F6F3))
      ..addJavaScriptChannel('CallCircleBridge', onMessageReceived: (message) {
        _saveAndSchedule(message.message);
      })
      ..addJavaScriptChannel('CallCircleLink', onMessageReceived: (message) {
        _openLink(message.message);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri != null &&
              (uri.scheme == 'tel' ||
                  uri.host == 'wa.me' ||
                  uri.host == 'play.google.com')) {
            _openLink(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) async {
          final raw = _preferences?.getString(_storageKey);
          if (raw != null) {
            try {
              final data = jsonDecode(raw);
              if (data is List) {
                await controller.runJavaScript(
                    'window.restoreNativeContacts(${jsonEncode(data)});');
              }
            } catch (_) {/* Corrupt data should not crash the app. */}
          }
          if (mounted) setState(() => _ready = true);
        },
      ));
    _web = controller;
    if (mounted) setState(() {});
    await controller.loadFlutterAsset('assets/callcircle.html');
    final raw = _preferences?.getString(_storageKey);
    if (raw != null) await _schedule(raw);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) _message('Could not open the calling app.');
    } catch (_) {
      if (mounted) _message('Could not open this link.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveAndSchedule(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      await _preferences?.setString(_storageKey, jsonEncode(decoded));
      await _schedule(raw);
    } catch (_) {/* Ignore malformed messages. */}
  }

  Future<void> _initializeNotifications() async {
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _notifications.initialize(
          const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Android 14+ may require a separate permission for exact 10 AM alarms.
      await android?.requestExactAlarmsPermission();
      _notificationReady = true;
    } catch (_) {
      // Contacts and calls continue to work when notifications are denied.
    }
  }

  // Keep up to 90 days of a single grouped reminder per calendar day.
  // Refreshes whenever the user changes a contact or opens the app.
  Future<void> _schedule(String raw) async {
    if (!_notificationReady) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      await _notifications.cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < 90; i++) {
        final day = DateTime(now.year, now.month, now.day + i);
        final scheduled = tz.TZDateTime(tz.local, day.year, day.month, day.day, 10);
        if (!scheduled.isAfter(now)) continue;
        final iso = _iso(day);
        final due = <String>[];
        for (final item in decoded) {
          if (item is! Map) continue;
          final frequency = item['frequency']?.toString() ?? '';
          if (frequency == 'ramadan' ||
              frequency == 'eid-fitr' ||
              frequency == 'eid-adha') continue;
          final date = item['nextDue']?.toString();
          final snooze = item['snoozedUntil']?.toString();
          if (date == null) continue;
          final effective = (snooze != null && snooze.compareTo(date) > 0)
              ? snooze : date;
          if (effective.compareTo(iso) <= 0) {
            final name = item['name']?.toString() ?? '';
            if (name.trim().isNotEmpty) due.add(name.trim());
          }
        }
        if (due.isEmpty) continue;
        final body = due.length <= 4
            ? 'Call ${due.join(', ')}'
            : 'Call ${due.take(4).join(', ')} and ${due.length - 4} more';
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_call_reminders',
            'Call reminders',
            channelDescription: 'Your daily 10 AM list of people to call',
            importance: Importance.high,
            priority: Priority.high,
          ),
        );
        try {
          await _notifications.zonedSchedule(
            1000 + i,
            due.length == 1 ? '1 person to call today' : '${due.length} people to call today',
            body,
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (_) {
          // If Android hasn't granted exact-alarm access, schedule inexactly.
          try {
            await _notifications.zonedSchedule(
              1000 + i,
              due.length == 1 ? '1 person to call today' : '${due.length} people to call today',
              body,
              scheduled,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          } catch (_) {/* The app still works without notifications. */}
        }
      }
    } catch (_) {/* Never lose access to the contacts UI due to notification errors. */}
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          top: false,
          child: Stack(children: [
            if (_web != null) WebViewWidget(controller: _web!),
            if (!_ready)
              const Center(child: CircularProgressIndicator()),
          ]),
        ),
      );
}