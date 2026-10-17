import '../core/day.dart';
import 'models.dart';
import 'scoring.dart';

/// Streak lengths worth celebrating.
class Milestones {
  static const all = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365];

  /// The next milestone above [streak].
  static int next(int streak) => all.firstWhere((m) => m > streak, orElse: () => (streak ~/ 100 + 1) * 100);
}

/// The next title and the areas that stand between you and it.
class TitleGoal {
  const TitleGoal(this.title, this.target, this.needed, this.areas);

  final String title;

  /// Score each area needs.
  final int target;

  /// How many areas must reach [target].
  final int needed;

  /// The areas to watch, closest first, with how far along each is.
  final List<Area> areas;

  /// Areas already at [target].
  int reached(Map<Area, int> v) => areas.where((a) => v[a]! >= target).length;

  /// Null when the top title is already held.
  static TitleGoal? of(Map<Area, int> v, {Set<Area> resting = const {}}) {
    final current = Titles.of(v, resting: resting);
    if (current == Titles.complete) return null;
    final active = [for (final a in Area.values) if (!resting.contains(a)) a]
      ..sort((a, b) => v[b]!.compareTo(v[a]!));
    if (current != Titles.polymath) {
      return TitleGoal(Titles.polymath, Titles.polymathMin, Titles.polymathAreas,
          active.take(Titles.polymathAreas).toList());
    }
    final low = [...active]..sort((a, b) => v[a]!.compareTo(v[b]!));
    return TitleGoal(Titles.complete, Titles.completeMin, active.length, low.take(3).toList());
  }
}

/// One line a day about getting 1% better.
class DailyLine {
  static const lines = [
    '1% better every day is 37 times better in a year.',
    "Don't break the chain. And if it breaks, don't miss twice.",
    'Small enough to do on a bad day. Big enough to matter.',
    'You do not rise to the level of your goals. You fall to the level of your systems.',
    'Every tick is a vote for the person you want to become.',
    'Motivation gets you started. Habit keeps you going.',
    'The tiny version still counts. Showing up is the habit.',
    'Progress, not perfection.',
    "Today's effort is next month's normal.",
    'Discipline is choosing what you want most over what you want now.',
    'The best time to start was yesterday. The next best is today.',
    'A streak is just one good day, repeated.',
    'Be the person who does it anyway.',
    'Slow progress is still progress.',
    'Win the morning, win the day.',
    'Consistency beats intensity.',
    'What you do every day matters more than what you do once in a while.',
    'Make it easy. Make it obvious. Make it satisfying.',
    'One more rep. One more page. One more day.',
    'Future you is watching. Make them proud.',
  ];

  static String of(Day d) => lines[d.diff(Day(2026, 1, 1)).abs() % lines.length];
}
