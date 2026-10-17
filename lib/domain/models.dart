import '../core/day.dart';

enum Area {
  physical('Physical', 'The Athlete'),
  mind('Mind', 'The Monk'),
  intellect('Intellect', 'The Scholar'),
  social('Social', 'The Orator'),
  craft('Craft', 'The Builder'),
  wealth('Wealth', 'The Investor');

  const Area(this.label, this.title);
  final String label;
  final String title;
}

/// Build: fixed days of the week. Maintain: N times a week, any days.
enum HabitMode { build, maintain }

enum TrackKind { check, amount }

enum LogStatus { done, tiny, missed }

enum Role { admin, member }

/// How a habit is scheduled from [from] onward. Editing a habit adds a new
/// rule instead of rewriting history, so past streaks keep their meaning.
class HabitRule {
  const HabitRule({
    required this.from,
    this.mode = HabitMode.build,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.perWeek = 3,
    this.target = 1,
    this.reminder,
  });

  final Day from;
  final HabitMode mode;

  /// 1 = Monday … 7 = Sunday. Used in build mode.
  final Set<int> days;

  /// Times a week. Used in maintain mode.
  final int perWeek;

  /// For amount habits: how much counts as done.
  final double target;

  /// Minutes after midnight, or null for no reminder.
  final int? reminder;

  /// Expected sessions per week, for load and coverage.
  double get weeklyLoad =>
      mode == HabitMode.build ? days.length.toDouble() : perWeek.toDouble();

  HabitRule copyWith({
    Day? from,
    HabitMode? mode,
    Set<int>? days,
    int? perWeek,
    double? target,
    int? Function()? reminder,
  }) =>
      HabitRule(
        from: from ?? this.from,
        mode: mode ?? this.mode,
        days: days ?? this.days,
        perWeek: perWeek ?? this.perWeek,
        target: target ?? this.target,
        reminder: reminder != null ? reminder() : this.reminder,
      );

  Map<String, dynamic> toJson() => {
        'from': from.key,
        'mode': mode.name,
        'days': days.toList()..sort(),
        'perWeek': perWeek,
        'target': target,
        'reminder': reminder,
      };

  factory HabitRule.fromJson(Map<String, dynamic> j) => HabitRule(
        from: Day.parse(j['from'] as String),
        mode: HabitMode.values.byName(j['mode'] as String),
        days: {...(j['days'] as List).cast<int>()},
        perWeek: j['perWeek'] as int,
        target: (j['target'] as num).toDouble(),
        reminder: j['reminder'] as int?,
      );
}

class Habit {
  const Habit({
    required this.id,
    required this.owner,
    required this.name,
    required this.area,
    required this.rules,
    required this.startCycle,
    this.endCycle,
    this.kind = TrackKind.check,
    this.unit = '',
    this.tiny = '',
    this.minutes = 15,
    this.core = false,
    this.archivedOn,
    this.countsForAreas = true,
  });

  final String id;
  final String owner;
  final String name;
  final Area area;
  final TrackKind kind;
  final String unit;

  /// The two-minute version that still keeps the streak.
  final String tiny;

  /// Rough time per session, for the load meter.
  final int minutes;

  /// Core habits are the ones kept during a comeback week.
  final bool core;

  /// Archived habits stop being due from this day; history is kept.
  final Day? archivedOn;
  bool get archived => archivedOn != null;

  /// Imported check-ins count for XP and history but not area strength.
  final bool countsForAreas;

  /// First cycle (month) this habit runs in, and optionally the last.
  final int startCycle;
  final int? endCycle;

  /// Never empty, sorted by [HabitRule.from].
  final List<HabitRule> rules;

  HabitRule ruleOn(Day d) {
    var r = rules.first;
    for (final x in rules) {
      if (!x.from.isAfter(d)) r = x;
    }
    return r;
  }

  HabitRule get current => rules.last;

  /// Adds a rule taking effect on [from], replacing any rule already
  /// starting that day or later.
  Habit withRule(HabitRule rule) {
    final kept = rules.where((r) => r.from.isBefore(rule.from)).toList();
    return copyWith(rules: [...kept, rule]);
  }

