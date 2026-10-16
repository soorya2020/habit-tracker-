import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../../widgets/common.dart';

/// Until Firebase is connected, members pick their name. With Firebase,
/// this becomes "Continue with Google".
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).value ?? ref.watch(repositoryProvider).current;
    final t = context.tk;
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
            const SizedBox(height: 8),
            Text('Google sign-in arrives when the shared online database is connected.',
                textAlign: TextAlign.center, style: context.tx.bodySmall),
          ]),
        ),
      ),
    );
  }
}
