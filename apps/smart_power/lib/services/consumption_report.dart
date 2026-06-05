import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/constants.dart';
import '../models/plug.dart';
import 'report_common.dart';

class ApplianceRow {
  final String name;
  final String powerLabel;
  final String usageLabel;
  final double energyKwh;
  final double costTsh;
  final double peakKw;
  const ApplianceRow({
    required this.name,
    required this.powerLabel,
    required this.usageLabel,
    required this.energyKwh,
    required this.costTsh,
    required this.peakKw,
  });
}

/// "Customer Electricity Consumption Report" — appliance-level breakdown,
/// trend, observations, recommendations and system statistics.
class ConsumptionData {
  final String customerName;
  final String meterNumber;
  final String address;
  final String period;
  final DateTime generatedOn;
  final double tariff;

  final List<ApplianceRow> appliances;
  final double totalEnergyKwh;
  final double totalCostTsh;

  final int totalAppliances;
  final String highestConsumer;
  final String lowestConsumer;
  final double avgDailyKwh;
  final double avgDailyCost;
  final double estMonthlyKwh;
  final double estMonthlyCost;

  final List<double> trend;
  final List<String> trendLabels;
  final List<String> observations;
  final List<String> recommendations;

  const ConsumptionData({
    required this.customerName,
    required this.meterNumber,
    required this.address,
    required this.period,
    required this.generatedOn,
    required this.tariff,
    required this.appliances,
    required this.totalEnergyKwh,
    required this.totalCostTsh,
    required this.totalAppliances,
    required this.highestConsumer,
    required this.lowestConsumer,
    required this.avgDailyKwh,
    required this.avgDailyCost,
    required this.estMonthlyKwh,
    required this.estMonthlyCost,
    required this.trend,
    required this.trendLabels,
    required this.observations,
    required this.recommendations,
  });
}

class ConsumptionReport {
  static final RegExp _sonoffId = RegExp(r'sonoff_([0-9a-z]+)');
  static const _trendFactors = [0.92, 1.06, 0.97, 1.12, 1.0, 1.18, 0.85];
  static const _trendLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _recommendations = [
    'Schedule heavy-load appliances such as washing machines and water heaters during off-peak hours.',
    'Replace conventional lighting with LED bulbs to lower consumption.',
    'Switch off plugs at the wall to remove standby (phantom) draw.',
    'Regularly maintain the refrigerator and other compressors for better efficiency.',
    'Install smart timers or automation controls for lighting and fans.',
  ];

