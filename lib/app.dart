import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/future/future_screen.dart';
import 'features/log/log_sheet.dart';
import 'features/today/celebration.dart';
import 'features/insights/insights_screen.dart';
import 'features/members/members_screen.dart';
import 'features/plan/habit_editor.dart';
import 'features/plan/plan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/today/today_screen.dart';
import 'services/notifications.dart';
import 'services/reminder_sync.dart';
import 'services/updates.dart';
import 'services/widget_sync.dart';
import 'state/providers.dart';
import 'ui/theme.dart';
import 'ui/haptics.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier(ref.read(sessionProvider) != null);
  ref.listen(sessionProvider, (_, uid) => signedIn.value = uid != null);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: signedIn,
    redirect: (_, state) {
      final atSignIn = state.matchedLocation == '/signin';
      if (!signedIn.value) return atSignIn ? null : '/signin';
      return atSignIn ? '/today' : null;
    },
    routes: [
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/members', builder: (_, _) => const MembersScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/plan', builder: (_, _) => const PlanScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (_, _) => const InsightsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/future', builder: (_, _) => const FutureScreen())]),
        ],
      ),
    ],
  );
});

class OnePercentApp extends ConsumerWidget {
  const OnePercentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: '1% Club',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
      );
}

/// Bottom tabs. Also keeps reminders in sync and picks up notification taps.
class _Shell extends ConsumerStatefulWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.onQueued = _resume;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
    if (WidgetSync.supported) {
      _widgetTaps = HomeWidget.widgetClicked.listen(_openFromWidget);
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_openFromWidget);
    }
  }

  /// A habit tapped on the home-screen widget opens its log sheet.
  void _openFromWidget(Uri? uri) {
    final id = WidgetSync.habitOf(uri);
    if (id == null || !mounted) return;
    final me = ref.read(meProvider);
    final h = me.habits.where((x) => x.id == id).firstOrNull;
    widget.shell.goBranch(0);
    if (h != null) showLogSheet(context, h, me.today);
  }

  @override
  void dispose() {
    _widgetTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.instance.onQueued = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _resume();
  }

  Future<void> _resume() async {
    ref.read(clockProvider.notifier).tick();
    ref.invalidate(updateProvider);
    ref.read(actionsProvider).ensureMonths();
    await ref.read(reminderSyncProvider).drain();
    ref.read(reminderSyncProvider).schedule(ref.read(meProvider));
    WidgetSync.push(ref.read(meProvider));
    if (mounted) Celebrations.check(context, ref.read(meProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meProvider, (_, me) {
      ref.read(reminderSyncProvider).schedule(me);
      WidgetSync.push(me);
      Celebrations.check(context, me);
    });
    final t = context.tk;
    return Scaffold(
      body: widget.shell,
      // Lives here, not on Today, so snackbars push it up instead of covering it.
      floatingActionButton: widget.shell.currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Haptics.tap();
                final c = ref.read(meProvider).cycleIndex;
                showHabitEditor(context, cycle: c < 1 ? 1 : c);
              },
              backgroundColor: t.ink,
              foregroundColor: t.screen,
              icon: const Icon(Icons.add),
              label: const Text('Habit'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: (i) {
          Haptics.select();
          widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Future'),
        ],
      ),
    );
  }
}
