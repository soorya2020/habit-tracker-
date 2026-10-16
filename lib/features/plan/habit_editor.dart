import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../services/reminder_sync.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';

/// Create a habit, or edit one. Schedule changes take effect from today,
/// so past days and streaks keep the old schedule.
Future<void> showHabitEditor(BuildContext context, {Habit? habit, int cycle = 1}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HabitEditor(habit: habit, cycle: cycle),
    );

class HabitEditor extends ConsumerStatefulWidget {
  const HabitEditor({super.key, this.habit, this.cycle = 1});
  final Habit? habit;
  final int cycle;

  @override
  ConsumerState<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<HabitEditor> {
  final name = TextEditingController();
  final tiny = TextEditingController();
  final unit = TextEditingController();
  late Area area;
  late TrackKind kind;
  late HabitMode mode;
  late Set<int> days;
  late int perWeek;
  late double target;
  int? reminder;
  late int startCycle;
  int? endCycle;
  late int minutes;
  late bool core;

  bool get editing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    final r = h?.current;
    name.text = h?.name ?? '';
    tiny.text = h?.tiny ?? '';
    unit.text = h?.unit ?? 'min';
    area = h?.area ?? Area.intellect;
    kind = h?.kind ?? TrackKind.check;
    mode = r?.mode ?? HabitMode.build;
    days = {...(r?.days ?? {1, 2, 3, 4, 5})};
    perWeek = r?.perWeek ?? 3;
    target = r?.target ?? 20;
    reminder = h == null ? 20 * 60 : r?.reminder;
    startCycle = h?.startCycle ?? widget.cycle;
    endCycle = h?.endCycle;
    minutes = h?.minutes ?? 20;
    core = h?.core ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    tiny.dispose();
    unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final me = ref.read(meProvider);
    final actions = ref.read(actionsProvider);
    final cycleStart = me.calendar.byIndex(startCycle)?.start ?? me.today;
    final from = cycleStart.isAfter(me.today) ? cycleStart : me.today;
    final rule = HabitRule(
      from: from,
      mode: mode,
      days: days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : days,
      perWeek: perWeek,
      target: kind == TrackKind.amount ? target : 1,
      reminder: reminder,
    );
    final old = widget.habit;
    Habit h;
    if (old == null) {
      h = Habit(
        id: actions.newId(),
        owner: me.uid,
        name: name.text.trim(),
        area: area,
        kind: kind,
        unit: unit.text.trim(),
        tiny: tiny.text.trim(),
        minutes: minutes,
        core: core,
        startCycle: startCycle,
        endCycle: endCycle,
        rules: [rule],
      );
    } else {
      h = old.copyWith(
        name: name.text.trim(),
        area: area,
        kind: kind,
        unit: unit.text.trim(),
        tiny: tiny.text.trim(),
        minutes: minutes,
        core: core,
        startCycle: startCycle,
        endCycle: () => endCycle,
      );
      final notStarted = old.rules.first.from.isAfter(me.today);
      final c = old.current;
      final changed = c.mode != rule.mode ||
          c.perWeek != rule.perWeek ||
          c.target != rule.target ||
          c.reminder != rule.reminder ||
          c.days.length != rule.days.length ||
          !c.days.containsAll(rule.days);
      if (notStarted) {
        h = h.copyWith(rules: [rule]);
      } else if (changed) {
        h = h.withRule(rule);
      }
    }
    await actions.saveHabit(h);
    await ref.read(reminderSyncProvider).ensurePermission();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final me = ref.watch(meProvider);
    final cycles = me.calendar.cycles;
    final valid = name.text.trim().isNotEmpty && (mode == HabitMode.maintain || days.isNotEmpty);

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Eyebrow(s),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(editing ? 'Edit habit' : 'New habit', style: context.tx.headlineSmall),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Name, e.g. Read'),
            onChanged: (_) => setState(() {}),
          ),
          label('Area'),
          ChoiceChips<Area>(
            values: Area.values,
            selected: (a) => a == area,
            label: (a) => a.label,
            leading: (a) => AreaDot(a),
            onSelect: (a) => setState(() => area = a),
          ),
          label('Track'),
          ChoiceChips<TrackKind>(
            values: TrackKind.values,
            selected: (k) => k == kind,
            label: (k) => k == TrackKind.check ? 'Done / not done' : 'An amount',
            onSelect: (k) => setState(() => kind = k),
          ),
          if (kind == TrackKind.amount) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: fmtNumber(target),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target'),
                  onChanged: (v) => target = double.tryParse(v) ?? target,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit')),
              ),
            ]),
          ],
          label('Tiny version'),
          TextField(
            controller: tiny,
            decoration: const InputDecoration(hintText: 'What still counts on a bad day, e.g. 1 page'),
          ),
          label('How often'),
          SegmentedButton<HabitMode>(
            segments: const [
              ButtonSegment(value: HabitMode.build, label: Text('Build · set days')),
              ButtonSegment(value: HabitMode.maintain, label: Text('Maintain · N a week')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
          const SizedBox(height: 10),
          if (mode == HabitMode.build)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 1; d <= 7; d++)
                  _DayToggle(
                    label: weekdayLetters[d - 1],
                    semantic: weekdayShort[d - 1],
                    on: days.contains(d),
                    onTap: () => setState(() => days.contains(d) ? days.remove(d) : days.add(d)),
                  ),
              ],
            )
          else
            Row(children: [
              IconButton.outlined(
                onPressed: perWeek > 1 ? () => setState(() => perWeek--) : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Fewer',
              ),
              Expanded(child: Center(child: Text('$perWeek× a week, any days', style: context.tx.titleMedium))),
              IconButton.outlined(
                onPressed: perWeek < 7 ? () => setState(() => perWeek++) : null,
                icon: const Icon(Icons.add),
                tooltip: 'More',
              ),
            ]),
          if (editing && mode == HabitMode.maintain)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Maintain keeps the streak going at a lower pace. Only owed days count.',
                  style: context.tx.bodySmall),
            ),
          label('Months'),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: startCycle,
                decoration: const InputDecoration(labelText: 'Starts'),
                items: [for (final c in cycles) DropdownMenuItem(value: c.index, child: Text('Month ${c.index}'))],
                onChanged: (v) => setState(() {
                  startCycle = v!;
                  if (endCycle != null && endCycle! < startCycle) endCycle = startCycle;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: endCycle,
                decoration: const InputDecoration(labelText: 'Ends'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Keeps going')),
                  for (final c in cycles)
                    if (c.index >= startCycle) DropdownMenuItem(value: c.index, child: Text('After Month ${c.index}')),
                ],
                onChanged: (v) => setState(() => endCycle = v),
              ),
            ),
          ]),
          label('Time per session'),
          ChoiceChips<int>(
            values: const [5, 10, 20, 30, 60, 90],
            selected: (m) => m == minutes,
            label: (m) => '$m min',
            onSelect: (m) => setState(() => minutes = m),
          ),
          label('Reminder'),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.notifications_none, size: 18),
                label: Text(reminder == null ? 'No reminder' : fmtMinutes(reminder!)),
                onPressed: () async {
                  final r = reminder ?? 20 * 60;
                  final picked = await showTimePicker(
                      context: context, initialTime: TimeOfDay(hour: r ~/ 60, minute: r % 60));
                  if (picked != null) setState(() => reminder = picked.hour * 60 + picked.minute);
                },
              ),
            ),
            if (reminder != null) ...[
              const SizedBox(width: 8),
              IconButton(
                  tooltip: 'Remove reminder',
                  onPressed: () => setState(() => reminder = null),
                  icon: const Icon(Icons.close)),
            ],
          ]),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Core habit'),
            subtitle: const Text('Kept during a comeback week'),
            value: core,
            onChanged: (v) => setState(() => core = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: valid ? _save : null, child: Text(editing ? 'Save' : 'Add habit')),
          if (editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(actionsProvider).archive(widget.habit!);
                if (context.mounted) Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: t.miss),
              child: const Text('Archive (history is kept)'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.semantic, required this.on, required this.onTap});
  final String label, semantic;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label: semantic,
      selected: on,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? t.ink : Colors.transparent,
            border: Border.all(color: on ? t.ink : t.line),
          ),
          child: Text(label, style: TextStyle(color: on ? t.screen : t.ink, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

