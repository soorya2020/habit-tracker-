import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day.dart';
import '../data/auth.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/schedule.dart';
import 'account.dart';
import 'person_view.dart';

/// Set in main() once storage is open.
final repositoryProvider =
    Provider<Repository>((ref) => throw UnimplementedError());
final authServiceProvider =
    Provider<AuthService>((ref) => throw UnimplementedError());

/// Set in main(). Holds per-phone preferences such as the theme.
final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// Light, dark or follow the phone. Stored on this phone only.
class ThemeChoice extends Notifier<ThemeMode> {
  static const _key = 'ui.theme';

  @override
  ThemeMode build() {
    final v = ref.watch(prefsProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == v,
        orElse: () => ThemeMode.system);
  }

  void set(ThemeMode m) {
    ref.read(prefsProvider).setString(_key, m.name);
    state = m;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeChoice, ThemeMode>(ThemeChoice.new);

final clubProvider = StreamProvider<ClubData>((ref) {
  // Re-subscribe when the member changes, so listeners start after sign-in.
  final uid = ref.watch(sessionProvider);
  final repo = ref.watch(repositoryProvider);
  if (ref.watch(cloudModeProvider) && uid == null) return Stream.value(repo.current);
  return repo.watch();
});

/// The current minute, so the day rolls over at the cutoff by itself.
class Clock extends Notifier<DateTime> {
  Timer? _t;

  @override
  DateTime build() {
    _t = Timer.periodic(const Duration(minutes: 1), (_) => tick());
    ref.onDispose(() => _t?.cancel());
    return DateTime.now();
  }

  void tick() => state = DateTime.now();
}

final clockProvider = NotifierProvider<Clock, DateTime>(Clock.new);

/// The signed-in member's id, or null.
class Session extends Notifier<String?> {
  @override
  String? build() {
    if (ref.watch(cloudModeProvider)) {
      final a = ref.watch(accountProvider);
      return a.stage == Stage.ready ? a.memberId : null;
    }
    return ref.watch(authServiceProvider).uid;
  }

  /// Phone-only mode: pick a member by name.
  Future<void> signInAs(String uid) async {
    await ref.read(authServiceProvider).signInAs(uid);
    state = uid;
  }

  Future<void> signOut() async {
    if (ref.read(cloudModeProvider)) {
      await ref.read(accountProvider.notifier).signOut();
      return;
    }
    await ref.read(authServiceProvider).signOut();
    state = null;
  }
}

final sessionProvider = NotifierProvider<Session, String?>(Session.new);

ClubData _club(Ref ref) =>
    ref.watch(clubProvider).value ?? ref.watch(repositoryProvider).current;

final personProvider = Provider.family<PersonView, String>((ref, uid) =>
    PersonView.of(_club(ref), uid, ref.watch(clockProvider)));

/// The signed-in person.
final meProvider = Provider<PersonView>((ref) {
  final uid = ref.watch(sessionProvider);
  return ref.watch(personProvider(uid ?? ''));
});

/// The other member, for the "Sanat closed the day" line.
final partnerProvider = Provider<PersonView?>((ref) {
  final uid = ref.watch(sessionProvider);
  final others = _club(ref).profiles.where((p) => p.uid != uid).toList();
  if (others.isEmpty) return null;
  return ref.watch(personProvider(others.first.uid));
});

final actionsProvider = Provider<ClubActions>((ref) => ClubActions(ref));

/// Everything that changes data goes through here.
class ClubActions {
  ClubActions(this._ref);
  final Ref _ref;

  Repository get _repo => _ref.read(repositoryProvider);
  PersonView get _me => _ref.read(meProvider);

  Future<void> log(Habit h, Day d, LogStatus status,
      {double? value, String remark = '', String source = 'app'}) {
    return _repo.putLog(LogEntry(
      habitId: h.id,
      owner: h.owner,
      day: d,
      status: status,
      value: value,
      remark: remark,
      updatedAt: DateTime.now(),
      source: source,
    ));
  }

  /// Puts back what was there before, or clears it.
  Future<void> restore(Habit h, Day d, LogEntry? previous) => previous == null
      ? _repo.removeLog(h.owner, '${d.key}_${h.id}')
      : _repo.putLog(LogEntry(
          habitId: previous.habitId,
          owner: previous.owner,
          day: previous.day,
          status: previous.status,
          value: previous.value,
          remark: previous.remark,
          updatedAt: DateTime.now(),
          source: previous.source,
        ));

  Future<void> saveHabit(Habit h) => _repo.putHabit(h);

  Future<void> archive(Habit h) =>
      _repo.putHabit(h.copyWith(archivedOn: () => _me.today));

  Future<void> saveCycle(Cycle c) => _repo.putCycle(c);

  /// Adds the month after the last one.
  Future<Cycle> addMonth() async {
    final c = _me.calendar.nextFrom(_me.today);
    await _repo.putCycle(c);
    return c;
  }

  /// Adds empty months up to today, so the plan never runs out.
  Future<void> ensureMonths() async {
    final today = _me.today;
    var cal = _me.calendar;
    while (cal.cycles.isNotEmpty && cal.indexOf(today) > cal.cycles.last.index) {
      final c = cal.nextFrom(today);
      await _repo.putCycle(c);
      cal = Calendar([...cal.cycles, c]);
    }
  }

  /// Wipes the signed-in person's habits, logs and reviews. An admin wipes
  /// everyone's, and every month, so the whole club starts from Month 1.
  Future<void> startFresh() =>
      _repo.startFresh(_me.profile, _me.today, everyone: _me.profile.isAdmin);

  Future<void> review(int cycle, ReviewVerdict v, String note) => _repo
      .putReview(Review(owner: _me.uid, cycle: cycle, verdict: v, note: note));

  Future<void> saveProfile(Profile p) => _repo.putProfile(p);

  Future<void> startComeback() => _repo.putProfile(_me.profile
      .copyWith(comebackUntil: () => _me.today.add(6)));

  Future<void> declineComeback() =>
      _repo.putProfile(_me.profile.copyWith(comebackDeclined: _me.today));

  Future<void> endComeback() =>
      _repo.putProfile(_me.profile.copyWith(comebackUntil: () => null));

  Future<void> addMember(String name, String email, Role role) {
    final uid =
        '${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}_${DateTime.now().millisecondsSinceEpoch % 100000}';
    return _repo.putProfile(
        Profile(uid: uid, name: name, email: email.trim().toLowerCase(), role: role));
  }

  /// Admin: set the Google email a member signs in with.
  Future<void> setMemberEmail(Profile p, String email) =>
      _repo.putProfile(p.copyWith(email: email.trim().toLowerCase()));

  String newId() => 'h${DateTime.now().microsecondsSinceEpoch}';
}
