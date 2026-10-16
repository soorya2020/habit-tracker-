import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/day.dart';
import '../../domain/models.dart';
import '../../state/person_view.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';
import '../log/log_sheet.dart';
import '../log/quick_log.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final partner = ref.watch(partnerProvider);
    final day = me.today;
    final due = me.dueOn(day);
    final optional = me.optionalOn(day);
    final done = due.where((h) => (me.logOn(h, day)?.credit ?? 0) > 0).length;
    final hour = me.now.hour;
    final greet = hour < 12 && hour >= 4 ? 'Good morning' : hour < 17 && hour >= 12 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${DateFormat('EEEE, d MMMM').format(day.date)}'
                      '${me.cycleIndex > 0 ? ' · Month ${me.cycleIndex}, day ${me.dayInCycle}' : ''}',
                      style: context.tx.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text('$greet, ${me.profile.name}', style: context.tx.headlineMedium),
                  ]),
                ),
                _ProfileButton(me: me),
              ],
            ),
            const SizedBox(height: 16),
            ..._banners(context, ref, me),
            _Summary(me: me, done: done, total: due.length),
            const SizedBox(height: 16),
            if (due.isEmpty && optional.isEmpty)
              _Empty(me: me)
            else ...[
              for (final h in due) ...[
                _HabitRow(habit: h, day: day),
                const SizedBox(height: 8),
              ],
              if (optional.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Eyebrow('Any day this week'),
                const SizedBox(height: 8),
                for (final h in optional) ...[
                  _HabitRow(habit: h, day: day, optional: true),
                  const SizedBox(height: 8),
                ],
              ],
            ],
            if (partner != null) ...[
              const SizedBox(height: 12),
              _PartnerLine(partner: partner),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _banners(BuildContext context, WidgetRef ref, PersonView me) {
    final t = context.tk;
    final actions = ref.read(actionsProvider);
    final out = <Widget>[];
    if (me.offerComeback) {
      final core = me.habits.where((h) => h.core && !h.archived).length;
      out.add(Callout(
        title: 'Welcome back, ${me.profile.name}',
        body: '${me.streak.daysAway} days away happens to everyone. Ease back in with a comeback week: '
            '${core > 0 ? 'only your $core core habits' : 'a lighter plan'} for 7 days, then the full plan returns.',
        tone: t.accent,
        actions: [
          FilledButton(onPressed: actions.startComeback, child: const Text('Start comeback week')),
          OutlinedButton(onPressed: actions.declineComeback, child: const Text('Full plan')),
        ],
      ));
    } else if (me.inComeback) {
      out.add(Callout(
        title: 'Comeback week',
        body: 'Core habits only until ${DateFormat('EEE d MMM').format(me.profile.comebackUntil!.date)}.',
        tone: t.accent,
        actions: [OutlinedButton(onPressed: actions.endComeback, child: const Text('Back to the full plan'))],
      ));
    } else if (me.streak.atRisk) {
      out.add(Callout(
        title: "Don't miss twice",
        body: 'Yesterday slipped, and your ${me.streak.current}-day streak is shielded for one day. '
            'Keep today, even with tiny versions, and it carries on.',
      ));
    }
    if (me.yesterdayOpen && !me.offerComeback) {
      final y = me.today.add(-1);
      out.add(Callout(
        title: 'Yesterday has ${me.openOn(y)} unlogged',
        body: 'You can still log it until tomorrow morning.',
        tone: t.muted,
        actions: [
          for (final h in me.dueOn(y).where((h) => me.logOn(h, y) == null).take(4))
            OutlinedButton(onPressed: () => showLogSheet(context, h, y), child: Text(h.name)),
        ],
      ));
    }
    return [for (final w in out) ...[w, const SizedBox(height: 12)]];
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.me});
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (v) => context.push(v),
      itemBuilder: (_) => [
        if (me.profile.isAdmin) const PopupMenuItem(value: '/members', child: Text('Members')),
        const PopupMenuItem(value: '/settings', child: Text('Settings')),
      ],
      child: CircleAvatar(
        radius: 20,
        backgroundColor: t.accentSoft,
        child: Text(me.profile.name.characters.first, style: TextStyle(color: t.accent, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.me, required this.done, required this.total});
  final PersonView me;
  final int done, total;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lv = me.level;
    return Panel(
      child: Row(children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: total == 0 ? 0 : done / total,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: t.heat0,
              color: t.accent,
            ),
            Text('$done/$total', style: mono(13, t.ink)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              total == 0
                  ? 'Nothing owed today'
                  : done == total
                      ? 'Day closed. Nice.'
                      : '${total - done} to go today',
              style: context.tx.titleMedium,
            ),
            const SizedBox(height: 6),
            Bar(value: lv.progress),
            const SizedBox(height: 6),
            Text('Level ${lv.level} · ${lv.toNext} XP to ${lv.level + 1}', style: context.tx.bodySmall),
          ]),
        ),
        const SizedBox(width: 12),
        Column(children: [
          Text('${me.streak.current}', style: display(26, t.ink)),
          Text('day streak', style: context.tx.bodySmall),
        ]),
      ]),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit, required this.day, this.optional = false});
  final Habit habit;
  final Day day;
  final bool optional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final me = ref.watch(meProvider);
    final log = me.logOn(habit, day);
    final rule = habit.ruleOn(day);
    final status = log?.status;
    final streak = me.habitStreak(habit);

    String meta;
    if (status == LogStatus.missed) {
      meta = log!.remark.isEmpty ? 'Missed' : 'Missed · ${log.remark}';
    } else if (status == LogStatus.tiny) {
      meta = 'Tiny version · ${habit.tiny}';
    } else if (habit.kind == TrackKind.amount) {
      meta = '${fmtNumber(log?.value ?? 0)} of ${fmtNumber(rule.target)} ${habit.unit}';
    } else if (status == LogStatus.done) {
      meta = log!.remark.isEmpty ? 'Done' : log.remark;
    } else if (optional) {
      final left = me.schedule.quota(habit, day) - me.schedule.doneThisWeekBefore(habit, day);
      meta = '$left more this week';
    } else {
      meta = rule.reminder != null ? 'Reminder at ${fmtMinutes(rule.reminder!)}' : scheduleText(rule);
    }

    final doneish = status == LogStatus.done || status == LogStatus.tiny;
    return Panel(
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      onTap: () => showLogSheet(context, habit, day),
      child: Row(children: [
        Semantics(
          button: true,
          label: doneish ? 'Mark ${habit.name} not done' : 'Mark ${habit.name} done',
          child: InkResponse(
            onTap: () => quickToggle(context, ref, habit, day),
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status == LogStatus.done
                      ? t.ok
                      : status == LogStatus.tiny
                          ? t.ok.withValues(alpha: .5)
                          : Colors.transparent,
                  border: Border.all(
                      color: status == LogStatus.missed ? t.miss : doneish ? Colors.transparent : t.line, width: 2),
                ),
                child: doneish
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : status == LogStatus.missed
                        ? Icon(Icons.close, size: 16, color: t.miss)
                        : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(habit.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.tx.titleMedium?.copyWith(
                        color: doneish ? t.muted : t.ink,
                        decoration: status == LogStatus.done ? TextDecoration.lineThrough : null)),
              ),
              const SizedBox(width: 6),
              AreaDot(habit.area, size: 6),
            ]),
            const SizedBox(height: 2),
            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tx.bodySmall),
          ]),
        ),
        if (streak > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$streak×', style: mono(12, t.muted)),
          ),
        Icon(Icons.chevron_right, color: t.muted, size: 20),
      ]),
    );
  }
}

