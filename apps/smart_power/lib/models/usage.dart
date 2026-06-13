import 'package:flutter/foundation.dart';

/// Period the usage chart is filtered by. `original` is the default,
/// unfiltered view (the data shown before period filtering was added).
enum UsagePeriod { original, day, week, month, year }

extension UsagePeriodX on UsagePeriod {
  /// Period sent to the gateway. `original` isn't a server period — it renders
  /// the local default view — so it maps to `week` if ever requested.
  String get apiName => this == UsagePeriod.original ? 'week' : name;

  /// True for the default (pre-filter) view, which is rendered locally.
  bool get isDefault => this == UsagePeriod.original;

  String get label {
    switch (this) {
      case UsagePeriod.original:
        return 'Default';
      case UsagePeriod.day:
        return 'Day';
      case UsagePeriod.week:
        return 'Week';
      case UsagePeriod.month:
        return 'Month';
      case UsagePeriod.year:
        return 'Year';
    }
  }

  /// Word used in "Top appliances this {word}".
  String get noun {
    switch (this) {
      case UsagePeriod.original:
        return 'today';
      case UsagePeriod.day:
        return 'today';
      case UsagePeriod.week:
        return 'week';
      case UsagePeriod.month:
        return 'month';
      case UsagePeriod.year:
        return 'year';
    }
  }
}

@immutable
class UsageBucket {
  final String label;
  final double kwh;
  final double cost;
  const UsageBucket({required this.label, required this.kwh, required this.cost});

  factory UsageBucket.fromJson(Map<String, dynamic> j) => UsageBucket(
        label: j['label'] as String? ?? '',
        kwh: (j['kwh'] as num?)?.toDouble() ?? 0,
        cost: (j['cost'] as num?)?.toDouble() ?? 0,
      );
}

@immutable
class UsageSeries {
  final UsagePeriod period;
  final List<UsageBucket> buckets;
  final double totalKwh;
  final double totalCost;
  final String currency;

  /// Per-plug totals for the period (switch entity_id → kWh).
  final Map<String, double> byEntity;

  const UsageSeries({
    required this.period,
    required this.buckets,
    required this.totalKwh,
    required this.totalCost,
    this.currency = 'TSh',
    this.byEntity = const {},
  });

  List<double> get values => [for (final b in buckets) b.kwh];
  List<String> get labels => [for (final b in buckets) b.label];

  /// Index of the latest (current) bucket — highlighted in the chart.
  int get currentIndex => buckets.isEmpty ? 0 : buckets.length - 1;

  factory UsageSeries.fromJson(Map<String, dynamic> j, UsagePeriod period) {
    final byEntity = <String, double>{};
    final raw = j['by_entity'];
    if (raw is Map) {
      raw.forEach((k, v) => byEntity['$k'] = (v as num?)?.toDouble() ?? 0);
    }
    return UsageSeries(
      period: period,
      buckets: (j['buckets'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => UsageBucket.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      totalKwh: (j['total_kwh'] as num?)?.toDouble() ?? 0,
      totalCost: (j['total_cost'] as num?)?.toDouble() ?? 0,
      currency: j['currency'] as String? ?? 'TSh',
      byEntity: byEntity,
    );
  }
}