  Habit copyWith({
    String? name,
    Area? area,
    TrackKind? kind,
    String? unit,
    String? tiny,
    int? minutes,
    bool? core,
    Day? Function()? archivedOn,
    int? startCycle,
    int? Function()? endCycle,
    List<HabitRule>? rules,
  }) =>
      Habit(
        id: id,
        owner: owner,
        name: name ?? this.name,
        area: area ?? this.area,
        kind: kind ?? this.kind,
        unit: unit ?? this.unit,
        tiny: tiny ?? this.tiny,
        minutes: minutes ?? this.minutes,
        core: core ?? this.core,
        archivedOn: archivedOn != null ? archivedOn() : this.archivedOn,
        countsForAreas: countsForAreas,
        startCycle: startCycle ?? this.startCycle,
        endCycle: endCycle != null ? endCycle() : this.endCycle,
        rules: rules ?? this.rules,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': owner,
        'name': name,
        'area': area.name,
        'kind': kind.name,
        'unit': unit,
        'tiny': tiny,
        'minutes': minutes,
        'core': core,
        'archivedOn': archivedOn?.key,
        'countsForAreas': countsForAreas,
        'startCycle': startCycle,
        'endCycle': endCycle,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        owner: j['owner'] as String,
        name: j['name'] as String,
        area: Area.values.byName(j['area'] as String),
        kind: TrackKind.values.byName(j['kind'] as String),
        unit: j['unit'] as String? ?? '',
        tiny: j['tiny'] as String? ?? '',
        minutes: j['minutes'] as int? ?? 15,
        core: j['core'] as bool? ?? false,
        archivedOn: j['archivedOn'] == null
            ? null
            : Day.parse(j['archivedOn'] as String),
        countsForAreas: j['countsForAreas'] as bool? ?? true,
        startCycle: j['startCycle'] as int,
        endCycle: j['endCycle'] as int?,
        rules: (j['rules'] as List)
            .map((r) => HabitRule.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

/// One entry per habit per day.
class LogEntry {
  const LogEntry({
    required this.habitId,
    required this.owner,
    required this.day,
    required this.status,
    required this.updatedAt,
    this.value,
    this.remark = '',
    this.source = 'app',
  });

  final String habitId;
  final String owner;
  final Day day;
  final LogStatus status;
  final double? value;
  final String remark;
  final DateTime updatedAt;

  /// app, notification, widget or import.
  final String source;

  String get id => '${day.key}_$habitId';

  /// Done counts fully, tiny counts half, missed counts nothing.
  double get credit => switch (status) {
        LogStatus.done => 1,
        LogStatus.tiny => .5,
        LogStatus.missed => 0,
      };

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'owner': owner,
        'day': day.key,
        'status': status.name,
        'value': value,
        'remark': remark,
        'updatedAt': updatedAt.toIso8601String(),
        'source': source,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        habitId: j['habitId'] as String,
        owner: j['owner'] as String,
        day: Day.parse(j['day'] as String),
        status: LogStatus.values.byName(j['status'] as String),
        value: (j['value'] as num?)?.toDouble(),
        remark: j['remark'] as String? ?? '',
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        source: j['source'] as String? ?? 'app',
      );
}

/// A 30-day "month" of the programme, shared by the whole club.
class Cycle {
  const Cycle({
    required this.index,
    required this.start,
    this.focus = '',
    this.doneMeans = '',
  });

  final int index;
  final Day start;
  final String focus;
  final String doneMeans;

  Cycle copyWith({String? focus, String? doneMeans}) => Cycle(
        index: index,
        start: start,
        focus: focus ?? this.focus,
        doneMeans: doneMeans ?? this.doneMeans,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'start': start.key,
        'focus': focus,
        'doneMeans': doneMeans,
      };

  factory Cycle.fromJson(Map<String, dynamic> j) => Cycle(
        index: j['index'] as int,
        start: Day.parse(j['start'] as String),
        focus: j['focus'] as String? ?? '',
        doneMeans: j['doneMeans'] as String? ?? '',
      );
}

enum ReviewVerdict { yes, partly, no }

/// A person's end-of-month review. Worth a one-off XP bonus.
class Review {
  const Review({
    required this.owner,
    required this.cycle,
    required this.verdict,
    this.note = '',
  });

  final String owner;
  final int cycle;
  final ReviewVerdict verdict;
  final String note;

  String get id => '${owner}_$cycle';

  Map<String, dynamic> toJson() =>
      {'owner': owner, 'cycle': cycle, 'verdict': verdict.name, 'note': note};

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        owner: j['owner'] as String,
        cycle: j['cycle'] as int,
        verdict: ReviewVerdict.values.byName(j['verdict'] as String),
        note: j['note'] as String? ?? '',
      );
}

class Profile {
  const Profile({
    required this.uid,
    required this.name,
    this.email = '',
    this.authUid,
    this.role = Role.member,
    this.cutoffHour = Day.defaultCutoffHour,
    this.quietStart = 23 * 60 + 30,
    this.quietEnd = 7 * 60,
    this.nudges = const [21 * 60 + 30, 23 * 60],
    this.remindersOn = true,
    this.resting = const {},
    this.comebackUntil,
    this.comebackDeclined,
  });

