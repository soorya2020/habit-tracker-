import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';

/// Admin only: see everyone and add people.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).value ?? ref.watch(repositoryProvider).current;
    final me = ref.watch(meProvider);
    final t = context.tk;
    if (!me.profile.isAdmin) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Only admins can see members.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final p in club.profiles) ...[
            Builder(builder: (context) {
              final v = ref.watch(personProvider(p.uid));
              final last = v.lastLogDay;
              final c = v.cycle;
              final joined = p.authUid != null;
              return Panel(
                onTap: joined ? null : () => _setEmail(context, ref, p),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: t.accentSoft,
                    child: Text(p.name.characters.first, style: TextStyle(color: t.accent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: context.tx.titleMedium),
                      Text(last == null ? 'No logs yet' : 'Last log ${DateFormat('d MMM').format(last.date)}',
                          style: context.tx.bodySmall),
                      Text(
                        [
                          if (c != null) '${(v.cyclePercent(c) * 100).round()}% this month',
                          'Level ${v.level.level}',
                        ].join(' · '),
                        style: context.tx.bodySmall,
                      ),
                      Text(
                        joined
                            ? p.email
                            : p.email.isEmpty
                                ? 'Not joined · tap to add their Google email'
                                : 'Invited as ${p.email} · not joined yet',
                        style: context.tx.bodySmall?.copyWith(color: joined ? null : t.warn),
                      ),
                    ]),
                  ),
                  Text(p.role == Role.admin ? 'ADMIN' : 'MEMBER', style: mono(10, p.role == Role.admin ? t.accent : t.muted)),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add member'),
          ),
          const SizedBox(height: 8),
          Text('They sign in with the Google account for this email.',
              textAlign: TextAlign.center, style: context.tx.bodySmall),
        ],
      ),
    );
  }

  Future<void> _setEmail(BuildContext context, WidgetRef ref, Profile p) async {
    final email = TextEditingController(text: p.email);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Invite ${p.name}', style: ctx.tx.headlineSmall),
          const SizedBox(height: 6),
          Text('They sign in with this Google account and get ${p.name}\'s habits and history.',
              style: ctx.tx.bodySmall),
          const SizedBox(height: 14),
          TextField(
            controller: email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Google email'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!email.text.contains('@')) return;
              ref.read(actionsProvider).setMemberEmail(p, email.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
    email.dispose();
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final email = TextEditingController();
    var role = Role.member;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add member', style: ctx.tx.headlineSmall),
            const SizedBox(height: 14),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Google email')),
            const SizedBox(height: 12),
            ChoiceChips<Role>(
              values: Role.values,
              selected: (r) => r == role,
              label: (r) => r == Role.admin ? 'Admin' : 'Member',
              onSelect: (r) => set(() => role = r),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                ref.read(actionsProvider).addMember(name.text.trim(), email.text.trim(), role);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ]),
        ),
      ),
    );
    name.dispose();
    email.dispose();
  }
}
