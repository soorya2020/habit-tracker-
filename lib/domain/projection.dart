import 'dart:math' as math;

import '../core/day.dart';
import 'scoring.dart';
import 'schedule.dart';

/// Where you end up if you keep your recent pace.
class Projection {
  const Projection({required this.xpPerDay, required this.xpNow});

  final double xpPerDay;
  final int xpNow;

  static const paceWindow = 14;

  factory Projection.of(Schedule s, Day today, int xpNow) {
    var sum = 0;
    for (var i = 1; i <= paceWindow; i++) {
      sum += Xp.forDay(s, today.add(-i));
    }
    return Projection(xpPerDay: sum / paceWindow, xpNow: xpNow);
  }

  Level levelIn(int days) => Level.of(xpNow + (xpPerDay * days).round());

  /// Days until [level] at this pace, or null if not moving.
  int? daysTo(int level) {
    final need = Level.xpFor(level) - xpNow;
    if (need <= 0) return 0;
    if (xpPerDay <= 0) return null;
    return (need / xpPerDay).ceil();
  }

  /// Pace if every owed habit were done: a full day is worth [Xp.perDay].
  static double get fullPace => Xp.perDay.toDouble();

  double get paceShare => math.min(1, xpPerDay / fullPace);
}
