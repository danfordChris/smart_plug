import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/config/constants.dart';
import 'package:smart_power/models/plug.dart';
import 'package:smart_power/services/bill_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('charges: energy at tariff, 18% VAT on energy+service, total sums', () {
    final d = BillReport.fromPlugs(
      const [],
      dailyKwh: 10, // 10 kWh/day
      customerEmail: 'musa.nziku@home.test',
      now: DateTime(2026, 5, 15), // May → 31 days
    );
    expect(d.consumedKwh, 10 * 31);
    expect(d.energyCharge, 310 * AppConstants.tariffPerKwh); // 155,000
    expect(d.serviceCharge, AppConstants.billServiceCharge);
    final expectedVat =
        (d.energyCharge + d.serviceCharge) * AppConstants.billVatRate;
    expect(d.vat, closeTo(expectedVat, 0.001));
    expect(d.total, closeTo(d.energyCharge + d.serviceCharge + d.vat, 0.001));
    // Derived identity fields.
    expect(d.customerName, 'Musa Nziku');
    expect(d.receiptNumber, startsWith('SPT-2026-'));
    expect(d.currentReadingKwh - d.previousReadingKwh, closeTo(310, 0.001));
  });

  test('meter number derives from the Sonoff device id', () {
    final d = BillReport.fromPlugs(
      const [
        Plug(
          id: 'number_01_sonoff_10024a097a_1',
          entityId: 'switch.number_01_sonoff_10024a097a_1',
          name: 'Radio',
          type: ApplianceType.other,
          state: PlugState.on,
        ),
      ],
      dailyKwh: 5,
      now: DateTime(2026, 6, 1),
    );
    expect(d.meterNumber, 'MTR-10024A097A');
  });

  testWidgets('PDF renders to valid, non-empty bytes', (tester) async {
    final d = BillReport.fromPlugs(
      const [],
      dailyKwh: 10,
      now: DateTime(2026, 5, 15),
    );
    final bytes = await BillReport.build(d);
    expect(bytes.lengthInBytes, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF'); // PDF magic
  });
}
