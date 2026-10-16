import 'models.dart';
import 'schedule.dart';

/// How heavy a month's plan is, so new habits don't pile up unnoticed.
class Load {
  const Load(this.habitsPerDay, this.minutesPerDay);

  final double habitsPerDay;
  final int minutesPerDay;

  static const maxHabitsPerDay = 5.5;
  static const maxMinutesPerDay = 120;

  bool get heavy =>
      habitsPerDay > maxHabitsPerDay || minutesPerDay > maxMinutesPerDay;

  /// 0..1+ against the heavier of the two limits.
  double get fill => [
        habitsPerDay / maxHabitsPerDay,
        minutesPerDay / maxMinutesPerDay
      ].reduce((a, b) => a > b ? a : b);

  /// Average daily load for the habits running in [cycle].
  static Load of(Iterable<Habit> habits, Cycle cycle, Calendar cal) {
    final mid = cycle.start.add(cal.lengthOf(cycle) ~/ 2);
    var perDay = 0.0, minutes = 0.0;
    for (final h in habits) {
      if (h.archived || !h.countsForAreas) continue;
      if (h.startCycle > cycle.index) continue;
      if (h.endCycle != null && h.endCycle! < cycle.index) continue;
      final r = h.rules.lastWhere((r) => !r.from.isAfter(mid),
          orElse: () => h.rules.first);
      perDay += r.weeklyLoad / 7;
      minutes += r.weeklyLoad * h.minutes / 7;
    }
    return Load(perDay, minutes.round());
  }
}
