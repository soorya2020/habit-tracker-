import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/core/day.dart';
import 'package:one_percent_club/data/seed.dart';
import 'package:one_percent_club/domain/models.dart';
import 'package:one_percent_club/domain/scoring.dart';
import 'package:one_percent_club/domain/schedule.dart';
import 'package:one_percent_club/domain/streaks.dart';

final _cal = Calendar(SheetImport.cycles);

Habit _habit({
  String id = 'h',
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  HabitMode mode = HabitMode.build,
  int perWeek = 3,
  Day? from,
  int startCycle = 1,
  int? endCycle,
  Area area = Area.mind,
  bool core = false,
}) =>
    Habit(
      id: id,
      owner: 'u',
      name: id,
      area: area,
      core: core,
      startCycle: startCycle,
      endCycle: endCycle,
      rules: [
        HabitRule(
            from: from ?? Day(2026, 8, 17),
            mode: mode,
            days: days,
            perWeek: perWeek)
      ],
    );

LogEntry _log(String h, Day d, LogStatus s, {String remark = ''}) => LogEntry(
    habitId: h,
    owner: 'u',
    day: d,
    status: s,
    remark: remark,
    updatedAt: DateTime(2026));

Schedule _sched(List<Habit> hs, List<LogEntry> logs, {Day? comeback}) =>
    Schedule(
        calendar: _cal,
        ledger: Ledger(logs),
        habits: hs,
        comebackUntil: comeback);

