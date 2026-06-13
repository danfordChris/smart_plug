import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/plug.dart';
import '../models/usage.dart';
import '../services/usage_api.dart';
import 'plugs_provider.dart';
import 'settings_provider.dart';

final usageApiProvider = Provider<UsageApi?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  final api = UsageApi(
    baseUrl: settings.gatewayUrl!,
    token: settings.accessToken!,
    refresher: () => ref.read(settingsProvider.notifier).refreshAccessToken(),
  );
  ref.onDispose(api.dispose);
  return api;
});

/// Selected usage period. Defaults to [UsagePeriod.original] — the unfiltered
/// view shown before period filtering was added.
final usagePeriodProvider = StateProvider<UsagePeriod>((_) => UsagePeriod.original);

/// Aggregate usage for a period. Real from the gateway when signed in; the
/// `original` default and the not-signed-in case render a synthetic series.
final usageProvider =
    FutureProvider.family<UsageSeries, UsagePeriod>((ref, period) async {
  final api = ref.watch(usageApiProvider);
  if (api == null || period.isDefault) {
    final plugs = ref.read(plugsProvider).valueOrNull ?? const <Plug>[];
    return syntheticUsage(period, plugs);
  }
  return api.fetch(period);
});

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Deterministic synthetic series so the chart looks alive in demo/preview.
UsageSeries syntheticUsage(UsagePeriod period, List<Plug> plugs) {
  final base = plugs.isEmpty
      ? 18.0
      : plugs.fold<double>(0, (a, p) => a + (p.energyTodayKwh ?? 0)).clamp(2.0, 200.0);

  late List<double> values;
  late List<String> labels;
  switch (period) {
    case UsagePeriod.original:
      // The pre-filter default: the original synthetic week seed with today's
      // live total folded into the latest bar.
      labels = _weekdayLabels;
      final today = plugs.fold<double>(0, (a, p) => a + (p.energyTodayKwh ?? 0));
      values = [16.4, 18.1, 15.2, 19.8, 17.6, 14.5, today + 17.1];
      break;
    case UsagePeriod.day:
      labels = [for (var h = 0; h < 24; h++) h.toString().padLeft(2, '0')];
      values = [
        for (var h = 0; h < 24; h++)
          (base / 24) * (1 + 0.6 * _g((h - 8) / 3) + 0.9 * _g((h - 19) / 3)),
      ];
      break;
    case UsagePeriod.week:
      labels = _weekdayLabels;
      const f = [0.92, 1.03, 0.86, 1.12, 0.99, 0.82, 1.0];
      values = [for (var i = 0; i < 7; i++) base * f[i]];
      break;
    case UsagePeriod.month:
      labels = ['W1', 'W2', 'W3', 'W4', 'W5'];
      const f = [6.8, 7.1, 6.5, 7.0, 3.4];
      values = [for (var i = 0; i < 5; i++) base * f[i]];
      break;
    case UsagePeriod.year:
      labels = _monthLabels;
      const f = [30, 27, 31, 29, 33, 28, 26, 30, 31, 32, 29, 18.0];
      values = [for (var i = 0; i < 12; i++) base * f[i]];
      break;
  }

  final buckets = [
    for (var i = 0; i < values.length; i++)
      UsageBucket(
        label: labels[i],
        kwh: values[i],
        cost: values[i] * AppConstants.tariffPerKwh,
      ),
  ];
  final total = values.fold<double>(0, (a, b) => a + b);
  final periodFactor = total / (base == 0 ? 1 : base);
  // The default view's breakdown is "today" → use today's energy as-is.
  final byEntity = {
    for (final p in plugs)
      p.entityId: period == UsagePeriod.original
          ? (p.energyTodayKwh ?? 0)
          : (p.energyTodayKwh ?? 0) * periodFactor,
  };
  return UsageSeries(
    period: period,
    buckets: buckets,
    totalKwh: total,
    totalCost: total * AppConstants.tariffPerKwh,
    currency: AppConstants.currencySymbol,
    byEntity: byEntity,
  );
}

double _g(double x) => 1.0 / (x * x + 1);
