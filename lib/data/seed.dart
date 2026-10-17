import '../core/day.dart';
import '../domain/models.dart';

/// One-time import from the "6-Month Skill Transformation" Google Sheet.
///
/// The sheet keeps one P (practised) or M (missed) per person per day, so
/// history comes in as a "Daily check-in" habit that carries XP, streaks
/// and remarks. Each day is also credited to the habits it names in its
/// remark ("gym, chess, comm"), or to that month's focus when the remark
/// names none, so the areas and the avatar start from the sheet too.
class SheetImport {
  static const soorya = 'soorya';
  static const sanat = 'sanat';
  static const checkInId = 'checkin';

  /// The day the app takes over from the sheet. Habits are owed from here.
  static final handover = Day(2026, 10, 16);

  static final cycles = <Cycle>[
    Cycle(index: 1, start: Day(2026, 8, 17), focus: 'Public speaking · AI course · Reading', doneMeans: 'One unscripted 3-min talk a week, 1–2 h of AI course daily, finish a book'),
    Cycle(index: 2, start: Day(2026, 9, 18), focus: 'Communication · Chess', doneMeans: 'Improve vocabulary; daily communication drill and chess puzzles'),
    Cycle(index: 3, start: Day(2026, 10, 18), focus: 'Hindi · LinkedIn', doneMeans: 'Basic Hindi conversation, 2 LinkedIn posts every week'),
    Cycle(index: 4, start: Day(2026, 11, 17), focus: 'Hindi · Communication · AI course', doneMeans: 'Keep posting on LinkedIn, 2 posts a week'),
    Cycle(index: 5, start: Day(2026, 12, 17), focus: 'Startup & politics · Being funny', doneMeans: 'Same goals as Sanat'),
    Cycle(index: 6, start: Day(2027, 1, 16), focus: 'Startup · Networking · Personal brand', doneMeans: 'Meet new people, try a bootcamp'),
    Cycle(index: 7, start: Day(2027, 2, 15), focus: 'Dance', doneMeans: 'To be decided'),
    Cycle(index: 8, start: Day(2027, 3, 17), focus: 'Ukulele', doneMeans: 'To be decided'),
  ];

  static const profiles = <Profile>[
    Profile(uid: soorya, name: 'Soorya', role: Role.admin),
    Profile(uid: sanat, name: 'Sanat'),
  ];

  /// Date of "Month m, day d" as the sheet records it. Month 1 days 1–18
  /// run from 17 Aug; days 19–30 run up to 17 Sep (the sheet skips 4–5
  /// Sep). Month 2 day 1 is 18 Sep.
  static Day dateOf(int month, int day) {
    if (month == 2) return Day(2026, 9, 17).add(day);
    if (day <= 18) return Day(2026, 8, 16).add(day);
    return Day(2026, 9, 17).add(day - 30);
  }

  // Rows from the Daily Tracker tab: [status, remark] per day.
  static const _soorya = <int, List<List<String>>>{
    1: [
      ['P', 'read 3pages , watched 1 1/2 chapter of ai content'], ['P', 'reading book must be improved, atkeat 10pages a day'], ['P', '1.5hr course and read 3chapters, i started enjoying reading'], ['M', 'failed and taking full responsibility 🙌'], ['P', '2hrs of course completed, started daily journaling again'], ['P', '2.5hrs on AI course'], ['P', ''], ['M', 'i am a looser'], ['M', 'i am a looser'], ['M', 'i am a loosee(myr)'],
      ['P', 'comeback'], ['P', ''], ['P', ''], ['P', '45mins ai and 30mins chess opening moves and intro.mudukaaaa'], ['P', 'only watched for 15 mins, got overwhelmed, stadted cgess and communication day1'], ['P', 'communication task completed'], ['P', '1hr ai,comm, journaling,chess'], ['P', 'chess and debate, no ai'], ['P', 'na'], ['P', ''],
      ['M', 'got late and skipped comm vedio'], ['P', ''], ['P', ''], ['P', ''], ['M', ''], ['P', ''], ['M', ''], ['P', ''], ['P', ''], ['P', 'kodai'],
    ],
    2: [
      ['P', 'kodai'], ['P', 'kodai'], ['P', 'kodai'], ['M', ''], ['M', ''], ['M', ''], ['P', ''], ['M', ''], ['M', ''], ['P', ''],
      ['M', ''], ['P', ''], ['P', ''], ['M', ''], ['M', ''], ['M', ''], ['M', ''], ['M', ''], ['M', ''],
    ],
  };

