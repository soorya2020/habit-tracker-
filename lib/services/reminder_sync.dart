import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day.dart';
import '../domain/models.dart';
import '../domain/reminders.dart';
import '../state/person_view.dart';
import '../state/providers.dart';
import 'notifications.dart';

final reminderSyncProvider = Provider<ReminderSync>((ref) {
  final s = ReminderSync(ref);
  ref.onDispose(s.dispose);
  return s;
});

/// Keeps scheduled notifications in step with the plan and logs, and writes
/// Done / Tiny taps from notifications into storage.
class ReminderSync {
  ReminderSync(this._ref);

  final Ref _ref;
  Timer? _debounce;
  static const _askedKey = 'notif.asked';

  NotificationService get _svc => NotificationService.instance;

  void dispose() => _debounce?.cancel();

  /// Reschedules shortly after the last change.
  void schedule(PersonView me) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      final notices = const ReminderPlanner().plan(me.schedule, me.profile, me.today, DateTime.now());
      _svc.apply(notices, me.uid);
    });
  }

  /// Asks for permission once, after the first habit exists.
  Future<void> ensurePermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);
    await _svc.requestPermission();
  }

  /// Logs taps made on notifications while the app was closed.
  Future<void> drain() async {
    final queued = await _svc.drain();
    if (queued.isEmpty) return;
    final club = _ref.read(repositoryProvider).current;
    final actions = _ref.read(actionsProvider);
    for (final a in queued) {
      final h = club.habits.where((x) => x.id == a.habitId && x.owner == a.owner);
      if (h.isEmpty) continue;
      await actions.log(h.first, Day.parse(a.day),
          a.action == 'tiny' ? LogStatus.tiny : LogStatus.done,
          value: h.first.kind == TrackKind.amount && a.action == 'done'
              ? h.first.ruleOn(Day.parse(a.day)).target
              : null,
          source: 'notification');
    }
  }
}
