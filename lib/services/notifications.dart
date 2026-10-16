import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';

/// A tap on Done / Tiny / Snooze, waiting to be written to storage.
class NoticeAction {
  const NoticeAction(this.action, this.habitId, this.owner, this.day);

  final String action; // done, tiny, open
  final String habitId;
  final String owner;
  final String day;

  Map<String, dynamic> toJson() =>
      {'a': action, 'h': habitId, 'o': owner, 'd': day};
  factory NoticeAction.fromJson(Map<String, dynamic> j) => NoticeAction(
      j['a'] as String, j['h'] as String, j['o'] as String, j['d'] as String);
}

const _queueKey = 'notif.queue';
const _category = 'habit';
const _channel = AndroidNotificationDetails(
  'reminders',
  'Reminders',
  channelDescription: 'Habit reminders and evening nudges',
  importance: Importance.high,
  priority: Priority.high,
);
const _snoozeMinutes = 30;

NotificationDetails _details({bool actions = false}) => NotificationDetails(
      android: actions
          ? const AndroidNotificationDetails(
              'reminders',
              'Reminders',
              channelDescription: 'Habit reminders and evening nudges',
              importance: Importance.high,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction('done', 'Done'),
                AndroidNotificationAction('tiny', 'Tiny'),
                AndroidNotificationAction('snooze', 'Snooze 30m'),
              ],
            )
          : _channel,
      iOS: DarwinNotificationDetails(
          categoryIdentifier: actions ? _category : null),
    );

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> _initTimeZone() async {
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }
}

/// Handles button taps while the app is closed. It only queues the tap;
/// the app writes it to storage the next time it opens.
@pragma('vm:entry-point')
Future<void> onBackgroundNotice(NotificationResponse r) async {
  DartPluginRegistrant.ensureInitialized();
  await _handle(r);
}

Future<NoticeAction?> _handle(NotificationResponse r) async {
  final p = r.payload;
  if (p == null || p.isEmpty) return null;
  final j = jsonDecode(p) as Map<String, dynamic>;
  final action = r.actionId ?? 'open';
  if (action == 'snooze') {
    await _initTimeZone();
    await _plugin.zonedSchedule(
      id: (r.id ?? 0) ^ 0x5000,
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: _snoozeMinutes)),
      notificationDetails: _details(actions: true),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: j['t'] as String?,
      body: 'Snoozed. Done, tiny, or snooze again.',
      payload: p,
    );
    return null;
  }
  if (j['h'] == null) return null;
  final a = NoticeAction(action, j['h'] as String, j['o'] as String, j['d'] as String);
  if (action == 'done' || action == 'tiny') {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final q = prefs.getStringList(_queueKey) ?? [];
    q.add(jsonEncode(a.toJson()));
    await prefs.setStringList(_queueKey, q);
  }
  return a;
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _ready = false;

  /// Called when a notice is tapped or answered while the app is running.
  VoidCallback? onQueued;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    await _initTimeZone();
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(_category, actions: [
          DarwinNotificationAction.plain('done', 'Done'),
          DarwinNotificationAction.plain('tiny', 'Tiny'),
          DarwinNotificationAction.plain('snooze', 'Snooze 30m'),
        ]),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: ios,
      ),
      onDidReceiveNotificationResponse: (r) async {
        await _handle(r);
        onQueued?.call();
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotice,
    );
    _ready = true;
  }

  /// Asks for permission. Called after the first habit exists, not on launch.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? true) && (i ?? true);
  }

  /// Taps waiting to be logged, oldest first. Clears the queue.
  Future<List<NoticeAction>> drain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final q = prefs.getStringList(_queueKey) ?? [];
    if (q.isEmpty) return const [];
    await prefs.remove(_queueKey);
    return [
      for (final s in q) NoticeAction.fromJson(jsonDecode(s) as Map<String, dynamic>)
    ];
  }

  /// Replaces every scheduled notice with [notices].
  Future<void> apply(List<Notice> notices, String owner) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final n in notices) {
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: _details(actions: n.habitIds.length == 1),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        payload: jsonEncode({
          't': n.title,
          'o': owner,
          'd': n.day.key,
          if (n.habitIds.length == 1) 'h': n.habitIds.first,
        }),
      );
    }
  }
}
