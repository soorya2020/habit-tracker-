import '../core/day.dart';
import '../data/repository.dart';
import '../domain/load.dart';
import '../domain/models.dart';
import '../domain/projection.dart';
import '../domain/schedule.dart';
import '../domain/scoring.dart';
import '../domain/streaks.dart';

/// Everything the screens need about one person, computed once per change.
class PersonView {
  PersonView._({
    required this.profile,
    required this.data,
    required this.calendar,
    required this.schedule,
    required this.today,
    required this.now,
    required this.streak,
    required this.xp,
    required this.strengths,
  });

  factory PersonView.of(ClubData data, String uid, DateTime now) {
    final profile = data.profile(uid) ?? Profile(uid: uid, name: 'You');
    final cal = Calendar(data.cycles);
    final today = Day.of(now, cutoffHour: profile.cutoffHour);
    final habits = data.habitsOf(uid);
    final s = Schedule(
      calendar: cal,
      ledger: Ledger(data.logsOf(uid)),
      habits: habits,
      comebackUntil: profile.comebackUntil,
    );
    final start = _firstDay(cal, habits, today);
    final streak = const StreakEngine()
        .run(s, start, today, now, cutoffHour: profile.cutoffHour);
    final xp =
        Xp.total(s, start, today, reviews: data.reviewsOf(uid).length);
    return PersonView._(
      profile: profile,
      data: data,
      calendar: cal,
      schedule: s,
      today: today,
      now: now,
      streak: streak,
      xp: xp,
      strengths: Strengths.of(s, today),
    );
  }

  static Day _firstDay(Calendar cal, List<Habit> habits, Day today) {
    var d = cal.cycles.isEmpty ? today : cal.cycles.first.start;
    for (final h in habits) {
      if (h.rules.first.from.isBefore(d)) d = h.rules.first.from;
    }
    return d.isAfter(today) ? today : d;
  }

  final Profile profile;
  final ClubData data;
  final Calendar calendar;
  final Schedule schedule;
  final Day today;
  final DateTime now;
  final StreakState streak;
  final int xp;
  final Map<Area, int> strengths;

  String get uid => profile.uid;
  Level get level => Level.of(xp);
  String get title => Titles.of(strengths, resting: profile.resting);
  String get nextStep => Titles.nextStep(strengths, resting: profile.resting);
  double get balance => Strengths.balance(strengths, profile.resting);
  int get cycleIndex => calendar.indexOf(today);
  int get dayInCycle => calendar.dayInCycle(today);
  Cycle? get cycle => calendar.byIndex(cycleIndex);
  Projection get projection => Projection.of(schedule, today, xp);

  List<Habit> get habits => schedule.habits;
  List<Habit> get activeHabits => [
        for (final h in habits)
          if (!h.archived && h.countsForAreas) h
      ];

  List<Habit> dueOn(Day d) {
    final xs = schedule.dueOn(d);
    // Not done first, in reminder order; done ones sink.
    xs.sort((a, b) {
      final da = logOn(a, d) != null ? 1 : 0, db = logOn(b, d) != null ? 1 : 0;
      if (da != db) return da - db;
      return (a.ruleOn(d).reminder ?? 9999).compareTo(b.ruleOn(d).reminder ?? 9999);
    });
    return xs;
  }

  List<Habit> optionalOn(Day d) => schedule.optionalOn(d);
  LogEntry? logOn(Habit h, Day d) => schedule.ledger.get(h.id, d);
  int habitStreak(Habit h) =>
      const StreakEngine().habitStreak(schedule, h.id, today);

  /// Owed habits on [d] that have no log yet.
  int openOn(Day d) => dueOn(d).where((h) => logOn(h, d) == null).length;

  double? scoreOn(Day d) => schedule.dayScore(d);

  /// Yesterday still has unlogged habits and can be edited.
  bool get yesterdayOpen {
    final y = today.add(-1);
    return openOn(y) > 0 &&
        StreakEngine.editable(y, now, cutoffHour: profile.cutoffHour);
  }

  bool get inComeback =>
      profile.comebackUntil != null && !today.isAfter(profile.comebackUntil!);

  /// Offer a comeback week after 3+ days with nothing logged.
  bool get offerComeback =>
      streak.daysAway >= 3 &&
      !inComeback &&
      profile.comebackDeclined != today &&
      activeHabits.isNotEmpty;

  /// Share of closed days kept in a cycle, 0..1. Open days don't count yet.
  double cyclePercent(Cycle c) {
    final end = calendar.endOf(c);
    final last = end.isAfter(today) ? today : end;
    var owed = 0, kept = 0;
    for (final d in c.start.until(last)) {
      final o = streak.outcomes[d];
      if (o == null || o == DayOutcome.open || o == DayOutcome.rest) continue;
      owed++;
      if (o == DayOutcome.kept) kept++;
    }
    return owed == 0 ? 0 : kept / owed;
  }

  Load loadOf(Cycle c) => Load.of(habits, c, calendar);

  Review? reviewOf(int cycle) {
    for (final r in data.reviewsOf(uid)) {
      if (r.cycle == cycle) return r;
    }
    return null;
  }

  Day? get lastLogDay => schedule.ledger.lastDay;
}
