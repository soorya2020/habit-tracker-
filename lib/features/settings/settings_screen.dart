import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final p = me.profile;
    final actions = ref.read(actionsProvider);
    void save(Profile x) => actions.saveProfile(x);

    Future<int?> pick(int m) async {
      final r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
      return r == null ? null : r.hour * 60 + r.minute;
    }

    Widget section(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Eyebrow(s),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          section('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {ref.watch(themeModeProvider)},
              showSelectedIcon: false,
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          section('Day'),
          ListTile(
            title: const Text('Day ends at'),
            subtitle: const Text('Logging after midnight still counts for the evening before.'),
            trailing: DropdownButton<int>(
              value: p.cutoffHour,
              underline: const SizedBox(),
              items: [for (final h in [0, 1, 2, 3, 4, 5]) DropdownMenuItem(value: h, child: Text(fmtMinutes(h * 60)))],
              onChanged: (h) => save(p.copyWith(cutoffHour: h)),
            ),
          ),
          section('Reminders'),
          SwitchListTile(
            title: const Text('Reminders'),
            subtitle: const Text('Habit reminders and evening nudges, at most 4 a day.'),
            value: p.remindersOn,
            onChanged: (v) => save(p.copyWith(remindersOn: v)),
          ),
          for (var i = 0; i < p.nudges.length; i++)
            ListTile(
              title: Text(i == p.nudges.length - 1 ? 'Last call' : 'Evening nudge'),
              subtitle: const Text('Only if the day is still open'),
              trailing: Text(fmtMinutes(p.nudges[i]), style: mono(14, context.tk.ink)),
              onTap: () async {
                final m = await pick(p.nudges[i]);
                if (m == null) return;
                save(p.copyWith(nudges: [...p.nudges]..[i] = m));
              },
            ),
          ListTile(
            title: const Text('Quiet hours'),
            subtitle: const Text('Nothing is sent in this window.'),
            trailing: Text('${fmtMinutes(p.quietStart)}–${fmtMinutes(p.quietEnd)}', style: mono(14, context.tk.ink)),
            onTap: () async {
              final a = await pick(p.quietStart);
              if (a == null || !context.mounted) return;
              final b = await pick(p.quietEnd);
              if (b == null) return;
              save(p.copyWith(quietStart: a, quietEnd: b));
            },
          ),
          section('Resting areas'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Areas you are leaving alone on purpose. They are left out of balance and titles.',
                  style: context.tx.bodySmall),
              const SizedBox(height: 10),
              ChoiceChips<Area>(
                values: Area.values,
                selected: p.resting.contains,
                label: (a) => a.label,
                leading: (a) => AreaDot(a),
                onSelect: (a) => save(p.copyWith(
                    resting: p.resting.contains(a) ? ({...p.resting}..remove(a)) : {...p.resting, a})),
              ),
            ]),
          ),
          section('Account'),
          ListTile(
            title: Text(p.name),
            subtitle: Text(p.isAdmin ? 'Admin' : 'Member'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () => ref.read(sessionProvider.notifier).signOut(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