  static const _sanat = <int, List<List<String>>>{
    1: [
      ['P', 'Leg day, followed by diet'], ['P', 'push day, sleep on low side, need to improve'], ['P', 'rest day, followed a strict diet'], ['P', "pull day. tatakae, maintained a strict diet. went for team dinner, Didn't junk"], ['P', 'Ran 8k, pushed my limits after 7km'], ['P', 'went for upper body in hometown gym'], ['P', 'tight schedule, did abs workout, showed up.'], ['P', 'planned to fail, will show up tomorrow.changed mind, went for a 5k'], ['P', 'did 5 sets of pull up and 45 pushup divided. but not satisfied.'], ['M', 'failed miserably, was rest day but ordered junk'],
      ['P', 'leg day, followed diet'], ['P', 'perfect'], ['P', '10k run'], ['P', 'rest day, body tired. changed push day to tomorrow'], ['P', 'Did push day, started chess and communication'], ['P', 'rest day with diet, and chess commm'], ['P', 'pull day, chess, comm done'], ['P', 'leg day, chess comm done'], ['P', 'upper, chess,comm'], ['P', 'chess, comm, rest day'],
      ['P', 'missed gym, did chess and comm'], ['P', 'gym,chess, comm'], ['P', 'gym chess comm'], ['P', 'prepared speech, chess'], ['M', ''], ['P', ''], ['P', 'debate, chess, leg'], ['P', 'push, chess, comm'], ['P', 'pull, chess ,comm'], ['P', 'kodai'],
    ],
    2: [
      ['P', 'kodai'], ['P', 'kodai'], ['P', 'kodai'], ['M', 'comm sess miss'], ['M', 'comm sess miss'], ['M', 'comm sess miss'], ['P', 'Did both'], ['M', 'comm sess miss'], ['P', ''], ['M', 'Poondi'],
      ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', 'Poondi'], ['M', ''],
      ['M', ''], ['M', ''], ['M', ''], ['P', "RESTART'"],
    ],
  };

  /// Monthly completion, as the sheet's Goals Overview shows it.
  static double sheetPercent(String uid, int month) {
    final rows = (uid == soorya ? _soorya : _sanat)[month] ?? const [];
    if (rows.isEmpty) return 0;
    return rows.where((r) => r[0] == 'P').length / 30;
  }

  static Habit checkIn(String owner) => Habit(
        id: '${checkInId}_$owner',
        owner: owner,
        name: 'Daily check-in (from the sheet)',
        area: Area.mind,
        countsForAreas: false,
        startCycle: 1,
        endCycle: 2,
        archivedOn: handover,
        rules: [HabitRule(from: cycles.first.start, mode: HabitMode.maintain, perWeek: 0)],
      );

  static List<LogEntry> logs(String owner) {
    final rows = owner == soorya ? _soorya : _sanat;
    final at = DateTime(2026, 10, 16);
    return [
      for (final m in rows.keys)
        for (var i = 0; i < rows[m]!.length; i++)
          LogEntry(
            habitId: '${checkInId}_$owner',
            owner: owner,
            day: dateOf(m, i + 1),
            status: rows[m]![i][0] == 'P' ? LogStatus.done : LogStatus.missed,
            remark: rows[m]![i][1],
            updatedAt: at,
            source: 'import',
          ),
    ];
  }