void main() {
  group('Day', () {
    test('closes at 3 AM', () {
      expect(Day.of(DateTime(2026, 10, 17, 2, 59)), Day(2026, 10, 16));
      expect(Day.of(DateTime(2026, 10, 17, 3)), Day(2026, 10, 17));
    });
    test('round-trips its key and knows the weekday', () {
      final d = Day.parse('2026-10-16');
      expect(d.key, '2026-10-16');
      expect(d.weekday, DateTime.friday);
      expect(d.weekStart, Day(2026, 10, 12));
      expect(Day(2026, 12, 31).add(1), Day(2027, 1, 1));
    });
  });

  group('Calendar', () {
    test('finds the month and day of month', () {
      final today = Day(2026, 10, 16);
      expect(_cal.indexOf(today), 2);
      expect(_cal.dayInCycle(today), 29);
      expect(_cal.indexOf(Day(2026, 10, 18)), 3);
      expect(_cal.indexOf(Day(2026, 8, 1)), 0);
    });
  });

  group('Schedule', () {
    test('build habits are owed on their days only', () {
      final h = _habit(days: {2, 5});
      final s = _sched([h], []);
      expect(s.isDue(h, Day(2026, 10, 16)), isTrue); // Friday
      expect(s.isDue(h, Day(2026, 10, 15)), isFalse); // Thursday
    });

    test('habits wait for their start month and stop after the end month', () {
      final h = _habit(startCycle: 3, endCycle: 3);
      final s = _sched([h], []);
      expect(s.isDue(h, Day(2026, 10, 17)), isFalse);
      expect(s.isDue(h, Day(2026, 10, 18)), isTrue);
      expect(s.isDue(h, Day(2026, 11, 17)), isFalse);
    });

    test('maintain habits are only owed when the week runs out', () {
      // 2 a week, week of Mon 12 Oct.
      final h = _habit(mode: HabitMode.maintain, perWeek: 2);
      final mon = Day(2026, 10, 12);
      var s = _sched([h], []);
      expect(s.isDue(h, mon), isFalse);
      expect(s.isDue(h, mon.add(5)), isTrue); // Saturday: need 2, 2 days left
      s = _sched([h], [_log('h', mon, LogStatus.done)]);
      expect(s.isDue(h, mon), isTrue); // done days count as owed
      expect(s.isDue(h, mon.add(5)), isFalse); // need 1, 2 days left
      expect(s.isDue(h, mon.add(6)), isTrue);
    });

    test('editing frequency keeps earlier days on the old rule', () {
      final h = _habit().withRule(HabitRule(
          from: Day(2026, 10, 18),
          mode: HabitMode.maintain,
          perWeek: 2));
      expect(h.rules.length, 2);
      expect(h.ruleOn(Day(2026, 10, 17)).mode, HabitMode.build);
      expect(h.ruleOn(Day(2026, 10, 20)).mode, HabitMode.maintain);
    });

    test('comeback week keeps only core habits', () {
      final core = _habit(id: 'c', core: true);
      final other = _habit(id: 'o');
      final s = _sched([core, other], [], comeback: Day(2026, 10, 22));
      expect(s.dueOn(Day(2026, 10, 16)).map((h) => h.id), ['c']);
      expect(s.dueOn(Day(2026, 10, 23)).length, 2);
    });
  });

  group('Streaks', () {
    final eng = const StreakEngine();
    final start = Day(2026, 10, 1);
    final now = DateTime(2026, 10, 20, 12);
    final today = Day(2026, 10, 20);

    StreakState run(String pattern) {
      final h = _habit(from: start);
      final logs = <LogEntry>[];
      for (var i = 0; i < pattern.length; i++) {
        final c = pattern[i];
        if (c == '.') continue;
        logs.add(_log('h', start.add(i),
            c == 'P' ? LogStatus.done : c == 't' ? LogStatus.tiny : LogStatus.missed));
      }
      return eng.run(_sched([h], logs), start, today, now);
    }

    test('counts kept days', () {
      expect(run('PPPPPPPPPPPPPPPPPPPP').current, 20);
    });

    test('tiny keeps the streak', () {
      expect(run('PPPtPPPPPPPPPPPPPPPP').current, 20);
    });

    test('one missed day is shielded when the next is kept', () {
      final s = run('PPPPMPPPPPPPPPPPPPPP');
      expect(s.current, 19);
      expect(s.outcomes[start.add(4)], DayOutcome.shielded);
    });

    test('missing twice breaks it', () {
      expect(run('PPPPMMPPPPPPPPPPPPPP').current, 14);
    });

    test('only one shield a week', () {
      expect(run('PPPPMPPMPPPPPPPPPPPP').current, 12);
    });

    test('a miss yesterday puts today at risk', () {
      final s = run('PPPPPPPPPPPPPPPPPPM');
      expect(s.atRisk, isTrue);
      expect(s.current, 18);
    });

    test('unlogged days inside 48 h stay open', () {
      final s = run('PPPPPPPPPPPPPPPPPP');
      expect(s.outcomes[today.add(-1)], DayOutcome.open);
      expect(s.current, 18);
    });

    test('counts days away', () {
      expect(run('PPPPPPPPPPPPPP').daysAway, 5); // 15–19 Oct
    });
  });

  group('Scoring', () {
    test('a full day is worth 100 XP split across habits', () {
      final a = _habit(id: 'a'), b = _habit(id: 'b');
      final d = Day(2026, 10, 16);
      final s = _sched([a, b], [
        _log('a', d, LogStatus.done),
        _log('b', d, LogStatus.tiny),
      ]);
      expect(Xp.forDay(s, d), 75);
    });

    test('an honest miss earns a small bonus', () {
      final a = _habit(id: 'a');
      final d = Day(2026, 10, 16);
      final s = _sched([a], [_log('a', d, LogStatus.missed, remark: 'sick')]);
      expect(Xp.forDay(s, d), Xp.honestMiss);
    });

    test('level curve', () {
      expect(Level.of(0).level, 1);
      expect(Level.of(99).level, 1);
      expect(Level.of(100).level, 2);
      expect(Level.of(250).level, 3);
      expect(Level.of(260).into, 10);
      expect(Level.xpFor(3), 250);
    });

    test('titles', () {
      Map<Area, int> v(List<int> x) =>
          {for (var i = 0; i < 6; i++) Area.values[i]: x[i]};
      expect(Titles.of(v([0, 0, 0, 0, 0, 0])), Titles.starting);
      expect(Titles.of(v([10, 20, 80, 10, 0, 0])), 'The Scholar');
      expect(Titles.of(v([30, 30, 80, 10, 0, 0])), Titles.polymath);
      expect(Titles.of(v([60, 60, 80, 60, 70, 61])), Titles.complete);
      expect(
          Titles.of(v([60, 60, 80, 60, 0, 0]),
              resting: {Area.craft, Area.wealth}),
          Titles.complete);
    });

    test('strength rewards consistency and coverage', () {
      final today = Day(2026, 10, 16);
      final a = _habit(id: 'a', area: Area.physical, from: today.add(-40));
      final logs = [
        for (var i = 0; i < 28; i++) _log('a', today.add(-i), LogStatus.done)
      ];
      final v = Strengths.of(_sched([a], logs), today);
      expect(v[Area.physical], 100);
      expect(v[Area.mind], 0);
    });
  });

  group('Sheet import', () {
    test('matches the sheet totals', () {
      expect(SheetImport.sheetPercent(SheetImport.soorya, 1), closeTo(.767, .01));
      expect(SheetImport.sheetPercent(SheetImport.sanat, 1), closeTo(.933, .01));
      expect(SheetImport.logs(SheetImport.soorya).length, 58);
      expect(SheetImport.logs(SheetImport.sanat).length, 58);
      expect(SheetImport.dateOf(1, 1), Day(2026, 8, 17));
      expect(SheetImport.dateOf(1, 30), Day(2026, 9, 17));
      expect(SheetImport.dateOf(2, 29), Day(2026, 10, 16));
    });

    test('history gives a starting level, streaks and area scores', () {
      final o = SheetImport.soorya;
      final s = _sched(SheetImport.habits(o), SheetImport.allLogs(o));
      final today = Day(2026, 10, 16);
      final xp = Xp.total(s, SheetImport.cycles.first.start, today);
      expect(xp, 3380); // 33 practised days, then 4 of 5 habits on 16 Oct
      final st = const StreakEngine()
          .run(s, SheetImport.cycles.first.start, today, DateTime(2026, 10, 16, 20));
      expect(st.daysAway, 0); // logged on 16 Oct
      expect(st.current, greaterThan(0));
      expect(st.best, greaterThanOrEqualTo(10));
      // Seen from the last sheet day, recent practice shows in the areas.
      final v = Strengths.of(s, SheetImport.dateOf(2, 13));
      expect(v[Area.intellect], greaterThan(0));
      expect(v[Area.social], greaterThan(0));
    });

    test('remarks credit the habits they name', () {
      final c = SheetImport.creditsFor;
      expect(c(SheetImport.soorya, 1, 18, 'P', 'chess and debate, no ai'), {'s6': LogStatus.done, 's3': LogStatus.done});
      expect(c(SheetImport.soorya, 1, 5, 'P', '2hrs of course completed, started daily journaling again'),
          {'s1': LogStatus.done, 's4': LogStatus.done});
      expect(c(SheetImport.soorya, 1, 21, 'M', 'got late and skipped comm vedio'), {'s3': LogStatus.missed});
      expect(c(SheetImport.sanat, 1, 21, 'P', 'missed gym, did chess and comm'),
          {'n1': LogStatus.missed, 'n3': LogStatus.done, 'n4': LogStatus.done});
      expect(c(SheetImport.sanat, 1, 10, 'M', 'failed miserably, was rest day but ordered junk'), {'n2': LogStatus.missed});
      expect(c(SheetImport.sanat, 1, 4, 'P', "pull day. tatakae, maintained a strict diet. went for team dinner, Didn't junk"),
          {'n1': LogStatus.done, 'n2': LogStatus.done});
      // No habit named: the month's focus.
      expect(c(SheetImport.sanat, 2, 10, 'M', 'Poondi'), {'n3': LogStatus.missed, 'n4': LogStatus.missed});
    });
  });
}
