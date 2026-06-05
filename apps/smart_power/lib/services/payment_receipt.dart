import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bill_pdf.dart';
import 'report_common.dart';

/// "Payment Receipt" issued against a paid bill.
class PaymentData {
  final String receiptNo;
  final String receivedFrom;
  final double paidAmount;
  final String amountInWordsText;
  final String itemDescription;
  final double totalPaid;
  final String billReference;
  final DateTime paymentDate;
  final String issuedBy;
  final DateTime dateIssued;

  const PaymentData({
    required this.receiptNo,
    required this.receivedFrom,
    required this.paidAmount,
    required this.amountInWordsText,
    required this.itemDescription,
    required this.totalPaid,
    required this.billReference,
    required this.paymentDate,
    required this.issuedBy,
    required this.dateIssued,
  });
}

class PaymentReceipt {
  static PaymentData fromBill(BillData bill, {DateTime? now}) {
    now ??= DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    final receiptNo = (stamp % 1000000000000000).toString().padLeft(15, '0');
    final billRef = 'A${(stamp % 100000000000).toString().padLeft(11, '0')}';
    final words = '${amountInWords(bill.total.round())} Shillings Only';
    return PaymentData(
      receiptNo: receiptNo,
      receivedFrom: bill.customerName,
      paidAmount: bill.total,
      amountInWordsText: words,
      itemDescription: 'Electricity Bill',
      totalPaid: bill.total,
      billReference: billRef,
      paymentDate: now,
      issuedBy: 'Accountant Office',
      dateIssued: now.add(const Duration(days: 2)),
    );
  }

  static Future<Uint8List> build(PaymentData d) async {
    final logo = await ReportStyle.loadLogo();
    final sym = ReportStyle.sym();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            ReportStyle.header(logo),
            pw.SizedBox(height: 14),
            ReportStyle.titleBar('Payment Receipt'),
            ReportStyle.sectionTitle('Payment Details'),
            ReportStyle.kv([
              ['Receipt No', d.receiptNo],
              ['Received From', d.receivedFrom],
              ['Paid Amount', '$sym ${ReportStyle.money2.format(d.paidAmount)}'],
              ['Amount in Words', d.amountInWordsText],
            ]),
            ReportStyle.sectionTitle('In Respect Of'),
            ReportStyle.table(
              ['Item Description', 'Item Amount ($sym)'],
              [
                [d.itemDescription, ReportStyle.money2.format(d.paidAmount)],
                ['Total Amount Paid', ReportStyle.money2.format(d.totalPaid)],
              ],
              rightAlign: {1},
              widths: {
                0: const pw.FlexColumnWidth(2.4),
                1: const pw.FlexColumnWidth(1),
              },
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Bill Reference: ${d.billReference}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: ReportStyle.ink,
              ),
            ),
            ReportStyle.sectionTitle('Authorisation'),
            ReportStyle.kv([
              ['Payment Date', ReportStyle.date.format(d.paymentDate)],
              ['Issued By', d.issuedBy],
              ['Date Issued', ReportStyle.date.format(d.dateIssued)],
            ]),
            pw.Spacer(),
            ReportStyle.footer(
              'Computer-generated receipt - valid without a signature.',
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> download(PaymentData d) async =>
      ReportStyle.printBytes(await build(d), 'SmartPower-Receipt-${d.receiptNo}.pdf');
}
