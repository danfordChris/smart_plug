import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/plug.dart';
import '../services/bill_pdf.dart';
import '../services/consumption_report.dart';
import '../services/payment_receipt.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart' show AppSnack;

/// Bottom sheet that summarises the period and offers the three Smart Power
/// Technologies documents as downloadable PDFs. Opened from the dashboard
/// "View report" button.
class BillSummarySheet extends StatefulWidget {
  final List<Plug> plugs;
  final double dailyKwh;
  final String? customerEmail;

  const BillSummarySheet({
    super.key,
    required this.plugs,
    required this.dailyKwh,
    this.customerEmail,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Plug> plugs,
    required double dailyKwh,
    String? customerEmail,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      builder: (_) => BillSummarySheet(
        plugs: plugs,
        dailyKwh: dailyKwh,
        customerEmail: customerEmail,
      ),
    );
  }

  @override
  State<BillSummarySheet> createState() => _BillSummarySheetState();
}

class _BillSummarySheetState extends State<BillSummarySheet> {
  late final BillData _bill;
  late final ConsumptionData _consumption;
  String? _busy; // key of the doc currently generating

  @override
  void initState() {
    super.initState();
    _bill = BillReport.fromPlugs(
      widget.plugs,
      dailyKwh: widget.dailyKwh,
      customerEmail: widget.customerEmail,
    );
    _consumption = ConsumptionReport.fromPlugs(
      widget.plugs,
      dailyKwh: widget.dailyKwh,
      customerEmail: widget.customerEmail,
    );
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (_) {
      if (mounted) AppSnack.info(context, "Couldn't generate the PDF");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.m,
            AppSpacing.xxl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              // Header
              Row(
                children: [
                  _glyph(scheme, AppIcons.document),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 20),
                        ),
                        Text(
                          _bill.billingPeriod,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),

              // Summary hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(
                        context,
                        'CONSUMED',
                        '${Fmt.energyValue(_consumption.totalEnergyKwh)} kWh',
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        context,
                        'AMOUNT DUE',
                        Fmt.money(_bill.total),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),

              Text(
                'DOCUMENTS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
              ),
              const SizedBox(height: AppSpacing.s),

              _docTile(
                context,
                key: 'consumption',
                icon: AppIcons.insights,
                title: 'Consumption Report',
                subtitle: 'Appliance breakdown · trend · recommendations',
                onTap: () => _run(
                  'consumption',
                  () => ConsumptionReport.download(_consumption),
                ),
              ),
              _docTile(
                context,
                key: 'bill',
                icon: AppIcons.document,
                title: 'Electricity Bill',
                subtitle: '${Fmt.money(_bill.total)} due · VAT incl.',
                onTap: () => _run('bill', () => BillReport.download(_bill)),
              ),
              _docTile(
                context,
                key: 'receipt',
                icon: AppIcons.check,
                title: 'Payment Receipt',
                subtitle: 'Proof of payment for this bill',
                onTap: () => _run(
                  'receipt',
                  () => PaymentReceipt.download(
                    PaymentReceipt.fromBill(_bill),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.m),
              Center(
                child: Text(
                  'Estimates from live meter data · ${AppConstants.billCompanyName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glyph(ColorScheme scheme, dynamic icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: HugeIcon(icon: icon, size: 22, color: scheme.onPrimaryContainer),
        ),
      );

  Widget _stat(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontSize: 20, color: scheme.onSurface),
        ),
      ],
    );
  }

  Widget _docTile(
    BuildContext context, {
    required String key,
    required dynamic icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busy == key;
    final disabled = _busy != null && !busy;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: (busy || disabled) ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 22,
                  color: disabled ? scheme.outline : scheme.primary,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : HugeIcon(
                        icon: AppIcons.download,
                        size: 20,
                        color: disabled ? scheme.outline : scheme.onSurface,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
