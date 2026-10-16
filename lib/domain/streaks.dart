import '../core/day.dart';
import 'schedule.dart';

/// How a past day turned out.
enum DayOutcome { kept, shielded, missed, open, rest }

class StreakState {
  const StreakState({
    required this.current,
    required this.best,
    required this.atRisk,
    required this.shieldReady,
    required this.daysAway,
    required this.outcomes,
  });

  /// Kept days in a row, counting a shielded miss as a bridge.
  final int current;
  final int best;

  /// Yesterday was missed and used the shield: today must be kept.
  final bool atRisk;

  /// A single miss in the next day would be forgiven.
  final bool shieldReady;

  /// Days in a row before today with nothing logged at all.
  final int daysAway;
  final Map<Day, DayOutcome> outcomes;

  static const empty = StreakState(
      current: 0,
      best: 0,
      atRisk: false,
      shieldReady: true,
      daysAway: 0,
      outcomes: {});
}

/// "Don't miss twice": one isolated missed day is forgiven when the next
/// owed day is kept, at most once every [shieldEvery] days.
class StreakEngine {
  const StreakEngine({this.keepThreshold = .5, this.shieldEvery = 7});

  /// Share of a day's work that counts as keeping it.
  final double keepThreshold;
  final int shieldEvery;

  /// Unlogged days stay open this long after they end.
  static const editWindow = Duration(hours: 48);

  /// Whether [d] can still be logged at [now].
  static bool editable(Day d, DateTime now, {int cutoffHour = 3}) =>
      now.isBefore(d.add(1).startsAt(cutoffHour: cutoffHour).add(editWindow));

  StreakState run(Schedule s, Day from, Day today, DateTime now,
      {int cutoffHour = 3}) {
    final outcomes = <Day, DayOutcome>{};
    var current = 0, best = 0;
    Day? lastShield;
    Day? pending; // a miss waiting for the next kept day

    void breakRun() {
      current = 0;
      pending = null;
    }

    for (final d in from.until(today)) {
      final score = s.dayScore(d);
      if (score == null) {
        outcomes[d] = DayOutcome.rest;
        continue;
      }
      final kept = score >= keepThreshold;
      final stillOpen = !s.isClosed(d) &&
          (d == today || editable(d, now, cutoffHour: cutoffHour));
      if (!kept && stillOpen) {
        outcomes[d] = DayOutcome.open;
        continue;
      }
      if (kept) {
        if (pending != null) {
          outcomes[pending!] = DayOutcome.shielded;
          lastShield = pending;
          pending = null;
        }
        current++;
        if (current > best) best = current;
        outcomes[d] = DayOutcome.kept;
        continue;
      }
      outcomes[d] = DayOutcome.missed;
      final shieldFree =
          lastShield == null || d.diff(lastShield) >= shieldEvery;
      if (pending == null && shieldFree && current > 0) {
        pending = d;
      } else {
        breakRun();
      }
    }

    final shieldFree =
        lastShield == null || today.diff(lastShield) >= shieldEvery;

    var away = 0;
    if (!s.ledger.isEmpty) {
      for (var d = today.add(-1); !d.isBefore(from); d = d.add(-1)) {
        if (s.ledger.onDay(d).isNotEmpty) break;
        away++;
      }
    }

    return StreakState(
      current: current,
      best: best,
      atRisk: pending != null,
      shieldReady: pending == null && shieldFree,
      daysAway: away,
      outcomes: outcomes,
    );
  }

  /// Consecutive owed days a single habit was done or tiny, newest first.
  /// Today and yesterday do not break it until they are logged missed.
  int habitStreak(Schedule s, String habitId, Day today, {int lookback = 400}) {
    final h = s.habits.firstWhere((x) => x.id == habitId);
    var n = 0;
    for (var i = 0; i < lookback; i++) {
      final d = today.add(-i);
      if (!s.isDue(h, d)) continue;
      final log = s.ledger.get(h.id, d);
      if (log == null && i <= 1) continue; // still editable
      if (log == null || log.credit == 0) break;
      n++;
    }
    return n;
  }
}
