import 'package:intl/intl.dart';

import '../config/constants.dart';

/// Number formatters for power, energy, voltage, currency, and relative time.
/// Centralizes intl usage so widgets stay clean (Handoff §9 utils/formatters).
class Fmt {
  Fmt._();

  static final NumberFormat _whole = NumberFormat('#,##0');
  static final NumberFormat _power0 = NumberFormat('#,##0');
  static final NumberFormat _power1 = NumberFormat('#,##0.0');
  static final NumberFormat _energy2 = NumberFormat('#,##0.00');
  static final NumberFormat _energy1 = NumberFormat('#,##0.0');
  static final NumberFormat _voltage0 = NumberFormat('#,##0');
  static final NumberFormat _amps2 = NumberFormat('0.00');

  /// Watts → "1,047 W" or "12.5 W" depending on magnitude.
  static String power(double? watts) {
    if (watts == null) return '—';
    if (watts.abs() >= 100) return '${_power0.format(watts)} W';
    return '${_power1.format(watts)} W';
  }

  /// Just the numeric portion, used inside large display readouts where the
  /// unit gets its own [Text] for typography alignment.
  static String powerValue(double? watts) {
    if (watts == null) return '—';
    if (watts.abs() >= 100) return _power0.format(watts);
    return _power1.format(watts);
  }

  /// kWh → "18.7 kWh".
  static String energy(double? kwh) {
    if (kwh == null) return '—';
    if (kwh.abs() >= 100) return '${_energy1.format(kwh)} kWh';
    return '${_energy2.format(kwh)} kWh';
  }

  static String energyValue(double? kwh) {
    if (kwh == null) return '—';
    if (kwh.abs() >= 100) return _energy1.format(kwh);
    return _energy2.format(kwh);
  }

  /// Volts → "223 V".
  static String voltage(double? v) =>
      v == null ? '—' : '${_voltage0.format(v)} V';

  /// Amps → "0.85 A".
  static String current(double? a) =>
      a == null ? '—' : '${_amps2.format(a)} A';

  /// Relative time: "12s ago", "5m ago", "2h ago", "Yesterday".
  static String relative(DateTime? then, {DateTime? now}) {
    if (then == null) return '—';
    now ??= DateTime.now();
    final diff = now.difference(then);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  /// A monetary amount → e.g. "TSh 9,350". Currency + rounding are driven by
  /// [AppConstants.currencySymbol]; shillings show no decimals.
  static String money(double amount) =>
      '${AppConstants.currencySymbol} ${_whole.format(amount.round())}';

  /// Estimated cost of [kwh] at the configured tariff → e.g. "TSh 9,350".
  static String cost(double kwh) => money(kwh * AppConstants.tariffPerKwh);

  /// Just the numeric cost (no symbol), for layouts that render the symbol
  /// separately. e.g. 9350.0 → "9,350".
  static String costValue(double kwh) =>
      _whole.format((kwh * AppConstants.tariffPerKwh).round());
}
