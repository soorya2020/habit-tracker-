import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/load.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../state/person_view.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import 'habit_editor.dart';

final _selectedCycle = NotifierProvider<_Sel, int?>(_Sel.new);

class _Sel extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int i) => state = i;
}

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final strip = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = ref.read(meProvider).cycleIndex;
      if (strip.hasClients && now > 1) {
        strip.jumpTo(((now - 1) * 116.0).clamp(0, strip.position.maxScrollExtent));
      }
    });
  }

  @override
  void dispose() {
    strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final now = me.cycleIndex < 1 ? 1 : me.cycleIndex;
    final sel = ref.watch(_selectedCycle) ?? now;
    final cycle = me.calendar.byIndex(sel);
    final t = context.tk;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SizedBox(
            height: 64,
            child: ListView.separated(
              controller: strip,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: me.calendar.cycles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = me.calendar.cycles[i];
                final on = c.index == sel;
                final sub = c.index < me.cycleIndex
                    ? '${(me.cyclePercent(c) * 100).round()}% kept'
                    : c.index == me.cycleIndex
                        ? 'Now'
                        : DateFormat('d MMM').format(c.start.date);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => ref.read(_selectedCycle.notifier).set(c.index),
                  child: Container(
                    width: 108,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: on ? t.ink : t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? t.ink : t.line),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Month ${c.index}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: on ? t.screen : t.ink)),
                      Text(sub,
                          style: mono(11, on ? t.screen.withValues(alpha: .7) : c.index == me.cycleIndex ? t.accent : t.muted)),
                    ]),
                  ),
                );
              },
            ),
          ),
          if (cycle != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MonthBody(me: me, cycle: cycle),
            ),
        ],
      ),
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.me, required this.cycle});
  final PersonView me;
  final Cycle cycle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final i = cycle.index;
    final past = i < me.cycleIndex, current = i == me.cycleIndex;
    final len = me.calendar.lengthOf(cycle);
    final tag = past
        ? 'Done'
        : current
            ? 'Now · day ${me.dayInCycle} of $len'
            : 'Starts ${DateFormat('d MMM').format(cycle.start.date)}';
    final habits = me.activeHabits
        .where((h) => h.startCycle <= i && (h.endCycle == null || h.endCycle! >= i))
        .toList()
      ..sort((a, b) => a.startCycle.compareTo(b.startCycle));
    final load = me.loadOf(cycle);
    final review = me.reviewOf(i);
    final canReview = (past || (current && me.dayInCycle >= len - 5)) && review == null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Eyebrow('Month $i · $tag')),
            TextButton(onPressed: () => _editMonth(context, ref, cycle), child: const Text('Edit')),
          ]),
          Text(cycle.focus.isEmpty ? 'No focus set yet' : cycle.focus, style: context.tx.titleLarge),
          if (cycle.doneMeans.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Done means: ${cycle.doneMeans}', style: context.tx.bodyMedium?.copyWith(color: t.muted)),
          ],
          if (review != null) ...[
            const SizedBox(height: 10),
            Text('Reviewed: ${switch (review.verdict) { ReviewVerdict.yes => 'achieved', ReviewVerdict.partly => 'partly achieved', ReviewVerdict.no => 'not this time' }}'
                '${review.note.isEmpty ? '' : ' · ${review.note}'}',
                style: context.tx.bodySmall?.copyWith(color: t.ok)),
          ],
        ]),
      ),
      if (canReview) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _review(context, ref, cycle),
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: Text('Review Month $i · +${Xp.perReview} XP'),
        ),
      ],
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Eyebrow('Daily load')),
            Text('${load.habitsPerDay.toStringAsFixed(1)} habits · ${load.minutesPerDay} min',
                style: mono(12, load.heavy ? t.warn : t.ink)),
          ]),
          const SizedBox(height: 8),
          Bar(value: load.fill, color: load.heavy ? t.warn : t.ok),
          if (load.heavy) ...[
            const SizedBox(height: 8),
            Text(
              'Heavier than ${Load.maxHabitsPerDay} habits or ${Load.maxMinutesPerDay} min a day. '
              'Switch an older habit to Maintain (fewer times a week) to keep its streak without the load.',
              style: context.tx.bodySmall?.copyWith(color: t.warn),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      Eyebrow('Habits in Month $i · ${habits.length}'),
      const SizedBox(height: 8),
      for (final h in habits) ...[
        _PlanRow(habit: h, cycle: i, me: me),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => showHabitEditor(context, cycle: i),
        icon: const Icon(Icons.add, size: 18),
        label: Text('Add a habit from Month $i'),
      ),
      const SizedBox(height: 8),
      Text('New habits carry over to later months until you set an end.', textAlign: TextAlign.center, style: context.tx.bodySmall),
    ]);
  }

  Future<void> _editMonth(BuildContext context, WidgetRef ref, Cycle c) async {
    final focus = TextEditingController(text: c.focus);
    final done = TextEditingController(text: c.doneMeans);
    await showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Month ${c.index} goals', style: ctx.tx.headlineSmall),
          const SizedBox(height: 14),
          TextField(controller: focus, decoration: const InputDecoration(labelText: 'Focus')),
          const SizedBox(height: 10),
          TextField(controller: done, maxLines: 3, minLines: 2, decoration: const InputDecoration(labelText: 'Done means')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(actionsProvider).saveCycle(c.copyWith(focus: focus.text.trim(), doneMeans: done.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
    focus.dispose();
    done.dispose();
  }

  Future<void> _review(BuildContext context, WidgetRef ref, Cycle c) async {
    var verdict = ReviewVerdict.partly;
    final note = TextEditingController();
    await showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Review Month ${c.index}', style: ctx.tx.headlineSmall),
            const SizedBox(height: 6),
            Text(c.doneMeans.isEmpty ? 'Did the month go the way you wanted?' : 'Did you get there? ${c.doneMeans}',
                style: ctx.tx.bodyMedium?.copyWith(color: ctx.tk.muted)),
            const SizedBox(height: 14),
            SegmentedButton<ReviewVerdict>(
              segments: const [
                ButtonSegment(value: ReviewVerdict.yes, label: Text('Yes')),
                ButtonSegment(value: ReviewVerdict.partly, label: Text('Partly')),
                ButtonSegment(value: ReviewVerdict.no, label: Text('No')),
              ],
              selected: {verdict},
              showSelectedIcon: false,
              onSelectionChanged: (s) => set(() => verdict = s.first),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(hintText: 'One thing to change next month')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(actionsProvider).review(c.index, verdict, note.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Month ${c.index} reviewed · +${Xp.perReview} XP')));
              },
              child: const Text('Save review'),
            ),
          ]),
        ),
      ),
    );
    note.dispose();
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.habit, required this.cycle, required this.me});
  final Habit habit;
  final int cycle;
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final r = habit.current;
    final tags = <String>[
      if (habit.startCycle == cycle) 'New',
      if (r.mode == HabitMode.maintain) 'Maintain',
      if (habit.core) 'Core',
      if (habit.endCycle != null) 'Ends M${habit.endCycle}',
    ];
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => showHabitEditor(context, habit: habit, cycle: cycle),
      child: Row(children: [
        AreaDot(habit.area),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habit.name, style: context.tx.titleMedium),
            const SizedBox(height: 2),
            Text(
              [
                scheduleText(r),
                if (habit.kind == TrackKind.amount) '${fmtNumber(r.target)} ${habit.unit}',
                if (r.reminder != null) fmtMinutes(r.reminder!),
              ].join(' · '),
              style: context.tx.bodySmall,
            ),
          ]),
        ),
        for (final tag in tags)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tag == 'New' ? t.accentSoft : t.heat0,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag, style: mono(10, tag == 'New' ? t.accent : t.muted)),
          ),
      ]),
    );
  }
}
