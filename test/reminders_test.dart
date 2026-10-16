import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/core/day.dart';
import 'package:one_percent_club/data/seed.dart';
import 'package:one_percent_club/domain/models.dart';
import 'package:one_percent_club/domain/reminders.dart';
import 'package:one_percent_club/domain/schedule.dart';

Habit _h(String id, int reminder) => Habit(
      id: id,
      owner: 'u',
      name: id,
      area: Area.mind,
      startCycle: 1,
      rules: [HabitRule(from: Day(2026, 8, 17), reminder: reminder)],
    );

void main() {
  final today = Day(2026, 10, 16);
  final cal = Calendar(SheetImport.cycles);
  const p = Profile(uid: 'u', name: 'U');

  List<Notice> plan(List<Habit> hs, {List<LogEntry> logs = const [], DateTime? now, Profile profile = p}) =>
      const ReminderPlanner(days: 1).plan(
          Schedule(calendar: cal, ledger: Ledger(logs), habits: hs),
          profile,
          today,
          now ?? DateTime(2026, 10, 16, 6));

  test('one reminder per habit plus two evening nudges', () {
    final n = plan([_h('a', 8 * 60)]);
    expect(n.where((x) => !x.nudge).single.habitIds, ['a']);
    expect(n.where((x) => x.nudge).length, 2);
  });

  test('never more than 4 a day; extra reminders merge', () {
    final n = plan([for (var i = 0; i < 6; i++) _h('h$i', (8 + i * 2) * 60)]);
    expect(n.length, 4);
    final merged = n.where((x) => !x.nudge).toList();
    expect(merged.length, 2);
    expect(merged.map((x) => x.title), ['4 habits now', '2 habits now']);
  });

  test('skips logged habits, quiet hours and the past', () {
    final logs = [
      LogEntry(habitId: 'a', owner: 'u', day: today, status: LogStatus.done, updatedAt: DateTime(2026)),
    ];
    final n = plan([_h('a', 8 * 60), _h('b', 23 * 60 + 45), _h('c', 5 * 60)], logs: logs);
    expect(n.where((x) => !x.nudge), isEmpty);
  });

  test('nothing when the day is closed or reminders are off', () {
    final logs = [
      LogEntry(habitId: 'a', owner: 'u', day: today, status: LogStatus.done, updatedAt: DateTime(2026)),
    ];
    expect(plan([_h('a', 8 * 60)], logs: logs), isEmpty);
    expect(plan([_h('a', 8 * 60)], profile: p.copyWith(remindersOn: false)), isEmpty);
  });
}
