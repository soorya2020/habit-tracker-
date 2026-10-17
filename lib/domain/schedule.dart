import '../core/day.dart';
import 'models.dart';

/// Finds which programme month a day falls in.
class Calendar {
  Calendar(List<Cycle> cycles)
      : cycles = [...cycles]..sort((a, b) => a.index.compareTo(b.index));

  final List<Cycle> cycles;

  static const cycleLength = 30;

  Cycle? byIndex(int i) {
    for (final c in cycles) {
      if (c.index == i) return c;
    }
    return null;
  }

  /// Last day of cycle [c]: the day before the next one starts.
  Day endOf(Cycle c) {
    final next = byIndex(c.index + 1);
    return next != null ? next.start.add(-1) : c.start.add(cycleLength - 1);
  }

  /// The cycle containing [d]. Before the first cycle returns 0; after the
  /// last, keeps counting in 30-day blocks.
  int indexOf(Day d) {
    if (cycles.isEmpty || d.isBefore(cycles.first.start)) return 0;
    for (final c in cycles.reversed) {
      if (!d.isBefore(c.start)) {
        final over = d.diff(endOf(c));
        return over <= 0 ? c.index : c.index + 1 + (over - 1) ~/ cycleLength;
      }
    }
    return 0;
  }

  /// 1-based day number inside its cycle.
  int dayInCycle(Day d) {
    final c = byIndex(indexOf(d));
    return c == null ? 0 : d.diff(c.start) + 1;
  }

  int lengthOf(Cycle c) => endOf(c).diff(c.start) + 1;

  /// The month after the last one, starting the day after it ends.
  Cycle get next => cycles.isEmpty
      ? Cycle(index: 1, start: Day.today())
      : Cycle(index: cycles.last.index + 1, start: endOf(cycles.last).add(1));
}

/// Logs grouped by habit and day for quick lookups.
class Ledger {
  Ledger(Iterable<LogEntry> logs) {
    for (final l in logs) {
      (_byHabit[l.habitId] ??= {})[l.day] = l;
      (_byDay[l.day] ??= []).add(l);
    }
  }

  final _byHabit = <String, Map<Day, LogEntry>>{};
  final _byDay = <Day, List<LogEntry>>{};

  LogEntry? get(String habitId, Day d) => _byHabit[habitId]?[d];
  List<LogEntry> onDay(Day d) => _byDay[d] ?? const [];
  Map<Day, LogEntry> forHabit(String id) => _byHabit[id] ?? const {};
  bool get isEmpty => _byDay.isEmpty;

  Day? get lastDay => _byDay.isEmpty
      ? null
      : _byDay.keys.reduce((a, b) => a.isAfter(b) ? a : b);

  Day? get firstDay => _byDay.isEmpty
      ? null
      : _byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);

  /// Completions (done or tiny) of a habit in [from]..[to].
  int completions(String habitId, Day from, Day to) {
    var n = 0;
    for (final e in forHabit(habitId).entries) {
      if (!e.key.isBefore(from) && !e.key.isAfter(to) && e.value.credit > 0) {
        n++;
      }
    }
    return n;
  }
}

/// Decides which habits a person owes on a given day.
class Schedule {
  Schedule({
    required this.calendar,
    required this.ledger,
    required this.habits,
    this.comebackUntil,
  });

  final Calendar calendar;
  final Ledger ledger;
  final List<Habit> habits;
  final Day? comebackUntil;

  static const comebackLength = 7;

  /// The habit runs on [d]: inside its months, started, not archived.
  bool inRange(Habit h, Day d) {
    if (d.isBefore(h.rules.first.from)) return false;
    if (h.archivedOn != null && !d.isBefore(h.archivedOn!)) return false;
    final i = calendar.indexOf(d);
    if (i < h.startCycle) return false;
    if (h.endCycle != null && i > h.endCycle!) return false;
    return true;
  }

  bool _inComeback(Day d) =>
      comebackUntil != null &&
      !d.isAfter(comebackUntil!) &&
      d.diff(comebackUntil!) > -comebackLength;

  bool _comebackAllows(Habit h, Day d) {
    if (!_inComeback(d) || h.core) return true;
    return !habits.any((x) => x.core && !x.archived);
  }

  /// Weekly quota for a maintain habit, scaled down for a partial week.
  int quota(Habit h, Day d) {
    final r = h.ruleOn(d);
    final ws = d.weekStart;
    var active = 0;
    for (var i = 0; i < 7; i++) {
      if (inRange(h, ws.add(i))) active++;
    }
    return (r.perWeek * active / 7).ceil();
  }

  /// Completions so far this week before [d].
  int doneThisWeekBefore(Habit h, Day d) {
    if (d == d.weekStart) return 0;
    return ledger.completions(h.id, d.weekStart, d.add(-1));
  }

  /// Whether [h] is owed on [d].
  ///
  /// Build habits are owed on their days. Maintain habits are owed on a day
  /// only when logged that day, or when the week's quota can no longer
  /// be met without it. So doing them any day of the week is fine.
  bool isDue(Habit h, Day d) {
    if (!inRange(h, d) || !_comebackAllows(h, d)) return false;
    final r = h.ruleOn(d);
    if (r.mode == HabitMode.build) return r.days.contains(d.weekday);
    // Any log, even "missed", means the person meant to do it that day.
    if (ledger.get(h.id, d) != null) return true;
    final need = quota(h, d) - doneThisWeekBefore(h, d);
    if (need <= 0) return false;
    var left = 0;
    for (var x = d; x.weekStart == d.weekStart; x = x.add(1)) {
      if (inRange(h, x)) left++;
    }
    return need >= left;
  }

  /// Habits owed on [d].
  List<Habit> dueOn(Day d) => [
        for (final h in habits)
          if (isDue(h, d)) h
      ];

  /// Maintain habits that can be done on [d] but are not owed yet.
  List<Habit> optionalOn(Day d) => [
        for (final h in habits)
          if (inRange(h, d) &&
              _comebackAllows(h, d) &&
              h.ruleOn(d).mode == HabitMode.maintain &&
              !isDue(h, d) &&
              doneThisWeekBefore(h, d) < quota(h, d))
            h
      ];

  /// Share of the day's work kept, 0..1, or null if nothing was owed.
  double? dayScore(Day d) {
    final due = dueOn(d);
    if (due.isEmpty) return null;
    var credit = 0.0;
    for (final h in due) {
      credit += ledger.get(h.id, d)?.credit ?? 0;
    }
    return credit / due.length;
  }

  /// Whether every owed habit on [d] has a log (done, tiny or missed).
  bool isClosed(Day d) {
    final due = dueOn(d);
    return due.isNotEmpty && due.every((h) => ledger.get(h.id, d) != null);
  }
}
