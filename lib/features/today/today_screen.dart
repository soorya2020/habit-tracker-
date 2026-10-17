import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/day.dart';
import '../../domain/models.dart';
import '../../domain/motivation.dart';
import '../../domain/scoring.dart';
import '../../domain/streaks.dart';
import '../../widgets/character_figure.dart';
import '../../state/person_view.dart';
import '../../services/updates.dart';
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
            _LevelCard(me: me),
            const SizedBox(height: 12),
            _StreakCard(me: me),
            const SizedBox(height: 20),
            if (due.isNotEmpty) ...[
              Row(children: [
                Eyebrow('Today · $done of ${due.length}'),
                const Spacer(),
                Text('Worth ${Xp.perDay} XP', style: context.tx.bodySmall),
              ]),
              const SizedBox(height: 8),
            ],
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
              _PartnerCard(me: me, partner: partner),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('"${DailyLine.of(day)}"',
                  textAlign: TextAlign.center,
                  style: context.tx.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _banners(BuildContext context, WidgetRef ref, PersonView me) {
    final t = context.tk;
    final actions = ref.read(actionsProvider);
    final out = <Widget>[];
    final update = ref.watch(updateProvider).value;
    if (update != null && update.available) {
      final notes = update.latest!.notes;
      out.add(Callout(
        title: 'Update available',
        body: notes.isEmpty ? 'A newer version of the app is ready.' : 'New: $notes',
        tone: t.accent,
        actions: [FilledButton(onPressed: Updates.download, child: const Text('Download update'))],
      ));
    }
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
        if (status == null && !optional)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: Text('+${Xp.shareOf(me.schedule, habit, day, LogStatus.done)} XP', style: mono(11.5, t.accent, w: FontWeight.w600)),
          ),
        Icon(Icons.chevron_right, color: t.muted, size: 20),
      ]),
    );
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

/// Avatar and how far the next level is, in days.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.me});
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final light = Theme.of(context).brightness == Brightness.light;
    final lv = me.level;
    final full = (lv.toNext / Xp.perDay).ceil();
    final pace = me.projection.daysTo(lv.level + 1);
    final days = full == 1 ? '1 full day' : '$full full days';
    final paceText = pace == null
        ? 'Log today to get moving.'
        : pace <= full
            ? 'You are on pace.'
            : 'At your recent pace, about $pace.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.line),
        gradient: RadialGradient(
          center: const Alignment(-.6, -1),
          radius: 1.4,
          colors: light ? const [Color(0xFFE3E8FC), Color(0xFFFFFFFF)] : const [Color(0xFF1B2050), Color(0xFF0A0D1C)],
          stops: const [0, .75],
        ),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.go('/insights'),
          child: CharacterFigure(strengths: me.strengths, size: 96, tokens: light ? Tokens.light : Tokens.night),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow('Level ${lv.level} → ${lv.level + 1}', color: t.accent),
            const SizedBox(height: 4),
            Text('${lv.toNext} XP to Level ${lv.level + 1}', style: display(20, t.ink)),
            const SizedBox(height: 8),
            Bar(value: lv.progress),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: "That's "),
                TextSpan(text: days, style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                TextSpan(text: '. $paceText'),
              ]),
              style: context.tx.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Streak, the next milestone, and this week at a glance.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.me});
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final st = me.streak;
    final next = Milestones.next(st.current);
    final title = st.current == 0 ? 'Start a streak today' : '${st.current}-day streak';
    final sub = st.current == 0
        ? 'Keep $next days in a row to reach your first milestone.'
        : '${next - st.current} more ${next - st.current == 1 ? 'day' : 'days'} to a $next-day streak.';
    final start = me.today.weekStart;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🔥 $title', style: context.tx.titleMedium),
              const SizedBox(height: 2),
              Text(sub, style: context.tx.bodySmall),
            ]),
          ),
          const SizedBox(width: 12),
          Column(children: [
            Text('${st.current}', style: display(26, t.ink)),
            Text(st.current == 1 ? 'day' : 'days', style: context.tx.bodySmall),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++) _WeekDot(day: start.add(i), me: me),
        ]),
      ]),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.day, required this.me});
  final Day day;
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final label = DateFormat('E').format(day.date).characters.first;
    final isToday = day == me.today;
    final outcome = day.isBefore(me.today) ? me.streak.outcomes[day] : null;
    final todayKept = isToday && (me.scoreOn(day) ?? 0) >= .5;
    final kept = todayKept || outcome == DayOutcome.kept || outcome == DayOutcome.shielded;
    final missed = outcome == DayOutcome.missed;
    final rest = outcome == DayOutcome.rest;
    final future = day.isAfter(me.today);
    final Color bg = kept ? (outcome == DayOutcome.shielded ? t.ok.withValues(alpha: .5) : t.ok) : future || rest ? t.heat0 : Colors.transparent;
    final Color fg = kept ? Colors.white : isToday ? t.accent : t.muted;
    return Semantics(
      label: '${DateFormat('EEEE').format(day.date)}: ${kept ? 'kept' : missed ? 'missed' : isToday ? 'today' : future ? 'later' : 'rest'}',
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: kept
              ? null
              : isToday
                  ? Border.all(color: t.accent, width: 2)
                  : missed || outcome == DayOutcome.open
                      ? Border.all(color: t.line, width: 2)
                      : null,
        ),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

/// How the other member is doing today, as a friendly nudge.
class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.me, required this.partner});
  final PersonView me, partner;

  int _done(PersonView p) => p.dueOn(p.today).where((h) => (p.logOn(h, p.today)?.credit ?? 0) > 0).length;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final due = partner.dueOn(partner.today).length;
    final theirs = _done(partner), mine = _done(me);
    final mineDue = me.dueOn(me.today).length;
    final name = partner.profile.name;
    final streak = partner.streak.current;
    final what = due == 0
        ? 'has a free day'
        : theirs == due
            ? 'closed the day, $theirs of $due'
            : 'kept $theirs of $due today';
    final tail = streak > 1 ? ' and is on a $streak-day streak.' : '.';
    final nudge = mineDue == 0
        ? ''
        : mine == mineDue
            ? ' You closed yours.'
            : theirs > mine
                ? ' Your move.'
                : mine > theirs
                    ? " You're ahead today."
                    : '';
    return Panel(
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: t.accentSoft,
          child: Text(name.characters.first, style: TextStyle(color: t.accent, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' $what$tail'),
            TextSpan(text: nudge, style: TextStyle(color: t.muted)),
          ])),
        ),
      ]),
    );
  }
}