  /// Habits each sheet day is credited to: the ones its remark names, or
  /// the month's focus when it names none. Days the sheet marks M count as
  /// misses for the same habits.
  static Map<String, LogStatus> creditsFor(String owner, int month, int day, String status, String remark) {
    final text = remark.toLowerCase().replaceAll(RegExp(r'\bno \w+'), '');
    bool has(String pattern) => RegExp(pattern).hasMatch(text);
    final named = <String, LogStatus>{};
    void put(String id, bool missed) => named[id] = missed ? LogStatus.missed : LogStatus.done;
    if (owner == soorya) {
      if (has(r'\bai\b|course')) put('s1', false);
      if (has(r'read|book|page|chapter')) put('s5', false);
      if (has(r'journal')) put('s4', false);
      if (has(r'chess')) put('s6', false);
      if (has(r'comm|debate|speech')) put('s3', has(_commMissed));
    } else {
      if (has(r'missed gym')) {
        put('n1', true);
      } else if (has(r'leg|push|pull|upper|gym|abs|run|ran|\dk\b|workout')) {
        put('n1', false);
      }
      if (has(r'junk') && !has(r"didn't junk")) {
        put('n2', true);
      } else if (has(r'diet')) {
        put('n2', false);
      }
      if (has(r'chess|both')) put('n3', false);
      if (has(r'comm|debate|speech|both')) put('n4', has(_commMissed));
    }
    final missed = status != 'P';
    if (named.isNotEmpty) {
      return missed ? {for (final id in named.keys) id: LogStatus.missed} : named;
    }
    // Chess and communication drills started on day 15 of month 1.
    final focus = owner == soorya
        ? (month == 1 ? (day < 15 ? ['s1', 's5'] : ['s1', 's3', 's6']) : ['s3', 's6'])
        : (month == 1 ? (day < 15 ? ['n1', 'n2'] : ['n1', 'n3', 'n4']) : ['n3', 'n4']);
    return {for (final id in focus) id: missed ? LogStatus.missed : LogStatus.done};
  }

  static const _commMissed = r'comm\w*( \w+)? miss|(skip|miss)\w* comm';

  /// Sheet days credited to individual habits.
  static List<LogEntry> habitLogs(String owner) {
    final rows = owner == soorya ? _soorya : _sanat;
    final at = DateTime(2026, 10, 16);
    return [
      for (final m in rows.keys)
        for (var i = 0; i < rows[m]!.length; i++)
          for (final c in creditsFor(owner, m, i + 1, rows[m]![i][0], rows[m]![i][1]).entries)
            LogEntry(habitId: c.key, owner: owner, day: dateOf(m, i + 1), status: c.value, updatedAt: at, source: 'import'),
    ];
  }

  /// Every imported log: the daily check-in and the habits it is credited to.
  static List<LogEntry> allLogs(String owner) => [...logs(owner), ...habitLogs(owner)];

  /// Lets a habit hold sheet history: before the handover it is owed only
  /// on days it was logged, so the import adds no misses of its own.
  static Habit _history(Habit h) => h.copyWith(
        startCycle: 1,
        rules: [HabitRule(from: cycles.first.start, mode: HabitMode.maintain, perWeek: 0), ...h.rules],
      );

  static const _withHistory = {'s1', 's3', 's4', 's5', 's6', 'n1', 'n2', 'n3', 'n4'};

  static List<Habit> habits(String owner) => [
        for (final h in _habits(owner)) _withHistory.contains(h.id) ? _history(h) : h,
      ];

  static HabitRule _r(Set<int> days, {int? at, double target = 1}) =>
      HabitRule(from: handover, days: days, reminder: at, target: target);

  static const _all = {1, 2, 3, 4, 5, 6, 7};
  static int _t(int h, int m) => h * 60 + m;

