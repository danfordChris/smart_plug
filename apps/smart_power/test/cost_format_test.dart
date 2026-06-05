import 'package:flutter_test/flutter_test.dart';

import 'package:smart_power/config/constants.dart';
import 'package:smart_power/utils/formatters.dart';

void main() {
  group('cost is Tanzanian Shillings, driven by AppConstants', () {
    test('tariff is 500 TSh per kWh', () {
      expect(AppConstants.tariffPerKwh, 500);
      expect(AppConstants.currencySymbol, 'TSh');
    });

    test('Fmt.cost converts kWh at the configured tariff', () {
      expect(Fmt.cost(1), 'TSh 500');
      expect(Fmt.cost(18.7), 'TSh 9,350'); // thousands separator, no decimals
      expect(Fmt.cost(0), 'TSh 0');
    });

    test('Fmt.money formats a shilling amount', () {
      expect(Fmt.money(9350), 'TSh 9,350');
      expect(Fmt.costValue(18.7), '9,350');
    });
  });
}
