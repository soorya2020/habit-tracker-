import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/core/day.dart';
import 'package:one_percent_club/domain/models.dart';
import 'package:one_percent_club/domain/motivation.dart';
import 'package:one_percent_club/domain/scoring.dart';

Map<Area, int> _v(int p, int m, int i, int s, int c, int w) => {
      Area.physical: p, Area.mind: m, Area.intellect: i, Area.social: s, Area.craft: c, Area.wealth: w,
    };

void main() {
  test('next streak milestone', () {
    expect(Milestones.next(0), 3);
    expect(Milestones.next(3), 7);
    expect(Milestones.next(29), 30);
    expect(Milestones.next(365), 400);
  });

  test('next title is the Polymath, then the Complete Man', () {
    final g = TitleGoal.of(_v(0, 6, 30, 15, 0, 0))!;
    expect(g.title, Titles.polymath);
    expect(g.areas, [Area.intellect, Area.social, Area.mind]);
    expect(g.reached(_v(0, 6, 30, 15, 0, 0)), 1);
    expect(TitleGoal.of(_v(40, 40, 40, 10, 0, 0))!.title, Titles.complete);
    expect(TitleGoal.of(_v(70, 70, 70, 70, 70, 70)), isNull);
  });

  test('a daily line for every day', () {
    expect(DailyLine.of(Day(2026, 10, 17)), isNotEmpty);
    expect(DailyLine.of(Day(2026, 10, 17)), isNot(DailyLine.of(Day(2026, 10, 18))));
  });
}