  static List<Habit> _habits(String owner) => owner == soorya
      ? [
          Habit(id: 's1', owner: owner, name: 'AI course', area: Area.intellect, kind: TrackKind.amount, unit: 'min', tiny: '10 min', minutes: 60, core: true, startCycle: 1, rules: [_r({1, 2, 3, 4, 5, 6}, at: _t(19, 0), target: 60)]),
          Habit(id: 's4', owner: owner, name: 'Journal', area: Area.mind, tiny: 'one line', minutes: 10, core: true, startCycle: 1, rules: [_r(_all, at: _t(22, 30))]),
          Habit(id: 's5', owner: owner, name: 'Read', area: Area.intellect, kind: TrackKind.amount, unit: 'pages', tiny: '1 page', minutes: 20, startCycle: 1, rules: [_r(_all, at: _t(22, 0), target: 10)]),
          Habit(id: 's3', owner: owner, name: 'Communication drill', area: Area.social, tiny: 'one 2-minute talk', minutes: 20, core: true, startCycle: 2, rules: [_r({1, 2, 3, 4, 5}, at: _t(20, 0))]),
          Habit(id: 's6', owner: owner, name: 'Chess puzzles', area: Area.intellect, tiny: '1 puzzle', minutes: 15, startCycle: 2, rules: [_r(_all, at: _t(22, 0))]),
          Habit(id: 's2', owner: owner, name: 'Hindi basics', area: Area.intellect, kind: TrackKind.amount, unit: 'min', tiny: '5 min', minutes: 20, startCycle: 3, rules: [_r(_all, at: _t(8, 0), target: 20)]),
          Habit(id: 's7', owner: owner, name: 'LinkedIn post', area: Area.social, tiny: 'draft 3 lines', minutes: 30, startCycle: 3, rules: [_r({2, 5}, at: _t(19, 30))]),
          Habit(id: 's8', owner: owner, name: 'Politics reading', area: Area.intellect, kind: TrackKind.amount, unit: 'min', tiny: '1 article', minutes: 20, startCycle: 5, rules: [_r({1, 2, 3, 4, 5}, at: _t(21, 0), target: 20)]),
          Habit(id: 's9', owner: owner, name: 'Stand-up practice', area: Area.social, tiny: '1 joke', minutes: 20, startCycle: 5, rules: [_r({3, 6}, at: _t(20, 30))]),
          Habit(id: 's10', owner: owner, name: 'Networking meetup', area: Area.social, tiny: 'message 1 person', minutes: 60, startCycle: 6, rules: [_r({6}, at: _t(18, 0))]),
          Habit(id: 's11', owner: owner, name: 'Dance practice', area: Area.physical, kind: TrackKind.amount, unit: 'min', tiny: '1 song', minutes: 30, startCycle: 7, rules: [_r({1, 3, 5}, at: _t(19, 0), target: 30)]),
          Habit(id: 's12', owner: owner, name: 'Ukulele', area: Area.craft, kind: TrackKind.amount, unit: 'min', tiny: '5 min', minutes: 20, startCycle: 8, rules: [_r(_all, at: _t(21, 30), target: 20)]),
          checkIn(owner),
        ]
      : [
          Habit(id: 'n1', owner: owner, name: 'Gym', area: Area.physical, tiny: '20 push-ups', minutes: 60, core: true, startCycle: 1, rules: [_r({1, 2, 3, 4, 5, 6}, at: _t(18, 30))]),
          Habit(id: 'n2', owner: owner, name: 'Clean diet', area: Area.physical, tiny: 'no junk today', minutes: 0, startCycle: 1, rules: [_r(_all, at: _t(21, 0))]),
          Habit(id: 'n3', owner: owner, name: 'Chess puzzles', area: Area.intellect, tiny: '1 puzzle', minutes: 15, startCycle: 1, rules: [_r(_all, at: _t(22, 0))]),
          Habit(id: 'n4', owner: owner, name: 'Communication drill', area: Area.social, tiny: 'one 2-minute talk', minutes: 20, core: true, startCycle: 2, rules: [_r({1, 2, 3, 4, 5}, at: _t(20, 0))]),
          checkIn(owner),
        ];
}
