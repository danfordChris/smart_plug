import 'package:flutter/foundation.dart';

/// A server-side on/off schedule for a plug. Mirrors the gateway's
/// `ScheduleOut` payload. Times are local to the gateway timezone
/// (Africa/Dar_es_Salaam) and fire even when the phone is off.
@immutable
class Schedule {
  final int id;
  final String entityId;

  /// "on" | "off".
  final String action;

  /// Local 24h time, "HH:MM".
  final String timeHhmm;

  /// CSV of weekday ints (Mon=0..Sun=6). Empty = every day.
  final String days;
  final bool enabled;
  final String label;

  const Schedule({
    required this.id,
    required this.entityId,
    required this.action,
    required this.timeHhmm,
    required this.days,
    required this.enabled,
    required this.label,
  });

  bool get isOn => action == 'on';

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: (j['id'] as num).toInt(),
        entityId: j['entity_id'] as String? ?? '',
        action: j['action'] as String? ?? 'on',
        timeHhmm: j['time_hhmm'] as String? ?? '00:00',
        days: j['days'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
        label: j['label'] as String? ?? '',
      );

  /// Parsed set of weekday ints (Mon=0..Sun=6). Empty = every day.
  Set<int> get dayInts {
    final s = days.trim();
    if (s.isEmpty) return const {};
    return s
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
  }

  /// Human-friendly recurrence, e.g. "Every day", "Weekdays", "Mon, Wed, Fri".
  String get recurrenceLabel => describeDays(dayInts);

  static const List<String> weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String describeDays(Set<int> d) {
    if (d.isEmpty || d.length == 7) return 'Every day';
    if (d.containsAll({0, 1, 2, 3, 4}) && d.length == 5) return 'Weekdays';
    if (d.containsAll({5, 6}) && d.length == 2) return 'Weekends';
    final sorted = d.toList()..sort();
    return sorted.map((i) => weekdayShort[i]).join(', ');
  }
}
