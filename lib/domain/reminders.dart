import '../core/day.dart';
import 'models.dart';
import 'schedule.dart';

class Notice {
  const Notice({
    required this.id,
    required this.at,
    required this.day,
    required this.title,
    required this.body,
    this.habitIds = const [],
    this.nudge = false,
  });

  final int id;
  final DateTime at;
  final Day day;
  final String title;
  final String body;

  /// One habit means the notice gets Done / Tiny / Snooze buttons.
  final List<String> habitIds;
  final bool nudge;
}

/// Decides which reminders to send over the next [days] days.
///
/// Habit reminders go out at each habit's time unless already logged.
/// Evening nudges go out only while the day still has open habits. Nothing
/// is sent in quiet hours, and no day gets more than [maxPerDay]; extra
/// reminders are merged into the nearest later one.
class ReminderPlanner {
  const ReminderPlanner({this.days = 7, this.maxPerDay = 4});

  final int days;
  final int maxPerDay;

  static int idFor(String key) => key.hashCode & 0x7fffffff;

  static bool quiet(int minute, Profile p) => p.quietStart > p.quietEnd
      ? minute >= p.quietStart || minute < p.quietEnd
      : minute >= p.quietStart && minute < p.quietEnd;

  List<Notice> plan(Schedule s, Profile p, Day today, DateTime now) {
    if (!p.remindersOn) return const [];
    final out = <Notice>[];
    for (var i = 0; i < days; i++) {
      final d = today.add(i);
      final due = s.dueOn(d);
      final open = [
        for (final h in due)
          if (s.ledger.get(h.id, d) == null) h
      ];
      if (open.isEmpty) continue;

      final nudges = [
        for (final m in p.nudges)
          if (!quiet(m, p) && d.at(m).isAfter(now)) m
      ]..sort();

      // Group open habits by reminder minute.
      final groups = <int, List<Habit>>{};
      for (final h in open) {
        final m = h.ruleOn(d).reminder;
        if (m == null || quiet(m, p) || !d.at(m).isAfter(now)) continue;
        (groups[m] ??= []).add(h);
      }
      final times = groups.keys.toList()..sort();
      final budget = (maxPerDay - nudges.length).clamp(0, maxPerDay);
      while (times.length > budget && times.isNotEmpty) {
        if (times.length == 1) {
          groups.remove(times.removeLast());
          break;
        }
        // Merge the closest neighbouring pair into the later time,
        // preferring smaller groups when gaps tie.
        var best = 0;
        int gap(int j) => times[j + 1] - times[j];
        int size(int j) => groups[times[j]]!.length + groups[times[j + 1]]!.length;
        for (var j = 1; j < times.length - 1; j++) {
          if (gap(j) < gap(best) || (gap(j) == gap(best) && size(j) < size(best))) best = j;
        }
        groups[times[best + 1]]!.insertAll(0, groups.remove(times[best])!);
        times.removeAt(best);
      }

      for (final m in times) {
        final hs = groups[m]!;
        final one = hs.length == 1;
        out.add(Notice(
          id: idFor('${d.key}_r$m'),
          at: d.at(m),
          day: d,
          title: one ? hs.first.name : '${hs.length} habits now',
          body: one
              ? (hs.first.tiny.isEmpty
                  ? 'Time for it.'
                  : 'Short on time? The tiny version is ${hs.first.tiny}.')
              : hs.map((h) => h.name).join(', '),
          habitIds: one ? [hs.first.id] : const [],
        ));
      }

      for (var k = 0; k < nudges.length; k++) {
        final last = k == nudges.length - 1;
        out.add(Notice(
          id: idFor('${d.key}_n$k'),
          at: d.at(nudges[k]),
          day: d,
          nudge: true,
          title: last ? "Don't let today go blank" : 'Close your day',
          body: i == 0
              ? '${open.length} of ${due.length} still open. Log them, or mark a miss with a note.'
              : 'Log what you did today. A tiny version still counts.',
        ));
      }
    }
    return out;
  }
}
