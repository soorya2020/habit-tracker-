import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/core/day.dart';
import 'package:one_percent_club/domain/models.dart';
import 'package:one_percent_club/domain/schedule.dart';
import 'package:one_percent_club/domain/three_rule.dart';

Habit h(String id, int start, {int? end}) => Habit(
      id: id,
      owner: 'me',
      name: id,
      area: Area.mind,
      startCycle: start,
      endCycle: end,
      rules: [HabitRule(from: Day(2026, 10, 24))],
    );

void main() {
  test('a fourth habit in a month overflows', () {
    final xs = [h('a', 3), h('b', 3), h('c', 3)];
    expect(ThreeRule.overflow(xs, h('d', 3)), 3);
    expect(ThreeRule.overflow(xs, h('d', 5)), 5);
  });

  test('a free slot or an ended habit makes room', () {
    expect(ThreeRule.overflow([h('a', 3), h('b', 3)], h('d', 3)), isNull);
    expect(ThreeRule.overflow([h('a', 3), h('b', 3), h('c', 3, end: 4)], h('d', 5)), isNull);
  });

  test('editing a habit in an over-full month still saves', () {
    final xs = [h('a', 3), h('b', 3), h('c', 3), h('d', 3)];
    expect(ThreeRule.overflow(xs, xs.last.copyWith(name: 'D')), isNull);
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
    expect(cal.next.start, Day(2026, 11, 1));
    expect(cal.indexOf(Day(2026, 10, 31)), 1);
    expect(cal.indexOf(Day(2026, 11, 30)), 2);
    expect(cal.indexOf(Day(2027, 1, 1)), 4);
    final two = Calendar([...cal.cycles, cal.next]);
    expect(two.endOf(two.cycles.last), Day(2026, 11, 30));
  });
}
