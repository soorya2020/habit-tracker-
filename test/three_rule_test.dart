import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/core/day.dart';
import 'package:one_percent_club/domain/models.dart';
import 'package:one_percent_club/domain/schedule.dart';
import 'package:one_percent_club/domain/three_rule.dart';

Habit h(String id, int start, {int? end, Set<int> days = const {1, 2, 3, 4, 5, 6, 7}, HabitMode mode = HabitMode.build, int perWeek = 3}) => Habit(
      id: id,
      owner: 'me',
      name: id,
      area: Area.mind,
      startCycle: start,
      endCycle: end,
      rules: [HabitRule(from: Day(2026, 10, 24), days: days, mode: mode, perWeek: perWeek)],
    );

void main() {
  test('a month can hold many habits, but a day only three', () {
    final xs = [h('a', 1, days: {1, 2}), h('b', 1, days: {1, 3}), h('c', 1, days: {1, 4}), h('d', 1, days: {2, 3})];
    expect(ThreeRule.problem(xs, h('e', 1, days: {5, 6, 7})), isNull);
    expect(ThreeRule.problem(xs, h('e', 1, days: {1})), contains('Monday'));
    expect(ThreeRule.fullDays(xs, [1]), {1});
  });

  test('a later month counts habits that carry over', () {
    final xs = [h('a', 1), h('b', 1), h('c', 2, end: 2)];
    expect(ThreeRule.problem(xs, h('d', 2, days: {1})), contains('Month 2'));
    expect(ThreeRule.problem(xs, h('d', 3, days: {1})), isNull);
  });

  test('maintain habits need free slots in the week', () {
    final xs = [h('a', 1), h('b', 1)];
    expect(ThreeRule.problem(xs, h('m', 1, mode: HabitMode.maintain, perWeek: 7)), isNull);
    expect(ThreeRule.problem([...xs, h('c', 1, days: {1, 2})], h('m', 1, mode: HabitMode.maintain, perWeek: 7)),
        contains('free slots'));
  });

  test('editing a habit on an over-full day still saves', () {
    final xs = [h('a', 1), h('b', 1), h('c', 1), h('d', 1)];
    expect(ThreeRule.problem(xs, xs.last.copyWith(name: 'D')), isNull);
  });

  test('the month locks after day 3', () {
    expect(ThreeRule.locked(4, 4, 3), isFalse);
    expect(ThreeRule.locked(4, 4, 4), isTrue);
    expect(ThreeRule.locked(5, 4, 20), isFalse);
    expect(ThreeRule.locked(3, 4, 1), isTrue);
  });

  test('dropping ends an old habit and archives a new one', () {
    final today = Day(2026, 11, 18);
    expect(ThreeRule.dropFrom(h('a', 3), 5, today).endCycle, 4);
    expect(ThreeRule.dropFrom(h('a', 5), 5, today).archived, isTrue);
  });

  test('months end on the last day of their calendar month', () {
    final cal = Calendar([Cycle(index: 1, start: Day(2026, 10, 24))]);
    expect(cal.endOf(cal.cycles.first), Day(2026, 10, 31));
    expect(cal.nextFrom(Day(2026, 10, 24)).start, Day(2026, 11, 1));
    expect(cal.nextFrom(Day(2026, 12, 5)).start, Day(2026, 12, 5));
    expect(cal.indexOf(Day(2026, 10, 31)), 1);
    expect(cal.indexOf(Day(2026, 11, 30)), 2);
    expect(cal.indexOf(Day(2027, 1, 1)), 4);
    final two = Calendar([...cal.cycles, cal.nextFrom(Day(2026, 10, 24))]);
    expect(two.endOf(two.cycles.last), Day(2026, 11, 30));
  });
}
