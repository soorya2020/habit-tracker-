import 'dart:math' as math;

import '../core/day.dart';
import 'models.dart';
import 'schedule.dart';

/// XP rules.
///
/// Each day is worth [perDay] XP, split across the habits owed that day:
/// done earns a full share, tiny half. An honest "missed" with a remark
/// earns a small bonus, and each month review earns [perReview].
class Xp {
  static const perDay = 100;
  static const perReview = 50;
  static const honestMiss = 5;

  static int forDay(Schedule s, Day d) {
    final due = s.dueOn(d);
    if (due.isEmpty) return 0;
    var xp = 0.0;
    var bonus = 0;
    for (final h in due) {
      final log = s.ledger.get(h.id, d);
      if (log == null) continue;
      xp += perDay * log.credit / due.length;
      if (log.status == LogStatus.missed &&
          log.source != 'import' &&
          log.remark.trim().isNotEmpty) {
        bonus = honestMiss;
      }
    }
    return xp.round() + bonus;
  }

  /// XP a single habit earns if done on [d] (half if tiny).
  static int shareOf(Schedule s, Habit h, Day d, LogStatus status) {
    final due = s.dueOn(d);
    final n = due.any((x) => x.id == h.id) ? due.length : due.length + 1;
    final credit = switch (status) {
      LogStatus.done => 1.0,
      LogStatus.tiny => .5,
      LogStatus.missed => 0.0,
    };
    return (perDay * credit / math.max(1, n)).round();
  }

  static int total(Schedule s, Day from, Day to, {int reviews = 0}) {
    var sum = 0;
    for (final d in from.until(to)) {
      sum += forDay(s, d);
    }
    return sum + reviews * perReview;
  }
}

/// Level L costs `100 + 50·(L−1)` XP to finish, so early levels come fast
/// and later ones take steady weeks.
class Level {
  const Level(this.level, this.into, this.cost);

  final int level;

  /// XP earned inside the current level.
  final int into;

  /// XP needed to finish the current level.
  final int cost;

  double get progress => cost == 0 ? 0 : into / cost;
  int get toNext => cost - into;

  static int costOf(int level) => 100 + 50 * (level - 1);

  /// Total XP needed to reach [level].
  static int xpFor(int level) {
    var sum = 0;
    for (var l = 1; l < level; l++) {
      sum += costOf(l);
    }
    return sum;
  }

  factory Level.of(int xp) {
    var l = 1, left = xp;
    while (left >= costOf(l)) {
      left -= costOf(l);
      l++;
    }
    return Level(l, left, costOf(l));
  }
}

/// Strength of each area, 0..100.
///
/// Consistency over the last [window] days, weighted so recent days count
/// more (half-life [halfLife] days), times coverage: how close the area is
/// to [targetPerWeek] sessions a week.
class Strengths {
  static const window = 28;
  static const halfLife = 14.0;
  static const targetPerWeek = 4.0;

  static Map<Area, int> of(Schedule s, Day today) {
    final owed = {for (final a in Area.values) a: 0.0};
    final got = {for (final a in Area.values) a: 0.0};
    final sessions = {for (final a in Area.values) a: 0.0};
    for (var i = 0; i < window; i++) {
      final d = today.add(-i);
      final w = math.pow(.5, i / halfLife).toDouble();
      for (final h in s.dueOn(d)) {
        if (!h.countsForAreas) continue;
        final log = s.ledger.get(h.id, d);
        // Today only counts once it is logged.
        if (i == 0 && log == null) continue;
        owed[h.area] = owed[h.area]! + w;
        got[h.area] = got[h.area]! + w * (log?.credit ?? 0);
        sessions[h.area] = sessions[h.area]! + (log?.credit ?? 0);
      }
    }
    return {
      for (final a in Area.values)
        a: owed[a] == 0
            ? 0
            : (100 *
                    (got[a]! / owed[a]!) *
                    math.min(1, sessions[a]! / (window / 7) / targetPerWeek))
                .round()
    };
  }

  /// Weakest active area over strongest, 0..1. 1 means perfectly even.
  static double balance(Map<Area, int> v, Set<Area> resting) {
    final active = [
      for (final a in Area.values)
        if (!resting.contains(a)) v[a]!
    ];
    if (active.isEmpty) return 0;
    final top = active.reduce(math.max);
    if (top == 0) return 0;
    return active.reduce((a, b) => a + b) / active.length / top;
  }
}

/// Titles earned from the shape of your areas.
class Titles {
  static const polymath = 'The Polymath';
  static const complete = 'The Complete Man';
  static const starting = 'The Recruit';

  static const polymathAreas = 3;
  static const polymathMin = 30;
  static const completeMin = 60;
  static const areaMin = 15;

  static List<Area> _active(Set<Area> resting) =>
      [for (final a in Area.values) if (!resting.contains(a)) a];

  static String of(Map<Area, int> v, {Set<Area> resting = const {}}) {
    final active = _active(resting);
    if (active.length >= 4 && active.every((a) => v[a]! >= completeMin)) {
      return complete;
    }
    if (active.where((a) => v[a]! >= polymathMin).length >= polymathAreas) {
      return polymath;
    }
    final best = strongest(v, resting);
    if (best == null || v[best]! < areaMin) return starting;
    return best.title;
  }

  static Area? strongest(Map<Area, int> v, Set<Area> resting) {
    Area? best;
    for (final a in _active(resting)) {
      if (best == null || v[a]! > v[best]!) best = a;
    }
    return best;
  }

  /// One plain sentence on how to reach the next title.
  static String nextStep(Map<Area, int> v, {Set<Area> resting = const {}}) {
    final t = of(v, resting: resting);
    final active = _active(resting);
    if (t == complete) return 'You hold the top title. Keep every area above $completeMin.';
    if (t != polymath) {
      final have = active.where((a) => v[a]! >= polymathMin).length;
      final below = active.where((a) => v[a]! < polymathMin).toList()
        ..sort((a, b) => v[b]!.compareTo(v[a]!));
      final need = below.take(polymathAreas - have).map((a) => a.label);
      return 'Next title: $polymath. Raise ${_join(need)} to $polymathMin.';
    }
    final low = [...active]..sort((a, b) => v[a]!.compareTo(v[b]!));
    return 'Next title: $complete. Every area at $completeMin. Start with ${low.first.label}.';
  }

  static String _join(Iterable<String> xs) {
    final l = xs.toList();
    if (l.length <= 1) return l.join();
    return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
  }
}
