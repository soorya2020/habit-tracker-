import '../core/day.dart';
import 'models.dart';

/// The three-habit rule: at most [max] habits run in any month.
///
/// Adding into a free slot is always allowed. Swapping, pausing or archiving
/// a habit that runs this month is only allowed in the first [graceDays]
/// days of the month; after that the month's habits are locked.
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

  static int countIn(Iterable<Habit> habits, int month) => inMonth(habits, month).length;

  /// The first month that would have more than [max] habits if [candidate]
  /// replaced the habit with the same id, or null if it fits. Months the
  /// habit already ran in are skipped, so editing never fails on a month
  /// that was over the limit before.
  static int? overflow(Iterable<Habit> habits, Habit candidate) {
    Habit? before;
    for (final h in habits) {
      if (h.id == candidate.id) before = h;
    }
    final all = [
      for (final h in habits)
        if (h.id != candidate.id) h,
      candidate,
    ];
    var last = candidate.startCycle;
    for (final h in all) {
      if (h.startCycle > last) last = h.startCycle;
      if (h.endCycle != null && h.endCycle! > last) last = h.endCycle!;
    }
    for (var m = candidate.startCycle; m <= last + 1; m++) {
      if (!runsIn(candidate, m)) continue;
      if (before != null && counts(before) && runsIn(before, m)) continue;
      if (countIn(all, m) > max) return m;
    }
    return null;
  }

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
