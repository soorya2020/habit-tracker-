import '../core/day.dart';
import 'models.dart';

/// The three-a-day rule: a month can hold any number of habits, but no
/// day of the week may have more than [max] of them due.
///
/// Build habits fill their set days. Maintain habits (N times a week) need
/// that many free slots somewhere in the week. Dropping a habit that runs
/// this month is only allowed in its first [graceDays] days; after that
/// the month's habits are locked.
class ThreeRule {
  static const max = 3;
  static const graceDays = 3;

  /// Habits that count toward the limit.
  static bool counts(Habit h) => !h.archived && h.countsForAreas;

  static bool runsIn(Habit h, int month) =>
      h.startCycle <= month && (h.endCycle == null || h.endCycle! >= month);

  static List<Habit> inMonth(Iterable<Habit> habits, int month) => [
        for (final h in habits)
          if (counts(h) && runsIn(h, month)) h
      ];

  /// Build habits set on each weekday (1 = Monday) in [month].
  static Map<int, int> perDay(Iterable<Habit> habits, int month) {
    final out = {for (var d = 1; d <= 7; d++) d: 0};
    for (final h in inMonth(habits, month)) {
      final r = h.current;
      if (r.mode != HabitMode.build) continue;
      for (final d in r.days) {
        out[d] = out[d]! + 1;
      }
    }
    return out;
  }

  /// Weekly sessions planned in [month], out of `7 × max`.
  static int perWeek(Iterable<Habit> habits, int month) {
    var n = 0;
    for (final h in inMonth(habits, month)) {
      n += h.current.mode == HabitMode.build ? h.current.days.length : h.current.perWeek;
    }
    return n;
  }

  /// Weekdays already holding [max] habits in any of [months], leaving out
  /// the habit [exceptId] being edited.
  static Set<int> fullDays(Iterable<Habit> habits, Iterable<int> months, {String? exceptId}) {
    final others = [for (final h in habits) if (h.id != exceptId) h];
    return {
      for (final m in months)
        for (final e in perDay(others, m).entries)
          if (e.value >= max) e.key
    };
  }

  /// Months [h] runs in, up to one past the last month anything is planned.
  static List<int> monthsOf(Habit h, Iterable<Habit> habits) {
    var last = h.startCycle;
    for (final x in habits) {
      if (x.startCycle > last) last = x.startCycle;
      if (x.endCycle != null && x.endCycle! > last) last = x.endCycle!;
    }
    return [for (var m = h.startCycle; m <= last + 1; m++) if (runsIn(h, m)) m];
  }

  /// Why [candidate] doesn't fit with the rest of [habits], or null if it
  /// does. Only what the change adds is checked, so editing a habit never
  /// fails on a day that was already over the limit.
  static String? problem(Iterable<Habit> habits, Habit candidate) {
    if (!counts(candidate)) return null;
    Habit? before;
    for (final h in habits) {
      if (h.id == candidate.id) before = h;
    }
    final all = [for (final h in habits) if (h.id != candidate.id) h, candidate];
    for (final m in monthsOf(candidate, all)) {
      final was = before != null && counts(before) && runsIn(before, m) ? before.current : null;
      final r = candidate.current;
      if (r.mode == HabitMode.build) {
        final days = perDay(all, m);
        for (final d in r.days) {
          final added = was == null || was.mode != HabitMode.build || !was.days.contains(d);
          if (added && days[d]! > max) {
            return '${weekdayNames[d - 1]} already has $max habits in Month $m. Pick other days.';
          }
        }
      }
      final grew = was == null ||
          (r.mode == HabitMode.build ? r.days.length : r.perWeek) >
              (was.mode == HabitMode.build ? was.days.length : was.perWeek);
      if (grew && perWeek(all, m) > 7 * max) {
        return 'Month $m has no free slots left this week. Each day holds $max habits.';
      }
    }
    return null;
  }

  static const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Whether habits can no longer be dropped from [month]: past months,
  /// and the current month once its first [graceDays] days are over.
  static bool locked(int month, int currentMonth, int dayInMonth) =>
      month < currentMonth || (month == currentMonth && dayInMonth > graceDays);

  /// Takes [h] out of [month] onward: a habit that starts in [month] or
  /// later is archived, an older one ends after the month before.
  static Habit dropFrom(Habit h, int month, Day today) => h.startCycle >= month
      ? h.copyWith(archivedOn: () => today)
      : h.copyWith(endCycle: () => month - 1);
}
