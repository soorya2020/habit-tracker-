import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../state/person_view.dart';

/// Keeps the Android home-screen widget showing today's habits.
class WidgetSync {
  static const rows = 6;
  static const _android = 'club.onepercent.one_percent_club.TodayWidget';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Timer? _debounce;

  /// Habit id from a widget tap, such as onepercent://log?habit=s1.
  static String? habitOf(Uri? uri) =>
      uri != null && uri.host == 'log' ? uri.queryParameters['habit'] : null;

  /// Text of one widget row.
  static String row(Habit h, LogEntry? log) => switch (log?.status) {
        LogStatus.done => '✓  ${h.name}',
        LogStatus.tiny => '½  ${h.name} · tiny',
        LogStatus.missed => '✕  ${h.name}',
        null => '○  ${h.name}',
      };

  static void push(PersonView me) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _write(me));
  }

  static Future<void> _write(PersonView me) async {
    final d = me.today;
    final due = me.dueOn(d);
    final done = due.where((h) => me.logOn(h, d) != null).length;
    final date = DateFormat('EEE d MMM').format(d.date);
    final streak = me.streak.current;
    try {
      await HomeWidget.saveWidgetData('title', due.isEmpty ? 'Today · $date' : 'Today · $done of ${due.length} logged');
      await HomeWidget.saveWidgetData(
          'subtitle',
          [if (due.isNotEmpty) date, if (streak > 0) '$streak-day streak', 'Level ${me.level.level}'].join(' · '));
      final shown = due.take(rows).toList();
      await HomeWidget.saveWidgetData('count', shown.length);
      for (var i = 0; i < shown.length; i++) {
        await HomeWidget.saveWidgetData('row$i', row(shown[i], me.logOn(shown[i], d)));
        await HomeWidget.saveWidgetData('habit$i', shown[i].id);
      }
      await HomeWidget.saveWidgetData(
          'more', due.isEmpty ? 'Nothing due today.' : due.length > rows ? '+${due.length - rows} more' : '');
      await HomeWidget.updateWidget(qualifiedAndroidName: _android);
    } catch (_) {
      // The widget is a convenience; never let it break the app.
    }
  }
}
