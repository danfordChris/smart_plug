import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/constants.dart';
import '../models/plug.dart';

/// Computed figures for one electricity bill.
class BillData {
  final String customerName;
  final String meterNumber;
  final String serviceAddress;
  final String billingPeriod;
  final DateTime issueDate;
  final DateTime dueDate;

  final double previousReadingKwh;
  final double currentReadingKwh;
  final double consumedKwh;
  final double tariffPerKwh;

  final double energyCharge;
  final double serviceCharge;
  final double vat;
  final double penalty;
  final double total;

  final String receiptNumber;
  final String transactionRef;

  const BillData({
    required this.customerName,
    required this.meterNumber,
    required this.serviceAddress,
    required this.billingPeriod,
    required this.issueDate,
    required this.dueDate,
    required this.previousReadingKwh,
    required this.currentReadingKwh,
    required this.consumedKwh,
    required this.tariffPerKwh,
    required this.energyCharge,
    required this.serviceCharge,
    required this.vat,
    required this.penalty,
    required this.total,
    required this.receiptNumber,
    required this.transactionRef,
  });
}

/// Builds and previews the Smart Power Technologies electricity-bill PDF.
class BillReport {
  static final _money = NumberFormat('#,##0');
  static final _kwh = NumberFormat('#,##0');
  static final _date = DateFormat('d MMMM yyyy');
  static final _green = PdfColor.fromInt(0xFF1F8A5B);
  static final _greenSoft = PdfColor.fromInt(0xFFEAF4EF);
  static final _ink = PdfColor.fromInt(0xFF1A1A1A);
  static final _muted = PdfColor.fromInt(0xFF6B6B6B);
  static final _line = PdfColor.fromInt(0xFFE0E0E0);

  static final RegExp _sonoffId = RegExp(r'sonoff_([0-9a-z]+)');

