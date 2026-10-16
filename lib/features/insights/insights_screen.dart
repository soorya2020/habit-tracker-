import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/streaks.dart';
import '../../state/person_view.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import 'character_card.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final partner = ref.watch(partnerProvider);
    final t = context.tk;

    Widget stat(String value, String label) => Expanded(
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: display(22, t.ink)),
              const SizedBox(height: 2),
              Text(label, style: context.tx.bodySmall),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          CharacterCard(me: me),
          const SizedBox(height: 12),
          Row(children: [
            stat('${me.streak.current}', 'day streak'),
            const SizedBox(width: 8),
            stat('${me.streak.best}', 'best streak'),
            const SizedBox(width: 8),
            stat('${(me.balance * 100).round()}%', 'balance'),
          ]),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Eyebrow('Last 70 days')),
                Text('${me.xp} XP total', style: mono(11, t.muted)),
              ]),
              const SizedBox(height: 10),
              _Heatmap(me: me),
              const SizedBox(height: 8),
              Row(children: [
                _key(t.ok, 'kept'),
                _key(t.ok.withValues(alpha: .45), 'shielded'),
                _key(t.miss.withValues(alpha: .7), 'missed'),
                _key(t.heat0, 'rest / not logged'),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(partner == null ? 'By month' : 'You vs ${partner.profile.name}'),
              const SizedBox(height: 10),
              for (final c in me.calendar.cycles.where((c) => c.index <= me.cycleIndex)) ...[
                _MonthBar(label: 'M${c.index} you', value: me.cyclePercent(c), color: t.accent),
                if (partner != null)
                  _MonthBar(label: 'M${c.index} ${partner.profile.name}', value: partner.cyclePercent(c), color: t.muted),
                const SizedBox(height: 6),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _key(Color c, String s) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(s, style: const TextStyle(fontSize: 11)),
        ]),
      );
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.me});
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    const weeks = 10;
    final end = me.today;
    final start = end.weekStart.add(-7 * (weeks - 1));
    Color colorOf(DayOutcome? o) => switch (o) {
          DayOutcome.kept => t.ok,
          DayOutcome.shielded => t.ok.withValues(alpha: .45),
          DayOutcome.missed => t.miss.withValues(alpha: .7),
          DayOutcome.open => t.accentSoft,
          _ => t.heat0,
        };
    return LayoutBuilder(builder: (context, c) {
      final cell = (c.maxWidth - (weeks - 1) * 4) / weeks;
      final size = cell.clamp(8.0, 22.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var w = 0; w < weeks; w++)
            Column(children: [
              for (var d = 0; d < 7; d++) ...[
                Builder(builder: (_) {
                  final day = start.add(w * 7 + d);
                  final future = day.isAfter(end);
                  return Container(
                    width: size,
                    height: size,
                    margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      color: future ? Colors.transparent : colorOf(me.streak.outcomes[day]),
                      borderRadius: BorderRadius.circular(3),
                      border: day == end ? Border.all(color: t.ink, width: 1.5) : null,
                    ),
                  );
                }),
              ],
            ]),
        ],
      );
    });
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(child: Bar(value: value, color: color)),
          SizedBox(width: 44, child: Text('${(value * 100).round()}%', textAlign: TextAlign.right, style: mono(12, context.tk.ink))),
        ]),
      );
}
