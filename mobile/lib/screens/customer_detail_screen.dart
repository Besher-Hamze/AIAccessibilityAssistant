import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer_account.dart';
import '../models/invoice.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/report_pdf_helper.dart';
import '../widgets/customer_form.dart';
import '../widgets/status_badge.dart';
import 'create_invoice_screen.dart';
import 'edit_invoice_screen.dart';

/// A customer's page: their invoices one by one, what they bought, the totals.
class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  CustomerAccount? _account;
  String? _error;
  String? _statusFilter;
  late final NavigationProvider _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavigationProvider>();
    _nav.subpageReader = () => _account?.spokenSummary ?? 'صفحة العميل قيد التحميل.';
    _load();
  }

  @override
  void dispose() {
    _nav.subpageReader = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final account = await context
          .read<DataProvider>()
          .api
          .getCustomerAccount(widget.customerId);
      if (!mounted) return;
      setState(() {
        _account = account;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _editCustomer() async {
    final account = _account;
    if (account == null) return;
    if (await showCustomerForm(context, customer: account.customer)) await _load();
  }

  Future<void> _newInvoice() async {
    await _nav.push(CreateInvoiceScreen(initialCustomerId: widget.customerId));
    if (mounted) await _load();
  }

  Future<void> _editInvoice(Invoice invoice) async {
    await _nav.push(EditInvoiceScreen(invoice: invoice));
    if (mounted) await _load();
  }

  Future<void> _markPaid(Invoice invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<DataProvider>().setInvoiceStatus(invoice.id, 'PAID');
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(account?.customer.name ?? 'العميل'),
        actions: [
          if (account != null)
            IconButton(
              tooltip: 'كشف حساب PDF',
              onPressed: () => generateAndOpenInvoiceReportPdf(
                context,
                customerName: account.customer.name,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (account != null && isAdmin)
            IconButton(
              tooltip: 'تعديل بيانات العميل',
              onPressed: _editCustomer,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: account == null
          ? _error == null
              ? const Center(child: CircularProgressIndicator())
              : _LoadError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _Header(account: account),
                  const SizedBox(height: 12),
                  _Totals(account: account),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _newInvoice,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('فاتورة جديدة لهذا العميل'),
                  ),
                  if (account.products.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _Title('المنتجات التي اشتراها'),
                    const SizedBox(height: 8),
                    ...account.products.map((p) => _ProductRow(product: p)),
                  ],
                  const SizedBox(height: 20),
                  _Title('الفواتير (${account.invoiceCount})'),
                  const SizedBox(height: 8),
                  _StatusFilter(
                    counts: account.counts,
                    selected: _statusFilter,
                    onChanged: (s) => setState(() => _statusFilter = s),
                  ),
                  const SizedBox(height: 8),
                  ..._visibleInvoices(account).map(
                    (inv) => _InvoiceCard(
                      invoice: inv,
                      canEdit: isAdmin,
                      onEdit: () => _editInvoice(inv),
                      onMarkPaid: () => _markPaid(inv),
                    ),
                  ),
                  if (_visibleInvoices(account).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد فواتير هنا',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Invoice> _visibleInvoices(CustomerAccount account) => _statusFilter == null
      ? account.invoices
      : account.invoices.where((i) => i.status == _statusFilter).toList();
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }
}

class _Header extends StatelessWidget {
  final CustomerAccount account;
  const _Header({required this.account});

  @override
  Widget build(BuildContext context) {
    final c = account.customer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              c.name.isNotEmpty ? c.name.characters.first : '؟',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                for (final line in [c.phone, c.email, c.address])
                  if (line != null && line.isNotEmpty)
                    Text(line, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  final CustomerAccount account;
  const _Totals({required this.account});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return GridView(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 700 ? 4 : 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 84,
      ),
      children: [
        _Tile('الإجمالي', AppFormat.money(account.totalAmount), AppColors.primary),
        _Tile('المدفوع', AppFormat.money(account.paidAmount), AppColors.success),
        _Tile('المعلق', AppFormat.money(account.pendingAmount), AppColors.warning),
        _Tile('القطع المشتراة', '${account.totalUnits}', AppColors.accent),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _Tile(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final CustomerProduct product;
  const _ProductRow({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: AppColors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (product.lastDate != null)
                  Text(
                    'آخر شراء ${AppFormat.date(product.lastDate!)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${product.quantity} قطعة', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                AppFormat.money(product.amount),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _StatusFilter({required this.counts, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {'PAID': 'مدفوعة', 'PENDING': 'معلقة', 'DRAFT': 'مسودة', 'CANCELLED': 'ملغاة'};
    return Wrap(
      spacing: 6,
      children: [
        ChoiceChip(
          label: const Text('الكل'),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final e in labels.entries)
          if ((counts[e.key] ?? 0) > 0)
            ChoiceChip(
              label: Text('${e.value} ${counts[e.key]}'),
              selected: selected == e.key,
              onSelected: (_) => onChanged(e.key),
            ),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;

  const _InvoiceCard({
    required this.invoice,
    required this.canEdit,
    required this.onEdit,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      AppFormat.date(invoice.date),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: invoice.status),
            ],
          ),
          const Divider(height: 18),
          for (final item in invoice.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.productName} × ${item.quantity}'),
                  ),
                  Text(AppFormat.money(item.subtotal)),
                ],
              ),
            ),
          if (invoice.notes != null && invoice.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ملاحظة: ${invoice.notes}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('المجموع', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                AppFormat.money(invoice.total),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
              ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('تعديل'),
                  ),
                ),
                if (invoice.status == 'PENDING' || invoice.status == 'DRAFT') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.success),
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('مدفوعة'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
