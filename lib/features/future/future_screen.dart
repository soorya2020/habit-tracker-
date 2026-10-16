import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../state/person_view.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import '../insights/character_card.dart';

final _allIn = NotifierProvider<_Toggle, bool>(_Toggle.new);

class _Toggle extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// Where you'll be at the end of the programme: at your pace, or all in.
class FutureScreen extends ConsumerWidget {
  const FutureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final allIn = ref.watch(_allIn);
    final t = context.tk;
    final p = me.projection;
    final last = me.calendar.cycles.isEmpty ? null : me.calendar.cycles.last;
    final end = last == null ? me.today.add(180) : me.calendar.endOf(last);
    final days = math.max(0, end.diff(me.today));
    final pace = allIn ? Xp.perDay.toDouble() : p.xpPerDay;
    final xpThen = me.xp + (pace * days).round();
    final lvThen = Level.of(xpThen);
    final v = allIn ? _allInStrengths(me) : me.strengths;
    final titleThen = Titles.of(v, resting: me.profile.resting);
    final fmt = DateFormat('d MMM yyyy');

    String when(int level) {
      if (pace <= 0) return 'not at this pace';
      final need = Level.xpFor(level) - me.xp;
      if (need <= 0) return 'reached';
      return fmt.format(me.today.add((need / pace).ceil()).date);
    }

    final milestones = <(String, String)>[
      ('Level ${me.level.level + 1}', when(me.level.level + 1)),
      ('Level ${(me.level.level ~/ 5 + 1) * 5}', when((me.level.level ~/ 5 + 1) * 5)),
      if (last != null) ('End of Month ${last.index}', 'Level ${lvThen.level} · $titleThen'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Future')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text('At your pace · ${p.xpPerDay.round()} XP/day')),
              const ButtonSegment(value: true, label: Text('All in · 100 XP/day')),
            ],
            selected: {allIn},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ref.read(_allIn.notifier).set(s.first),
          ),
          const SizedBox(height: 12),
          _Projected(me: me, v: v, level: lvThen, title: titleThen, end: fmt.format(end.date)),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Milestones'),
              const SizedBox(height: 6),
              for (final (a, b) in milestones)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(a, style: context.tx.titleMedium)),
                    Text(b, style: mono(12, t.muted)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Text(
            allIn
                ? 'All in means every owed habit done every day from today.'
                : 'Your pace is the average of the last ${14} days. Log more and this moves.',
            style: context.tx.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Strength each area reaches if every planned habit is done.
  static Map<Area, int> _allInStrengths(PersonView me) {
    final perWeek = {for (final a in Area.values) a: 0.0};
    for (final h in me.activeHabits) {
      perWeek[h.area] = perWeek[h.area]! + h.current.weeklyLoad;
    }
    return {
      for (final a in Area.values)
        a: math.max(me.strengths[a]!, (100 * math.min(1, perWeek[a]! / Strengths.targetPerWeek)).round()),
    };
  }
}

class _Projected extends StatelessWidget {
  const _Projected({required this.me, required this.v, required this.level, required this.title, required this.end});
  final PersonView me;
  final Map<Area, int> v;
  final Level level;
  final String title;
  final String end;

  @override
  Widget build(BuildContext context) => CharacterCard(
        me: me,
        strengths: v,
        caption: 'By $end: level ${level.level}, $title.',
      );
}
