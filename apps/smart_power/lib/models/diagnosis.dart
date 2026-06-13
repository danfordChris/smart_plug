import 'package:flutter/foundation.dart';

/// One diagnosis finding (a single behaviour/fault) with its rendered message.
@immutable
class Finding {
  final String code;
  final String severity; // ok | info | warning | critical
  final String message;

  const Finding({required this.code, required this.severity, required this.message});

  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        code: j['code'] as String? ?? '',
        severity: j['severity'] as String? ?? 'ok',
        message: j['message'] as String? ?? '',
      );
}

/// A plug's appliance diagnosis from the gateway: structured status + NL.
@immutable
class Diagnosis {
  final String entityId;
  final String statusLabel; // Healthy | Notice | Needs attention | Faulty
  final String severity; // ok | info | warning | critical
  final String explanation;
  final List<Finding> findings;
  final String applianceGuess;
  final double confidence;
  final String modelVersion;

  const Diagnosis({
    required this.entityId,
    required this.statusLabel,
    required this.severity,
    required this.explanation,
    this.findings = const [],
    this.applianceGuess = '',
    this.confidence = 0.0,
    this.modelVersion = '',
  });

  bool get isHealthy => severity == 'ok';
  bool get needsAttention => severity == 'warning' || severity == 'critical';
  bool get isCollecting => modelVersion == 'insufficient-data';

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        entityId: j['entity_id'] as String? ?? '',
        statusLabel: j['status_label'] as String? ?? 'Healthy',
        severity: j['severity'] as String? ?? 'ok',
        explanation: j['explanation'] as String? ?? '',
        findings: (j['findings'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Finding.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        applianceGuess: j['appliance_guess'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        modelVersion: j['model_version'] as String? ?? '',
      );
}
