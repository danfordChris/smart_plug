import 'package:flutter_test/flutter_test.dart';
import 'package:smart_power/models/schedule.dart';

void main() {
  group('Schedule.fromJson', () {
    test('maps gateway payload', () {
      final s = Schedule.fromJson({
        'id': 7,
        'entity_id': 'switch.radio_sonoff_10024a_1',
        'action': 'off',
        'time_hhmm': '22:30',
        'days': '0,2,4',
        'enabled': false,
        'label': 'Night off',
      });
      expect(s.id, 7);
      expect(s.entityId, 'switch.radio_sonoff_10024a_1');
      expect(s.isOn, isFalse);
      expect(s.timeHhmm, '22:30');
      expect(s.enabled, isFalse);
      expect(s.label, 'Night off');
      expect(s.dayInts, {0, 2, 4});
    });

    test('empty days = every day', () {
      final s = Schedule.fromJson({'id': 1, 'days': ''});
      expect(s.dayInts, isEmpty);
      expect(s.recurrenceLabel, 'Every day');
    });
  });

  group('describeDays', () {
    test('special groupings', () {
      expect(Schedule.describeDays({}), 'Every day');
      expect(Schedule.describeDays({0, 1, 2, 3, 4, 5, 6}), 'Every day');
      expect(Schedule.describeDays({0, 1, 2, 3, 4}), 'Weekdays');
      expect(Schedule.describeDays({5, 6}), 'Weekends');
    });

    test('arbitrary set lists short names in order', () {
      expect(Schedule.describeDays({4, 0, 2}), 'Mon, Wed, Fri');
    });
  });
}