  static ConsumptionData fromPlugs(
    List<Plug> plugs, {
    required double dailyKwh,
    String? customerEmail,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final days = lastDay.day;
    final tariff = AppConstants.tariffPerKwh;

    final rows = <ApplianceRow>[];
    var plugsTodayKwh = 0.0;
    for (final p in plugs) {
      final power = p.powerW ?? 0;
      final todayKwh = p.energyTodayKwh ?? 0;
      plugsTodayKwh += todayKwh;
      final energy = todayKwh * days;
      final hrs = power > 0 ? (todayKwh * 1000 / power).clamp(0, 24) : null;
      final peak = (p.history.isEmpty
              ? power
              : p.history.reduce((a, b) => a > b ? a : b)) /
          1000.0;
      rows.add(ApplianceRow(
        name: p.name,
        powerLabel: power > 0 ? ReportStyle.money.format(power) : 'N/A',
        usageLabel: hrs != null ? ReportStyle.kwh1.format(hrs) : 'N/A',
        energyKwh: energy,
        costTsh: energy * tariff,
        peakKw: peak,
      ));
    }

    // Everything the dashboard counts beyond the monitored plugs.
    final baselineToday = (dailyKwh - plugsTodayKwh).clamp(0.0, double.infinity);
    if (baselineToday > 0) {
      final energy = baselineToday * days;
      rows.add(ApplianceRow(
        name: 'Other household load',
        powerLabel: 'N/A',
        usageLabel: 'N/A',
        energyKwh: energy,
        costTsh: energy * tariff,
        peakKw: 0,
      ));
    }

    final totalEnergy = dailyKwh * days;
    final totalCost = totalEnergy * tariff;

    final sorted = [...rows]..sort((a, b) => b.energyKwh.compareTo(a.energyKwh));
    final highest = sorted.isNotEmpty ? sorted.first : null;
    final lowest = sorted.isNotEmpty ? sorted.last : null;
    final highPct = (highest != null && totalEnergy > 0)
        ? (highest.energyKwh / totalEnergy * 100)
        : 0;
    final plugShare = totalEnergy > 0
        ? (plugsTodayKwh * days / totalEnergy * 100)
        : 0;

    return ConsumptionData(
      customerName: _nameFrom(customerEmail),
      meterNumber: _meterFrom(plugs),
      address: AppConstants.billServiceAddress,
      period: '${ReportStyle.date.format(firstDay)} - ${ReportStyle.date.format(lastDay)}',
      generatedOn: now,
      tariff: tariff,
      appliances: rows,
      totalEnergyKwh: totalEnergy,
      totalCostTsh: totalCost,
      totalAppliances: plugs.length,
      highestConsumer: highest?.name ?? 'N/A',
      lowestConsumer: lowest?.name ?? 'N/A',
      avgDailyKwh: dailyKwh,
      avgDailyCost: dailyKwh * tariff,
      estMonthlyKwh: totalEnergy,
      estMonthlyCost: totalCost,
      trend: [for (final f in _trendFactors) dailyKwh * f],
      trendLabels: _trendLabels,
      observations: [
        if (highest != null)
          '${highest.name} was the highest energy consumer, contributing approximately ${highPct.toStringAsFixed(1)}% of total usage.',
        'Monitored smart plugs measured ${plugShare.toStringAsFixed(1)}% of consumption; the remainder is estimated baseline household load.',
        'Peak electricity demand typically occurs during evening hours between 7:00 PM and 11:00 PM.',
      ],
      recommendations: _recommendations,
    );
  }

  static Future<Uint8List> build(ConsumptionData d) async {
    final logo = await ReportStyle.loadLogo();
    final sym = ReportStyle.sym();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          ReportStyle.header(logo),
          pw.SizedBox(height: 14),
          ReportStyle.titleBar('Customer Electricity Consumption Report'),
          ReportStyle.sectionTitle('Customer Information'),
          ReportStyle.kv([
            ['Customer Name', d.customerName],
            ['Meter Number', d.meterNumber],
            ['Customer Address', d.address],
            ['Consumption Period', d.period],
            ['Report Generated On', ReportStyle.date.format(d.generatedOn)],
          ]),
          ReportStyle.sectionTitle('Executive Summary'),
          ReportStyle.paragraph(
            'This report summarises electricity consumption for the appliances monitored by '
            'Plug Assistance during the reporting period. The system identifies high-energy '
            'devices, estimates operational costs and supports energy-saving decisions. '
            'During this period the total energy consumed was '
            '${ReportStyle.kwh1.format(d.totalEnergyKwh)} kWh, at an estimated cost of '
            '$sym ${ReportStyle.money.format(d.totalCostTsh)}, based on a tariff of '
            '$sym ${ReportStyle.money.format(d.tariff)} per kWh.',
          ),
          ReportStyle.sectionTitle('Appliance Consumption Summary'),
          ReportStyle.table(
            ['Appliance', 'Power (W)', 'Usage (hrs/day)', 'Energy (kWh)', 'Cost ($sym)'],
            [
              for (final a in d.appliances)
                [
                  a.name,
                  a.powerLabel,
                  a.usageLabel,
                  ReportStyle.kwh1.format(a.energyKwh),
                  ReportStyle.money.format(a.costTsh),
                ],
              [
                'Total',
                '',
                '',
                ReportStyle.kwh1.format(d.totalEnergyKwh),
                ReportStyle.money.format(d.totalCostTsh),
              ],
            ],
            rightAlign: {1, 2, 3, 4},
            widths: {
              0: const pw.FlexColumnWidth(1.8),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.2),
            },
          ),
          ReportStyle.sectionTitle('Daily Energy Consumption Trend'),
          ReportStyle.barChart(d.trend, d.trendLabels),
          ReportStyle.sectionTitle('Peak Consumption Analysis'),
          ReportStyle.table(
            ['Appliance', 'Peak Usage Time', 'Peak Power Draw'],
            [
              for (final a in d.appliances.where((a) => a.peakKw > 0))
                [
                  a.name,
                  a.name.toLowerCase().contains('fridge') ||
                          a.name.toLowerCase().contains('refrig')
                      ? 'Continuous'
                      : '7:00 PM - 11:00 PM',
                  '${ReportStyle.kwh1.format(a.peakKw)} kW',
                ],
            ],
            rightAlign: {2},
          ),
          ReportStyle.sectionTitle('Observations'),
          ReportStyle.bullets(d.observations),
          ReportStyle.sectionTitle('System Recommendations'),
          ReportStyle.bullets(d.recommendations),
          ReportStyle.sectionTitle('System Generated Statistics'),
          ReportStyle.table(
            ['Metric', 'Value'],
            [
              ['Total Connected Appliances', '${d.totalAppliances}'],
              ['Highest Energy Consumer', d.highestConsumer],
              ['Lowest Energy Consumer', d.lowestConsumer],
              ['Average Daily Consumption', '${ReportStyle.kwh1.format(d.avgDailyKwh)} kWh'],
              ['Average Daily Cost', '$sym ${ReportStyle.money.format(d.avgDailyCost)}'],
              ['Estimated Monthly Consumption', '${ReportStyle.kwh1.format(d.estMonthlyKwh)} kWh'],
              ['Estimated Monthly Cost', '$sym ${ReportStyle.money.format(d.estMonthlyCost)}'],
            ],
            widths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.4),
            },
          ),
          ReportStyle.sectionTitle('Conclusion'),
          ReportStyle.paragraph(
            'The monitoring system successfully tracked the electricity consumption of '
            'individual appliances and identified the major contributors to energy use. '
            'Implementing the recommendations in this report can help reduce electricity '
            'costs and improve overall energy efficiency.',
          ),
          pw.SizedBox(height: 12),
          ReportStyle.footer(
            'System-generated estimate based on live meter data from Plug Assistance.',
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> download(ConsumptionData d) async =>
      ReportStyle.printBytes(await build(d), 'SmartPower-ConsumptionReport.pdf');

  static String _nameFrom(String? email) {
    if (email == null || email.isEmpty) return 'Account Holder';
    final local = email.split('@').first.replaceAll(RegExp(r'[._]+'), ' ');
    return local
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String _meterFrom(List<Plug> plugs) {
    for (final p in plugs) {
      final m = _sonoffId.firstMatch(p.id.toLowerCase());
      if (m != null) return 'MTR-${m.group(1)!.toUpperCase()}';
    }
    return 'MTR-00000000';
  }
}
