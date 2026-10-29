import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/report_pdf_helper.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  Future<void> _showDetails(Invoice invoice) async {
    final data = context.read<DataProvider>();
    final isAdmin = context.read<AuthProvider>().user?.isAdmin == true;
    Invoice full;
    try {
      full = await data.api.getInvoice(invoice.id);
    } catch (_) {
      full = invoice;
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Text(full.number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    StatusBadge(status: full.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(full.customerName, style: const TextStyle(color: AppColors.muted)),
                Text(AppFormat.date(full.date), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                if (full.notes != null) ...[
                  const SizedBox(height: 8),
                  Text('ملاحظة: ${full.notes}'),
                ],
                const SizedBox(height: 16),
                const Text('البنود', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...full.items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text('${item.quantity} × ${AppFormat.money(item.unitPrice)}'),
                    trailing: Text(AppFormat.money(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(AppFormat.money(full.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
                if (isAdmin && full.status != 'CANCELLED') ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (full.status != 'PAID')
                        FilledButton(
                          onPressed: () async {
                            await data.setInvoiceStatus(full.id, 'PAID');
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('تعليمفع'),
                        ),
                      if (full.status != 'PENDING')
                        OutlinedButton(
                          onPressed: () async {
                            await data.setInvoiceStatus(full.id, 'PENDING');
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('تعليق'),
                        ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () async {
                          await data.setInvoiceStatus(full.id, 'CANCELLED');
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('إلغاء'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'pdf',
            backgroundColor: AppColors.primary,
            onPressed: () => generateAndOpenInvoiceReportPdf(
                  context,
                  status: data.invoiceFilter,
                ),
            child: const Icon(Icons.picture_as_pdf_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('فاتورة جديدة'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: data.invoiceFilter == null,
                  onTap: () {
                    data.setInvoiceFilter(null);
                  },
                ),
                _FilterChip(
                  label: 'مدفوعة',
                  selected: data.invoiceFilter == 'PAID',
                  onTap: () {
                    data.setInvoiceFilter('PAID');
                  },
                ),
                _FilterChip(
                  label: 'معلقة',
                  selected: data.invoiceFilter == 'PENDING',
                  onTap: () {
                    data.setInvoiceFilter('PENDING');
                  },
                ),
                _FilterChip(
                  label: 'مسودة',
                  selected: data.invoiceFilter == 'DRAFT',
                  onTap: () {
                    data.setInvoiceFilter('DRAFT');
                  },
                ),
                _FilterChip(
                  label: 'ملغاة',
                  selected: data.invoiceFilter == 'CANCELLED',
                  onTap: () {
                    data.setInvoiceFilter('CANCELLED');
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: data.loadInvoices,
              child: data.loadingInvoices && data.invoices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : data.invoices.isEmpty
                      ? const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'لا توجد فواتير',
                          subtitle: 'أنشئ فاتورة جديدة أو اطلب من المساعد إنشاؤها',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: data.invoices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final inv = data.invoices[index];
                            return InkWell(
                              onTap: () => _showDetails(inv),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.rose.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.receipt_rounded, color: AppColors.rose),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w800)),
                                          Text(inv.customerName, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                          Text(AppFormat.date(inv.date), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(AppFormat.money(inv.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 6),
                                        StatusBadge(status: inv.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accent.withValues(alpha: 0.25),
      ),
    );
  }
}