  final String uid;
  final String name;
  final String email;

  /// The sign-in account linked to this member, once they have joined.
  final String? authUid;
  final Role role;
  final int cutoffHour;

  /// Minutes after midnight. No nudges between these.
  final int quietStart;
  final int quietEnd;

  /// Evening nudges, minutes after midnight, only sent if the day is open.
  final List<int> nudges;
  final bool remindersOn;

  /// Areas left out of balance and titles on purpose.
  final Set<Area> resting;

  /// While set and not passed, only core habits are due.
  final Day? comebackUntil;

  /// The day the comeback offer was turned down, so it stays hidden.
  final Day? comebackDeclined;

  bool get isAdmin => role == Role.admin;

  Profile copyWith({
    String? name,
    String? email,
    Role? role,
    int? cutoffHour,
    int? quietStart,
    int? quietEnd,
    List<int>? nudges,
    bool? remindersOn,
    Set<Area>? resting,
    Day? Function()? comebackUntil,
    Day? comebackDeclined,
  }) =>
      Profile(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        authUid: authUid,
        role: role ?? this.role,
        cutoffHour: cutoffHour ?? this.cutoffHour,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        nudges: nudges ?? this.nudges,
        remindersOn: remindersOn ?? this.remindersOn,
        resting: resting ?? this.resting,
        comebackUntil:
            comebackUntil != null ? comebackUntil() : this.comebackUntil,
        comebackDeclined: comebackDeclined ?? this.comebackDeclined,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'authUid': authUid,
        'role': role.name,
        'cutoffHour': cutoffHour,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'nudges': nudges,
        'remindersOn': remindersOn,
        'resting': resting.map((a) => a.name).toList(),
        'comebackUntil': comebackUntil?.key,
        'comebackDeclined': comebackDeclined?.key,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        uid: j['uid'] as String,
        name: j['name'] as String,
        email: j['email'] as String? ?? '',
        authUid: j['authUid'] as String?,
        role: Role.values.byName(j['role'] as String? ?? 'member'),
        cutoffHour: j['cutoffHour'] as int? ?? Day.defaultCutoffHour,
        quietStart: j['quietStart'] as int? ?? 23 * 60 + 30,
        quietEnd: j['quietEnd'] as int? ?? 7 * 60,
        nudges: (j['nudges'] as List?)?.cast<int>() ?? const [1290, 1380],
        remindersOn: j['remindersOn'] as bool? ?? true,
        resting: {
          for (final a in (j['resting'] as List? ?? const []))
            Area.values.byName(a as String)
        },
        comebackUntil: j['comebackUntil'] == null
            ? null
            : Day.parse(j['comebackUntil'] as String),
        comebackDeclined: j['comebackDeclined'] == null
            ? null
            : Day.parse(j['comebackDeclined'] as String),
      );
}
