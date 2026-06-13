import 'package:flutter_test/flutter_test.dart';
import 'package:smart_power/models/usage.dart';
import 'package:smart_power/providers/usage_provider.dart';

void main() {
  group('UsageSeries.fromJson', () {
    test('parses buckets, totals, and by_entity', () {
      final s = UsageSeries.fromJson({
        'period': 'week',
        'buckets': [
          {'label': 'Mon', 'kwh': 1.5, 'cost': 750.0},
          {'label': 'Tue', 'kwh': 2.0, 'cost': 1000.0},
        ],
        'total_kwh': 3.5,
        'total_cost': 1750.0,
        'currency': 'TSh',
        'by_entity': {'switch.radio': 1.5, 'switch.fan': 2.0},
      }, UsagePeriod.week);
      expect(s.buckets.length, 2);
      expect(s.values, [1.5, 2.0]);
      expect(s.labels, ['Mon', 'Tue']);
      expect(s.totalKwh, 3.5);
      expect(s.totalCost, 1750.0);
      expect(s.currentIndex, 1);
      expect(s.byEntity['switch.fan'], 2.0);
    });
  });

  group('UsagePeriod', () {
    test('labels + nouns + apiName', () {
      expect(UsagePeriod.day.label, 'Day');
      expect(UsagePeriod.day.noun, 'today');
      expect(UsagePeriod.month.apiName, 'month');
      expect(UsagePeriod.year.label, 'Year');
    });
  });

  group('syntheticUsage bucket counts', () {
    test('matches the gateway period shapes', () {
      expect(syntheticUsage(UsagePeriod.day, const []).buckets.length, 24);
      expect(syntheticUsage(UsagePeriod.week, const []).buckets.length, 7);
      expect(syntheticUsage(UsagePeriod.month, const []).buckets.length, 5);
      expect(syntheticUsage(UsagePeriod.year, const []).buckets.length, 12);
      // Non-empty + positive cost.
      final s = syntheticUsage(UsagePeriod.week, const []);
      expect(s.totalKwh > 0, isTrue);
      expect(s.totalCost > 0, isTrue);
    });
  });
}
