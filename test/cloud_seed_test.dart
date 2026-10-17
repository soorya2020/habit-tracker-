import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/data/firestore_repository.dart';
import 'package:one_percent_club/data/seed.dart';
import 'package:one_percent_club/domain/models.dart';

void main() {
  test('club setup fits in one Firestore batch with unique ids', () {
    final logs = [for (final p in SheetImport.profiles) ...SheetImport.logs(p.uid)];
    final habits = [for (final p in SheetImport.profiles) ...SheetImport.habits(p.uid)];
    final writes = SheetImport.profiles.length + SheetImport.cycles.length + habits.length + logs.length + 2;
    expect(writes, lessThan(500));
    expect(logs.map(FirestoreRepository.logDocId).toSet().length, logs.length);
    expect(habits.map((h) => h.id).toSet().length, habits.length);
  });

  test('documents survive a JSON round trip', () {
    for (final p in SheetImport.profiles) {
      final x = Profile.fromJson(p.copyWith(email: 'a@b.c').toJson()..['authUid'] = 'u1');
      expect(x.authUid, 'u1');
      expect(x.email, 'a@b.c');
      for (final h in SheetImport.habits(p.uid)) {
        expect(Habit.fromJson(h.toJson()).toJson(), h.toJson());
      }
      for (final l in SheetImport.logs(p.uid)) {
        expect(LogEntry.fromJson(l.toJson()).toJson(), l.toJson());
      }
    }
  });

  test('a member editing settings keeps their link and role', () {
    final p = Profile.fromJson(const Profile(uid: 'x', name: 'X', role: Role.admin).toJson()..['authUid'] = 'u');
    final edited = p.copyWith(cutoffHour: 2, remindersOn: false);
    expect(edited.authUid, 'u');
    expect(edited.role, Role.admin);
  });
}
