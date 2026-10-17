import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import 'quick_log.dart';
import '../../ui/haptics.dart';

/// Done / Tiny / Missed with an amount and a remark.
Future<void> showLogSheet(BuildContext context, Habit h, Day day) =>
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => _LogSheet(habit: h, day: day),
    );

class _LogSheet extends ConsumerStatefulWidget {
  const _LogSheet({required this.habit, required this.day});
  final Habit habit;
  final Day day;

  @override
  ConsumerState<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends ConsumerState<_LogSheet> {
  LogStatus? status;
  double value = 0;
  final remark = TextEditingController();

  @override
  void initState() {
    super.initState();
    final me = ref.read(meProvider);
    final log = me.logOn(widget.habit, widget.day);
    status = log?.status ?? LogStatus.done;
    value = log?.value ?? widget.habit.ruleOn(widget.day).target;
    remark.text = log?.remark ?? '';
  }

  @override
  void dispose() {
    remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final h = widget.habit;
    final me = ref.watch(meProvider);
    final rule = h.ruleOn(widget.day);
    final isToday = widget.day == me.today;
    final xp = Xp.shareOf(me.schedule, h, widget.day, status ?? LogStatus.done);
    final step = rule.target >= 20 ? 5.0 : 1.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            AreaDot(h.area),
            const SizedBox(width: 8),
            Eyebrow('${h.area.label} · ${isToday ? 'today' : 'yesterday'}'),
          ]),
          const SizedBox(height: 6),
          Text(h.name, style: context.tx.headlineSmall),
          const SizedBox(height: 16),
          SegmentedButton<LogStatus>(
            segments: [
              const ButtonSegment(value: LogStatus.done, label: Text('Done')),
              ButtonSegment(value: LogStatus.tiny, label: Text(h.tiny.isEmpty ? 'Tiny' : 'Tiny · ${h.tiny}', overflow: TextOverflow.ellipsis)),
              const ButtonSegment(value: LogStatus.missed, label: Text('Missed')),
            ],
            selected: {status!},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              Haptics.select();
              setState(() => status = s.first);
            },
          ),
          if (h.kind == TrackKind.amount && status == LogStatus.done) ...[
            const SizedBox(height: 16),
            Row(children: [
              IconButton.outlined(
                onPressed: value <= 0 ? null : () {
                  Haptics.select();
                  setState(() => value = (value - step).clamp(0, 9999));
                },
                icon: const Icon(Icons.remove),
                tooltip: 'Less',
              ),
              Expanded(
                child: Column(children: [
                  Text(fmtNumber(value), style: display(30, t.ink)),
                  Text('of ${fmtNumber(rule.target)} ${h.unit}', style: context.tx.bodySmall),
                ]),
              ),
              IconButton.outlined(
                onPressed: () {
                  Haptics.select();
                  setState(() => value += step);
                },
                icon: const Icon(Icons.add),
                tooltip: 'More',
              ),
            ]),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: remark,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: status == LogStatus.missed
                  ? 'What got in the way? (honest misses earn +${Xp.honestMiss} XP)'
                  : 'Remark (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              status == LogStatus.missed ? Haptics.tap() : Haptics.success();
              final before = me.logOn(h, widget.day);
              await ref.read(actionsProvider).log(h, widget.day, status!,
                  value: h.kind == TrackKind.amount && status == LogStatus.done ? value : null,
                  remark: remark.text.trim());
              if (!context.mounted) return;
              Navigator.pop(context);
              showUndo(context, ref, h, widget.day, before,
                  status == LogStatus.missed ? 'Logged as missed' : '${h.name} · +$xp XP');
            },
            child: Text(status == LogStatus.missed ? 'Log as missed' : 'Save · +$xp XP'),
          ),
        ],
      ),
    );
  }
}
