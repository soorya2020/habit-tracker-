import 'package:flutter_test/flutter_test.dart';
import 'package:one_percent_club/services/updates.dart';
import 'package:one_percent_club/services/widget_sync.dart';

void main() {
  test('release tags give build numbers', () {
    expect(Updates.buildOf('build-12'), 12);
    expect(Updates.buildOf('v1.0'), isNull);
    expect(const UpdateStatus(5, Release(6, '')).available, isTrue);
    expect(const UpdateStatus(6, Release(6, '')).available, isFalse);
    expect(const UpdateStatus(0, Release(6, '')).available, isFalse);
    expect(const UpdateStatus(5, null).available, isFalse);
  });

  test('widget taps name the habit to log', () {
    expect(WidgetSync.habitOf(Uri.parse('onepercent://log?habit=s1')), 's1');
    expect(WidgetSync.habitOf(Uri.parse('onepercent://today')), isNull);
    expect(WidgetSync.habitOf(null), isNull);
  });
}
