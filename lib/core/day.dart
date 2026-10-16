/// A calendar day in the user's local time zone.
///
/// A day closes at [defaultCutoffHour] the next morning, so logging at
/// 1 AM still counts for the evening before.
class Day implements Comparable<Day> {
  const Day._(this._n);

  /// Days since 1970-01-01.
  final int _n;

  static const defaultCutoffHour = 3;

  factory Day(int year, int month, int day) =>
      Day._(DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ _ms);

  /// The day a local moment belongs to, with the day ending at [cutoffHour].
  factory Day.of(DateTime t, {int cutoffHour = defaultCutoffHour}) {
    final shifted = t.subtract(Duration(hours: cutoffHour));
    return Day(shifted.year, shifted.month, shifted.day);
  }

  factory Day.today({int cutoffHour = defaultCutoffHour}) =>
      Day.of(DateTime.now(), cutoffHour: cutoffHour);

  /// Parses `yyyy-mm-dd`.
  factory Day.parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return Day(p[0], p[1], p[2]);
  }

  static const _ms = 86400000;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(_n * _ms, isUtc: true);
  int get year => date.year;
  int get month => date.month;
  int get dayOfMonth => date.day;

  /// 1 = Monday … 7 = Sunday.
  int get weekday => date.weekday;

  /// Monday of this day's week.
  Day get weekStart => add(1 - weekday);

  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${dayOfMonth.toString().padLeft(2, '0')}';

  Day add(int days) => Day._(_n + days);

  /// Whole days from [other] to this day.
  int diff(Day other) => _n - other._n;

  /// The local moment this day starts (at the cutoff hour).
  DateTime startsAt({int cutoffHour = defaultCutoffHour}) =>
      DateTime(year, month, dayOfMonth, cutoffHour);

  /// The local moment on this calendar date at [minutes] after midnight.
  DateTime at(int minutes) =>
      DateTime(year, month, dayOfMonth, minutes ~/ 60, minutes % 60);

  bool isBefore(Day o) => _n < o._n;
  bool isAfter(Day o) => _n > o._n;

  Iterable<Day> until(Day end) sync* {
    for (var d = this; !d.isAfter(end); d = d.add(1)) {
      yield d;
    }
  }

  @override
  int compareTo(Day other) => _n.compareTo(other._n);
  @override
  bool operator ==(Object other) => other is Day && other._n == _n;
  @override
  int get hashCode => _n;
  @override
  String toString() => key;
}
