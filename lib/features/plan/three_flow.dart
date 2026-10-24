import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/three_rule.dart';
import '../../state/person_view.dart';
import '../../state/providers.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import 'habit_editor.dart';
import 'plan_screen.dart';

/// Adds a habit to [month]. The editor keeps each day to three habits.
Future<void> addHabitTo(BuildContext context, WidgetRef ref, int month) async {
  var me = ref.read(meProvider);
  if (me.calendar.cycles.isEmpty) {
    // Habits run inside months, so the first habit starts the first month.
    final c = await ref.read(actionsProvider).addMonth();
    if (!context.mounted) return;
    await editMonth(context, ref, c);
    if (!context.mounted) return;
    me = ref.read(meProvider);
    month = c.index;
  }
  if (ThreeRule.perWeek(me.habits, month) >= 7 * ThreeRule.max) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Every day in Month $month already has ${ThreeRule.max} habits. Free up a day first.')));
    return;
  }
  await showHabitEditor(context, cycle: month);
}

/// Whether to ask which habits carry into the current month.
bool needsMonthPick(PersonView me, bool asked) {
  final i = me.cycleIndex;
  if (asked || i < 2 || ThreeRule.locked(i, i, me.dayInCycle)) return false;
  return ThreeRule.inMonth(me.habits, i).any((h) => h.startCycle < i);
}

String monthPickKey(PersonView me) => 'three.picked.${me.uid}.${me.cycleIndex}';

/// New month: keep the habits that carry over, or pause some.
Future<void> pickMonthThree(BuildContext context, WidgetRef ref) async {
  final me = ref.read(meProvider);
  final i = me.cycleIndex;
  final carried = ThreeRule.inMonth(me.habits, i).where((h) => h.startCycle < i).toList();
  final keep = await _pick(
    context,
    title: 'Your habits for Month $i',
    body: 'Untick a habit to pause it from this month. You can change this until day ${ThreeRule.graceDays}, '
        'then your habits are locked until the month ends.',
    habits: carried,
    many: true,
  );
  if (keep == null) return;
  final actions = ref.read(actionsProvider);
  for (final h in carried) {
    if (!keep.contains(h)) await actions.saveHabit(ThreeRule.dropFrom(h, i, me.today));
  }
  await ref.read(prefsProvider).setBool(monthPickKey(me), true);
  Haptics.success();
}

/// A list of habits to choose from: one for a swap, several to keep.
Future<List<Habit>?> _pick(
  BuildContext context, {
  required String title,
  required String body,
  required List<Habit> habits,
  required bool many,
}) {
  final chosen = <Habit>{if (many) ...habits};
  return showModalBottomSheet<List<Habit>>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final t = ctx.tk;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: ctx.tx.headlineSmall),
            const SizedBox(height: 6),
            Text(body, style: ctx.tx.bodyMedium?.copyWith(color: t.muted)),
            const SizedBox(height: 14),
            for (final h in habits) ...[
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () {
                  if (!many) return Navigator.pop(ctx, [h]);
                  set(() => chosen.contains(h) ? chosen.remove(h) : chosen.add(h));
                },
                child: Row(children: [
                  AreaDot(h.area),
                  const SizedBox(width: 12),
                  Expanded(child: Text(h.name, style: ctx.tx.titleMedium)),
                  if (many)
                    Icon(chosen.contains(h) ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: chosen.contains(h) ? t.ok : t.muted)
                  else
                    Text('Swap out', style: mono(12, t.miss)),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (many) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, chosen.toList()),
                child: Text(chosen.length == habits.length ? 'Keep all ${habits.length}' : 'Keep ${chosen.length}, pause ${habits.length - chosen.length}'),
              ),
            ],
          ]),
        );
      },
    ),
  );
}