class _PartnerLine extends StatelessWidget {
  const _PartnerLine({required this.partner});
  final PersonView partner;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final d = partner.today;
    final due = partner.dueOn(d);
    final done = due.where((h) => (partner.logOn(h, d)?.credit ?? 0) > 0).length;
    final text = due.isEmpty
        ? 'nothing owed today'
        : done == due.length
            ? 'closed the day · $done of ${due.length}'
            : '$done of ${due.length} so far today';
    return Row(children: [
      CircleAvatar(
        radius: 14,
        backgroundColor: t.heat0,
        child: Text(partner.profile.name.characters.first, style: TextStyle(fontSize: 12, color: t.ink)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: partner.profile.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: ' $text', style: TextStyle(color: t.muted)),
        ])),
      ),
      Text('${partner.streak.current}d', style: mono(12, t.muted)),
    ]);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.me});
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final upcoming = me.activeHabits.where((h) => h.startCycle > me.cycleIndex).toList()
      ..sort((a, b) => a.startCycle.compareTo(b.startCycle));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A free day', style: context.tx.titleMedium),
        const SizedBox(height: 4),
        Text(
          me.activeHabits.isEmpty
              ? 'Add your first habit to start. Keep it small enough to do on a bad day.'
              : upcoming.isNotEmpty
                  ? 'Nothing is owed today. Next up: ${upcoming.first.name} in Month ${upcoming.first.startCycle}.'
                  : 'Nothing is owed today. Rest counts too.',
          style: context.tx.bodyMedium?.copyWith(color: context.tk.muted),
        ),
      ]),
    );
  }
}
