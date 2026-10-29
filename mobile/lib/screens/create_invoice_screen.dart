import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  Customer? _customer;
  final Map<String, int> _quantities = {};
  final _notes = TextEditingController();
  String _status = 'PENDING';
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  double get _total {
    final products = context.read<DataProvider>().products;
    double sum = 0;
    for (final entry in _quantities.entries) {
      final matches = products.where((e) => e.id == entry.key);
      if (matches.isNotEmpty) sum += matches.first.price * entry.value;
    }
    return sum;
  }

  Future<void> _save() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عميلاً')),
      );
      return;
    }
    final items = _quantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'productId': e.key, 'quantity': e.value})
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف منتجاً واحداً على الأقل')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<DataProvider>().createInvoice({
        'customerId': _customer!.id,
        'items': items,
        'status': _status,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء الفاتورة')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('فاتورة جديدة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Customer>(
              initialValue: _customer,
              decoration: const InputDecoration(labelText: 'العميل'),
              items: data.customers
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _customer = v),
            ),
            const SizedBox(height: 16),
            const Text('المنتجات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            ...data.products.map((Product p) {
              final qty = _quantities[p.id] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${AppFormat.money(p.price)} · متاح ${p.stock}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: qty > 0
                          ? () => setState(() {
                                _quantities[p.id] = qty - 1;
                                if (_quantities[p.id] == 0) _quantities.remove(p.id);
                              })
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: qty < p.stock
                          ? () => setState(() => _quantities[p.id] = qty + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: const [
                DropdownMenuItem(value: 'PENDING', child: Text('معلقة')),
                DropdownMenuItem(value: 'PAID', child: Text('مدفوعة')),
                DropdownMenuItem(value: 'DRAFT', child: Text('مسودة')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'PENDING'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    AppFormat.money(_total),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('إنشاء الفاتورة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
