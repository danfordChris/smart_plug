import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/constants.dart';

/// Shared styling + building blocks for all Smart Power Technologies PDF
/// documents (bill, consumption report, payment receipt) so they share one
/// letterhead, palette, and table style.
class ReportStyle {
  ReportStyle._();

  static final money = NumberFormat('#,##0');
  static final money2 = NumberFormat('#,##0.00');
  static final kwh1 = NumberFormat('#,##0.0');
  static final date = DateFormat('d MMMM yyyy');

  static final green = PdfColor.fromInt(0xFF1F8A5B);
  static final greenSoft = PdfColor.fromInt(0xFFEAF4EF);
  static final ink = PdfColor.fromInt(0xFF1A1A1A);
  static final muted = PdfColor.fromInt(0xFF6B6B6B);
  static final line = PdfColor.fromInt(0xFFE0E0E0);

  static String sym() => AppConstants.currencySymbol;

  static Future<pw.ImageProvider> loadLogo() async => pw.MemoryImage(
        (await rootBundle.load('assets/bill_logo.png')).buffer.asUint8List(),
      );

  static Future<void> printDoc(pw.Document doc, String name) =>
      Printing.layoutPdf(name: name, onLayout: (_) => doc.save());

  /// Opens the system print/share sheet for already-built PDF [bytes].
  static Future<void> printBytes(Uint8List bytes, String name) =>
      Printing.layoutPdf(name: name, onLayout: (_) => bytes);

  /// Company letterhead: logo + name + address + contacts.
  static pw.Widget header(pw.ImageProvider logo) {
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
                  color: green,
                ),
              ),
              pw.SizedBox(height: 2),
              for (final l in AppConstants.billCompanyAddressLines)
                pw.Text(l, style: pw.TextStyle(fontSize: 9, color: muted)),
              pw.Text(
                'Email: ${AppConstants.billCompanyEmail}    |    Mobile: ${AppConstants.billCompanyPhone}',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget titleBar(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: green,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Center(
        child: pw.Text(
          text.toUpperCase(),
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

  static pw.Widget sectionTitle(String left, [String? right]) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: greenSoft,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              left,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: green,
              ),
            ),
          ),
          if (right != null)
            pw.Text(
              right,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: green,
              ),
            ),
        ],
      ),
    );
  }

  /// Two-column label/value list.
  static pw.Widget kv(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: line, width: 0.5),
        bottom: pw.BorderSide(color: line, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(1.6),
      },
      children: [
        for (final r in rows)
          pw.TableRow(
            children: [
              _cell(r[0], color: muted),
              _cell(r[1], bold: true),
            ],
          ),
      ],
    );
  }

  /// A bordered data table with a green header row.
  static pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Set<int> rightAlign = const {},
    Map<int, pw.FlexColumnWidth>? widths,
  }) {
    pw.Widget hc(String t, int i) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            t,
            textAlign:
                rightAlign.contains(i) ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        );
    return pw.Table(
      border: pw.TableBorder.all(color: line, width: 0.5),
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: green),
          children: [for (var i = 0; i < headers.length; i++) hc(headers[i], i)],
        ),
        for (var r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r.isOdd ? greenSoft : PdfColors.white,
            ),
            children: [
              for (var i = 0; i < rows[r].length; i++)
                _cell(
                  rows[r][i],
                  align:
                      rightAlign.contains(i) ? pw.TextAlign.right : pw.TextAlign.left,
                ),
            ],
          ),
      ],
    );
  }

  static pw.Widget bullets(List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final it in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3, left: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4, right: 6, left: 1),
                  width: 3,
                  height: 3,
                  decoration: pw.BoxDecoration(
                    color: green,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    it,
                    style: pw.TextStyle(fontSize: 10, color: ink, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget paragraph(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.justify,
          style: pw.TextStyle(fontSize: 10, color: ink, height: 1.4),
        ),
      );

  /// A small bar chart drawn from [values] (no external chart deps).
  static pw.Widget barChart(List<double> values, List<String> labels) {
    final max = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b).clamp(0.001, double.infinity);
    return pw.Container(
      height: 90,
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    ReportStyle.kwh1.format(values[i]),
                    style: pw.TextStyle(fontSize: 6.5, color: muted),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    height: (values[i] / max) * 60,
                    margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                    decoration: pw.BoxDecoration(
                      color: green,
                      borderRadius: pw.BorderRadius.vertical(
                        top: pw.Radius.circular(2),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    i < labels.length ? labels[i] : '',
                    style: pw.TextStyle(fontSize: 7, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget footer(String note) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: line),
        pw.Text(note, style: pw.TextStyle(fontSize: 8, color: muted)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Thank you for choosing ${AppConstants.billCompanyName}.',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: color ?? ink,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

/// Converts a non-negative integer amount to English words (for receipts).
String amountInWords(int n) {
  if (n == 0) return 'Zero';
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety',
  ];

  String below1000(int x) {
    final b = StringBuffer();
    if (x >= 100) {
      b.write('${ones[x ~/ 100]} Hundred');
      x %= 100;
      if (x > 0) b.write(' ');
    }
    if (x >= 20) {
      b.write(tens[x ~/ 10]);
      if (x % 10 > 0) b.write('-${ones[x % 10]}');
    } else if (x > 0) {
      b.write(ones[x]);
    }
    return b.toString();
  }

  const scales = [
    [1000000000, 'Billion'],
    [1000000, 'Million'],
    [1000, 'Thousand'],
  ];
  final parts = <String>[];
  var rem = n;
  for (final s in scales) {
    final value = s[0] as int;
    final name = s[1] as String;
    if (rem >= value) {
      parts.add('${below1000(rem ~/ value)} $name');
      rem %= value;
    }
  }
  if (rem > 0) parts.add(below1000(rem));
  return parts.join(' ');
}
