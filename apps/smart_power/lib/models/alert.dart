import 'package:flutter/foundation.dart';

/// An in-app alert from the gateway feed: offline/online, auto-off fired, or a
/// schedule firing.
@immutable
class AppAlert {
  final int id;
  final String entityId;
  final String kind; // offline | online | auto_off | schedule_fired
  final String message;
  final bool read;
  final DateTime? createdAt;

  const AppAlert({
    required this.id,
    required this.entityId,
    required this.kind,
    required this.message,
    required this.read,
    this.createdAt,
  });

  factory AppAlert.fromJson(Map<String, dynamic> j) => AppAlert(
        id: (j['id'] as num).toInt(),
        entityId: j['entity_id'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        message: j['message'] as String? ?? '',
        read: j['read'] as bool? ?? false,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
      );
}