  /// Derives a bill from the current plug list. [dailyKwh] is the dashboard's
  /// whole-home "today" figure; the monthly consumption is estimated from it.
  static BillData fromPlugs(
    List<Plug> plugs, {
    required double dailyKwh,
    String? customerEmail,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;

    final consumed = (dailyKwh.isFinite && dailyKwh > 0)
        ? dailyKwh * daysInMonth
        : 0.0;

    // Cumulative readings: prefer real lifetime totals, else a stable base.
    final lifetime = plugs.fold<double>(
      0,
      (a, p) => a + (p.energyTotalKwh ?? 0),
    );
    final previous = lifetime > consumed ? lifetime - consumed : 12480.0;
    final current = previous + consumed;

    final tariff = AppConstants.tariffPerKwh;
    final energyCharge = consumed * tariff;
    final serviceCharge = AppConstants.billServiceCharge;
    final vat = (energyCharge + serviceCharge) * AppConstants.billVatRate;
    const penalty = 0.0;
    final total = energyCharge + serviceCharge + vat + penalty;

    final stamp = now.millisecondsSinceEpoch;
    final receiptNo =
        '${AppConstants.billReceiptPrefix}-${now.year}-${(stamp % 1000000).toString().padLeft(6, '0')}';
    final txnRef = 'TXN-${(stamp % 10000000000).toString().padLeft(10, '0')}';

    return BillData(
      customerName: _nameFrom(customerEmail),
      meterNumber: _meterFrom(plugs),
      serviceAddress: AppConstants.billServiceAddress,
      billingPeriod: '${_date.format(firstDay)} - ${_date.format(lastDay)}',
      issueDate: now,
      dueDate: now.add(const Duration(days: 15)),
      previousReadingKwh: previous,
      currentReadingKwh: current,
      consumedKwh: consumed,
      tariffPerKwh: tariff,
      energyCharge: energyCharge,
      serviceCharge: serviceCharge,
      vat: vat,
      penalty: penalty,
      total: total,
      receiptNumber: receiptNo,
      transactionRef: txnRef,
    );
  }

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

  /// Generates the PDF for [data] and opens the system print/share sheet
  /// (save as PDF, AirDrop, email, etc.).
  static Future<void> download(BillData data) async {
    await Printing.layoutPdf(
      name: 'SmartPower-Bill-${data.receiptNumber}.pdf',
      onLayout: (format) => build(data),
    );
  }

  /// Convenience: compute from plugs and download in one call.
  static Future<void> open(
    List<Plug> plugs, {
    required double dailyKwh,
    String? customerEmail,
  }) =>
      download(fromPlugs(plugs, dailyKwh: dailyKwh, customerEmail: customerEmail));

  static Future<Uint8List> build(BillData d) async {
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/bill_logo.png')).buffer.asUint8List(),
    );
    final sym = AppConstants.currencySymbol;
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(d, logo),
            pw.SizedBox(height: 14),
            _titleBar(),
            pw.SizedBox(height: 14),
            _sectionTitle('Customer Information'),
            _kv([
              ['Customer Name', d.customerName],
              ['Meter Number', d.meterNumber],
              ['Service Address', d.serviceAddress],
              ['Billing Period', d.billingPeriod],
              ['Bill Issue Date', _date.format(d.issueDate)],
              ['Due Date', _date.format(d.dueDate)],
            ]),
            pw.SizedBox(height: 14),
            _sectionTitle('Consumption Details', 'Value'),
            _kv([
              ['Previous Meter Reading', '${_kwh.format(d.previousReadingKwh)} kWh'],
              ['Current Meter Reading', '${_kwh.format(d.currentReadingKwh)} kWh'],
              ['Total Energy Consumed', '${_kwh.format(d.consumedKwh)} kWh'],
              ['Tariff Rate', '$sym ${_money.format(d.tariffPerKwh)} per kWh'],
            ]),
            pw.SizedBox(height: 14),
            _sectionTitle('Billing Summary', 'Amount ($sym)'),
            _amounts(d, sym),
            pw.SizedBox(height: 14),
            _sectionTitle('Payment Information'),
            _kv([
              ['Payment Status', 'Pending'],
              ['Accepted Payment Method', 'Mobile Money, Bank Transfer'],
              ['Receipt Number', d.receiptNumber],
              ['Transaction Reference', d.transactionRef],
            ]),
            pw.Spacer(),
            _footer(),
          ],
        ),
      ),
    );
    return doc.save();
  }

  // ── building blocks ──────────────────────────────────────────────────

  static pw.Widget _header(BillData d, pw.ImageProvider logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 58, width: 58, child: pw.Image(logo)),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.billCompanyName,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: _green,
                ),
              ),
              pw.SizedBox(height: 2),
              for (final line in AppConstants.billCompanyAddressLines)
                pw.Text(line, style: pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(
                'Email: ${AppConstants.billCompanyEmail}    |    Mobile: ${AppConstants.billCompanyPhone}',
                style: pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _titleBar() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: _green,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text(
          'ELECTRICITY BILL RECEIPT',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String left, [String? right]) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: _greenSoft,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              left,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
          ),
          if (right != null)
            pw.Text(
              right,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _kv(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.6),
      },
      children: [
        for (final r in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: pw.Text(
                  r[0],
                  style: pw.TextStyle(fontSize: 10, color: _muted),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                child: pw.Text(
                  r[1],
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _ink,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _amounts(BillData d, String sym) {
    pw.TableRow row(String label, double amount, {bool emphasize = false}) {
      final style = pw.TextStyle(
        fontSize: emphasize ? 12 : 10,
        color: emphasize ? _green : _ink,
        fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.TableRow(
        decoration: emphasize ? pw.BoxDecoration(color: _greenSoft) : null,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(label, style: style),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              _money.format(amount),
              textAlign: pw.TextAlign.right,
              style: style,
            ),
          ),
        ],
      );
    }

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(1.0),
      },
      children: [
        row('Energy Consumption Charges', d.energyCharge),
        row('Service Charge', d.serviceCharge),
        row('VAT (${(AppConstants.billVatRate * 100).round()}%)', d.vat),
        row('Late Payment Penalty', d.penalty),
        row('Total Amount Due', d.total, emphasize: true),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: _line),
        pw.Text(
          'This is a system-generated estimate based on live meter data from Plug Assistance.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Thank you for choosing ${AppConstants.billCompanyName}.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    );
  }
}
