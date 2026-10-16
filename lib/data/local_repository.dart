import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'repository.dart';
import 'seed.dart';

/// Keeps the club on this phone in shared preferences.
///
/// On first run it loads the history imported from the Google Sheet.
class LocalRepository implements Repository {
  LocalRepository._(this._prefs, this._data);

  static const _key = 'club.v1';

  final SharedPreferences _prefs;
  ClubData _data;
  final _changes = StreamController<ClubData>.broadcast();

  static Future<LocalRepository> open([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    final data = raw == null
        ? seeded()
        : ClubData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final repo = LocalRepository._(p, data);
    if (raw == null) await repo._save();
    return repo;
  }

  static ClubData seeded() => ClubData(
        profiles: SheetImport.profiles,
        cycles: SheetImport.cycles,
        habits: [
          for (final p in SheetImport.profiles) ...SheetImport.habits(p.uid)
        ],
        logs: [for (final p in SheetImport.profiles) ...SheetImport.logs(p.uid)],
      );

  @override
  ClubData get current => _data;

  @override
  Stream<ClubData> watch() async* {
    yield _data;
    yield* _changes.stream;
  }

  Future<void> _set(ClubData d) async {
    _data = d;
    _changes.add(d);
    await _save();
  }

  Future<void> _save() => _prefs.setString(_key, jsonEncode(_data.toJson()));

  List<T> _upsert<T>(List<T> xs, T x, bool Function(T) same) {
    final out = [...xs];
    final i = out.indexWhere(same);
    i < 0 ? out.add(x) : out[i] = x;
    return out;
  }

  ClubData _copy({
    List<Profile>? profiles,
    List<Cycle>? cycles,
    List<Habit>? habits,
    List<LogEntry>? logs,
    List<Review>? reviews,
  }) =>
      ClubData(
        profiles: profiles ?? _data.profiles,
        cycles: cycles ?? _data.cycles,
        habits: habits ?? _data.habits,
        logs: logs ?? _data.logs,
        reviews: reviews ?? _data.reviews,
      );

  @override
  Future<void> putProfile(Profile p) => _set(
      _copy(profiles: _upsert(_data.profiles, p, (x) => x.uid == p.uid)));

  @override
  Future<void> putCycle(Cycle c) => _set(
      _copy(cycles: _upsert(_data.cycles, c, (x) => x.index == c.index)));

  @override
  Future<void> putHabit(Habit h) =>
      _set(_copy(habits: _upsert(_data.habits, h, (x) => x.id == h.id)));

  @override
  Future<void> putLog(LogEntry l) {
    final old = _data.logs.where((x) => x.owner == l.owner && x.id == l.id);
    if (old.isNotEmpty && old.first.updatedAt.isAfter(l.updatedAt)) {
      return Future.value();
    }
    return _set(_copy(
        logs: _upsert(_data.logs, l, (x) => x.owner == l.owner && x.id == l.id)));
  }

  @override
  Future<void> removeLog(String owner, String logId) => _set(_copy(
      logs: [
        for (final x in _data.logs)
          if (!(x.owner == owner && x.id == logId)) x
      ]));

  @override
  Future<void> putReview(Review r) =>
      _set(_copy(reviews: _upsert(_data.reviews, r, (x) => x.id == r.id)));
}
