import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models.dart';
import 'repository.dart';
import 'seed.dart';

/// The club in Cloud Firestore, shared by every member.
///
/// Collections: members, cycles, habits, logs, reviews, plus `uids`
/// (sign-in account → member) and `meta/club` (set once the club exists).
/// Firestore keeps an offline copy, so logging works without signal and
/// syncs later.
class FirestoreRepository implements Repository {
  FirestoreRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  ClubData _data = const ClubData();

  CollectionReference<Map<String, dynamic>> _c(String name) => _db.collection(name);

  @override
  ClubData get current => _data;

  /// Live club data. Each call opens its own listeners, so calling it again
  /// after signing in starts fresh.
  @override
  Stream<ClubData> watch() {
    final parts = <String, List<Map<String, dynamic>>>{};
    const names = ['members', 'cycles', 'habits', 'logs', 'reviews'];
    final subs = <StreamSubscription>[];
    late final StreamController<ClubData> out;

    void emit() {
      if (parts.length < names.length) return;
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) {
        final xs = <T>[];
        for (final m in parts[k]!) {
          try {
            xs.add(f(m));
          } catch (_) {
            // Skip a malformed document rather than breaking the app.
          }
        }
        return xs;
      }

      _data = ClubData(
        profiles: list('members', Profile.fromJson),
        cycles: list('cycles', Cycle.fromJson),
        habits: list('habits', Habit.fromJson),
        logs: list('logs', LogEntry.fromJson),
        reviews: list('reviews', Review.fromJson),
      );
      out.add(_data);
    }

    out = StreamController<ClubData>(
      onListen: () {
        for (final n in names) {
          subs.add(_c(n).snapshots().listen(
            (snap) {
              parts[n] = [for (final d in snap.docs) d.data()];
              emit();
            },
            onError: out.addError,
          ));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  static String logDocId(LogEntry l) => '${l.owner}_${l.id}';

  @override
  Future<void> putProfile(Profile p) => _c('members').doc(p.uid).set(p.toJson());

  @override
  Future<void> putCycle(Cycle c) => _c('cycles').doc('${c.index}').set(c.toJson());

  @override
  Future<void> putHabit(Habit h) => _c('habits').doc(h.id).set(h.toJson());

  @override
  Future<void> putLog(LogEntry l) => _c('logs').doc(logDocId(l)).set(l.toJson());

  @override
  Future<void> removeLog(String owner, String logId) =>
      _c('logs').doc('${owner}_$logId').delete();

  @override
  Future<void> putReview(Review r) => _c('reviews').doc(r.id).set(r.toJson());

  // ---- Joining ----

  /// The member linked to a sign-in account, if any.
  Future<String?> memberFor(String authUid) async {
    final d = await _c('uids').doc(authUid).get();
    return d.data()?['member'] as String?;
  }

  Future<bool> clubExists() async => (await _db.doc('meta/club').get()).exists;

  /// A member the admin added with this email who hasn't joined yet.
  Future<Profile?> invitedAs(String email) async {
    final q = await _c('members').where('email', isEqualTo: email.toLowerCase()).limit(1).get();
    if (q.docs.isEmpty) return null;
    final p = Profile.fromJson(q.docs.first.data());
    return p.authUid == null ? p : null;
  }

  /// First sign-in ever: creates the club from the Google Sheet history,
  /// with the signer as [memberId] and admin.
  Future<void> createClub({required String memberId, required String authUid, required String email}) async {
    final batch = _db.batch();
    for (final p in SheetImport.profiles) {
      final mine = p.uid == memberId;
      batch.set(
        _c('members').doc(p.uid),
        (mine ? p.copyWith(email: email.toLowerCase(), role: Role.admin) : p.copyWith(role: Role.member)).toJson()
          ..['authUid'] = mine ? authUid : null,
      );
    }
    for (final c in SheetImport.cycles) {
      batch.set(_c('cycles').doc('${c.index}'), c.toJson());
    }
    for (final p in SheetImport.profiles) {
      for (final h in SheetImport.habits(p.uid)) {
        batch.set(_c('habits').doc(h.id), h.toJson());
      }
      for (final l in SheetImport.logs(p.uid)) {
        batch.set(_c('logs').doc(logDocId(l)), l.toJson());
      }
    }
    batch.set(_c('uids').doc(authUid), {'member': memberId});
    batch.set(_db.doc('meta/club'), {'createdAt': DateTime.now().toIso8601String(), 'createdBy': memberId});
    await batch.commit();
  }

  /// Links an invited member to the account that just signed in.
  Future<void> claim(Profile p, String authUid) async {
    final batch = _db.batch();
    batch.update(_c('members').doc(p.uid), {'authUid': authUid});
    batch.set(_c('uids').doc(authUid), {'member': p.uid});
    await batch.commit();
  }
}
