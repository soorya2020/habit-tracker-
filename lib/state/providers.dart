import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/day.dart';
import '../data/auth.dart';
import '../data/repository.dart';
import '../domain/models.dart';
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

final clubProvider = StreamProvider<ClubData>(
    (ref) => ref.watch(repositoryProvider).watch());

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

class Session extends Notifier<String?> {
  @override
  String? build() => ref.watch(authServiceProvider).uid;

  Future<void> signInAs(String uid) async {
    await ref.read(authServiceProvider).signInAs(uid);
    state = uid;
  }

  Future<void> signOut() async {
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
    return _repo.putProfile(Profile(uid: uid, name: name, email: email, role: role));
  }

  String newId() => 'h${DateTime.now().microsecondsSinceEpoch}';
}
