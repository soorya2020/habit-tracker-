import '../core/day.dart';
import '../domain/models.dart';

/// Everything the club shares: members, months, habits, logs and reviews.
class ClubData {
  const ClubData({
    this.profiles = const [],
    this.cycles = const [],
    this.habits = const [],
    this.logs = const [],
    this.reviews = const [],
  });

  final List<Profile> profiles;
  final List<Cycle> cycles;
  final List<Habit> habits;
  final List<LogEntry> logs;
  final List<Review> reviews;

  Profile? profile(String uid) {
    for (final p in profiles) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  List<Habit> habitsOf(String uid) => [
        for (final h in habits)
          if (h.owner == uid) h
      ];
  List<LogEntry> logsOf(String uid) => [
        for (final l in logs)
          if (l.owner == uid) l
      ];
  List<Review> reviewsOf(String uid) => [
        for (final r in reviews)
          if (r.owner == uid) r
      ];

  Map<String, dynamic> toJson() => {
        'profiles': profiles.map((x) => x.toJson()).toList(),
        'cycles': cycles.map((x) => x.toJson()).toList(),
        'habits': habits.map((x) => x.toJson()).toList(),
        'logs': logs.map((x) => x.toJson()).toList(),
        'reviews': reviews.map((x) => x.toJson()).toList(),
      };

  factory ClubData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        [for (final x in (j[k] as List? ?? const [])) f(x as Map<String, dynamic>)];
    return ClubData(
      profiles: list('profiles', Profile.fromJson),
      cycles: list('cycles', Cycle.fromJson),
      habits: list('habits', Habit.fromJson),
      logs: list('logs', LogEntry.fromJson),
      reviews: list('reviews', Review.fromJson),
    );
  }
}

/// Storage for the club. The local version keeps everything on the phone;
/// a Firestore version will implement the same interface.
abstract class Repository {
  ClubData get current;
  Stream<ClubData> watch();

  Future<void> putProfile(Profile p);
  Future<void> putCycle(Cycle c);
  Future<void> putHabit(Habit h);

  /// One log per habit per day. The newer [LogEntry.updatedAt] wins.
  Future<void> putLog(LogEntry l);
  Future<void> removeLog(String owner, String logId);
  Future<void> putReview(Review r);

  /// Deletes every habit, log and review of [p] and marks the day they
  /// started fresh. With [everyone], wipes every member's habits, logs and
  /// reviews and every month too, so the whole club starts over.
  Future<void> startFresh(Profile p, Day today, {bool everyone = false});
}
