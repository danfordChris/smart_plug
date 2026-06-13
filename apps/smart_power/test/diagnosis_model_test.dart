import 'package:flutter_test/flutter_test.dart';
import 'package:smart_power/models/diagnosis.dart';

void main() {
  test('Diagnosis.fromJson parses gateway payload', () {
    final d = Diagnosis.fromJson({
      'entity_id': 'switch.radio',
      'status_label': 'Needs attention',
      'severity': 'warning',
      'explanation': 'Drawing power while off.',
      'findings': [
        {'code': 'stuck_on', 'severity': 'warning', 'message': 'Stuck relay.'},
        {'code': 'healthy', 'severity': 'ok', 'message': 'ok'},
      ],
      'appliance_guess': 'radio',
      'confidence': 0.82,
      'model_version': '1',
    });
    expect(d.entityId, 'switch.radio');
    expect(d.severity, 'warning');
    expect(d.needsAttention, isTrue);
    expect(d.isHealthy, isFalse);
    expect(d.isCollecting, isFalse);
    expect(d.findings.length, 2);
    expect(d.findings.first.code, 'stuck_on');
    expect(d.applianceGuess, 'radio');
    expect(d.confidence, closeTo(0.82, 1e-9));
  });

  test('healthy + collecting flags', () {
    final healthy = Diagnosis.fromJson({'entity_id': 'switch.x', 'severity': 'ok'});
    expect(healthy.isHealthy, isTrue);
    expect(healthy.needsAttention, isFalse);

    final collecting = Diagnosis.fromJson(
        {'entity_id': 'switch.x', 'severity': 'ok', 'model_version': 'insufficient-data'});
    expect(collecting.isCollecting, isTrue);
  });
}
