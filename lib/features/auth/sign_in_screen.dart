import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed.dart';
import '../../state/account.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';

/// Google sign-in and joining the club. Without Firebase (phone-only
/// mode), members pick their name instead.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final cloud = ref.watch(cloudModeProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Text('1% Club', style: display(44, t.ink)),
            const SizedBox(height: 8),
            Text('Get one percent better every day, together.',
                style: context.tx.bodyLarge?.copyWith(color: t.muted)),
            const Spacer(),
            if (cloud) const _CloudGate() else const _LocalPicker(),
          ]),
        ),
      ),
    );
  }
}

class _CloudGate extends ConsumerWidget {
  const _CloudGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(accountProvider);
    final n = ref.read(accountProvider.notifier);
    final t = context.tk;
    Widget note(String s) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(s, textAlign: TextAlign.center, style: context.tx.bodySmall),
        );
    Widget signOut() => TextButton(onPressed: n.signOut, child: Text('Use another account (${a.email})'));

    switch (a.stage) {
      case Stage.loading:
        return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
      case Stage.signedOut:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton.icon(
            onPressed: n.signIn,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          if (a.error != null) note(a.error!),
        ]);
      case Stage.setup:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Set up the club', style: context.tx.titleLarge),
          const SizedBox(height: 4),
          Text('You are the first one here. Which person from the sheet are you? You will be the admin, and the sheet history comes along.',
              style: context.tx.bodyMedium?.copyWith(color: t.muted)),
          const SizedBox(height: 14),
          for (final p in SheetImport.profiles) ...[
            OutlinedButton(
              onPressed: () => n.createClub(p.uid),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text("I'm ${p.name}", style: context.tx.titleMedium),
            ),
            const SizedBox(height: 8),
          ],
          signOut(),
        ]);
      case Stage.claim:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Welcome, ${a.invite!.name}', style: context.tx.titleLarge),
          const SizedBox(height: 4),
          Text('Your admin added ${a.email}. Join to see your habits and history.',
              style: context.tx.bodyMedium?.copyWith(color: t.muted)),
          const SizedBox(height: 14),
          FilledButton(onPressed: n.claim, child: const Text('Join the club')),
          signOut(),
        ]);
      case Stage.notInvited:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Not on the list yet', style: context.tx.titleMedium),
              const SizedBox(height: 4),
              Text('Ask your admin to add ${a.email} under Members, then tap Check again.',
                  style: context.tx.bodyMedium?.copyWith(color: t.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: n.retry, child: const Text('Check again')),
          signOut(),
        ]);
      case Stage.error:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text("Couldn't reach the club", style: context.tx.titleMedium),
          note(a.error ?? ''),
          const SizedBox(height: 12),
          FilledButton(onPressed: n.retry, child: const Text('Try again')),
          signOut(),
        ]);
      case Stage.ready:
        return const SizedBox.shrink();
    }
  }
}

class _LocalPicker extends ConsumerWidget {
  const _LocalPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).value ?? ref.watch(repositoryProvider).current;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Eyebrow('Continue as'),
      const SizedBox(height: 10),
      for (final p in club.profiles) ...[
        OutlinedButton(
          onPressed: () => ref.read(sessionProvider.notifier).signInAs(p.uid),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(p.name, style: context.tx.titleMedium),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
