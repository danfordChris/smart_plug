/// Raw Home Assistant `/api/states/<entity_id>` response.
///
/// Shape per HA docs:
/// {
///   "entity_id": "switch.radio",
///   "state": "on" | "off" | "unavailable",
///   "attributes": { ... },
///   "last_changed": "2026-05-20T16:00:00Z",
///   "last_updated": "2026-05-20T16:00:00Z"
/// }
class HaStateResponse {
  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime? lastChanged;
  final DateTime? lastUpdated;

  const HaStateResponse({
    required this.entityId,
    required this.state,
    required this.attributes,
    this.lastChanged,
    this.lastUpdated,
  });

  factory HaStateResponse.fromJson(Map<String, dynamic> json) {
    return HaStateResponse(
      entityId: json['entity_id'] as String? ?? '',
      state: json['state'] as String? ?? 'unavailable',
      attributes: Map<String, dynamic>.from(
        (json['attributes'] as Map?) ?? const {},
      ),
      lastChanged: _parseDate(json['last_changed']),
      lastUpdated: _parseDate(json['last_updated']),
    );
  }

  static DateTime? _parseDate(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Numeric coercion for sensor states. Returns null on parse failure or
  /// when the entity is `unavailable` / `unknown`.
  double? asDouble() {
    if (state.isEmpty) return null;
    if (state == 'unavailable' || state == 'unknown') return null;
    return double.tryParse(state);
  }
}
