import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/models/plug.dart';
import 'package:smart_power/services/bill_pdf.dart';
import 'package:smart_power/services/consumption_report.dart';
import 'package:smart_power/services/payment_receipt.dart';
import 'package:smart_power/services/report_common.dart';

const _plug = Plug(
  id: 'number_01_sonoff_10024a097a_1',
  entityId: 'switch.number_01_sonoff_10024a097a_1',
  name: 'Fridge',
  type: ApplianceType.fridge,
  state: PlugState.on,
  powerW: 120,
  energyTodayKwh: 1.4,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('amountInWords', () {
    test('matches the receipt sample', () {
      expect(
        amountInWords(257140),
        'Two Hundred Fifty-Seven Thousand One Hundred Forty',
      );
      expect(amountInWords(0), 'Zero');
      expect(amountInWords(5000), 'Five Thousand');
    });
  });

  group('ConsumptionReport', () {
    test('totals, appliance rows, and stats derive from plugs', () {
      final d = ConsumptionReport.fromPlugs(
        const [_plug],
        dailyKwh: 10, // whole-home daily
        customerEmail: 'musa.nziku@home.test',
        now: DateTime(2026, 5, 15), // 31 days
      );
      expect(d.totalEnergyKwh, 10 * 31);
      expect(d.totalCostTsh, 10 * 31 * 500);
      // 1 monitored plug + 1 "Other household load" row (baseline > 0).
      expect(d.appliances.length, 2);
      expect(d.appliances.first.name, 'Fridge');
      expect(d.appliances.any((a) => a.name == 'Other household load'), isTrue);
      expect(d.totalAppliances, 1); // monitored plugs
      expect(d.customerName, 'Musa Nziku');
      expect(d.meterNumber, 'MTR-10024A097A');
      expect(d.trend.length, 7);
    });

    testWidgets('builds a valid PDF', (tester) async {
      final d = ConsumptionReport.fromPlugs(
        const [_plug],
        dailyKwh: 10,
        now: DateTime(2026, 5, 15),
      );
      final bytes = await ConsumptionReport.build(d);
      expect(bytes.lengthInBytes, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });

  group('PaymentReceipt', () {
    test('derives from a bill', () {
      final bill = BillReport.fromPlugs(
        const [],
        dailyKwh: 10,
        customerEmail: 'musa.nziku@home.test',
        now: DateTime(2026, 5, 15),
      );
      final p = PaymentReceipt.fromBill(bill, now: DateTime(2026, 5, 15));
      expect(p.receivedFrom, 'Musa Nziku');
      expect(p.paidAmount, bill.total);
      expect(p.totalPaid, bill.total);
      expect(p.amountInWordsText, endsWith('Shillings Only'));
      expect(p.billReference, startsWith('A'));
    });

    testWidgets('builds a valid PDF', (tester) async {
      final bill = BillReport.fromPlugs(
        const [],
        dailyKwh: 10,
        now: DateTime(2026, 5, 15),
      );
      final bytes = await PaymentReceipt.build(
        PaymentReceipt.fromBill(bill, now: DateTime(2026, 5, 15)),
      );
      expect(bytes.lengthInBytes, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}
