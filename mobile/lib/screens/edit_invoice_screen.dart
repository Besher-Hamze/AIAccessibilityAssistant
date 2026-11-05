import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/product.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class _Line {
  final String productId;
  final String name;
  final double unitPrice;

  /// Highest allowed quantity: what is in stock plus what this invoice already holds.
  final int maxQuantity;
  int quantity;

  _Line({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.maxQuantity,
    required this.quantity,
  });
}

class EditInvoiceScreen extends StatefulWidget {
  final Invoice invoice;

  const EditInvoiceScreen({super.key, required this.invoice});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  late final List<_Line> _lines;
  late final TextEditingController _notes;
  late DateTime _date;
  late String _status;
  bool _saving = false;

  bool get _cancelled => widget.invoice.status == 'CANCELLED';

  double get _total => _lines.fold(0, (sum, l) => sum + l.unitPrice * l.quantity);

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    final products = context.read<DataProvider>().products;
    _lines = invoice.items.map((item) {
      final match = products.where((p) => p.id == item.productId);
      final stock = match.isEmpty ? 0 : match.first.stock;
      return _Line(
        productId: item.productId,
        name: item.productName,
        unitPrice: item.unitPrice,
        maxQuantity: stock + item.quantity,
        quantity: item.quantity,
      );
    }).toList();
    _notes = TextEditingController(text: invoice.notes ?? '');
    _date = invoice.date;
    _status = invoice.status;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'تاريخ الفاتورة',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addProduct() async {
    final used = _lines.map((l) => l.productId).toSet();
    final available = context
        .read<DataProvider>()
        .products
        .where((p) => !used.contains(p.id) && p.stock > 0)
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات أخرى متاحة')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Product>(
      context: context,
      backgroundColor: AppColors.background,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        children: [
          for (final p in available)
            ListTile(
              title: Text(p.name),
              subtitle: Text('${AppFormat.money(p.price)} · متاح ${p.stock}'),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      _lines.add(_Line(
        productId: picked.id,
        name: picked.name,
        unitPrice: picked.price,
        maxQuantity: picked.stock,
        quantity: 1,
      ));
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_lines.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الفاتورة تحتاج منتجاً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<DataProvider>().updateInvoice(widget.invoice.id, {
        if (!_cancelled)
          'items': [
            for (final l in _lines) {'productId': l.productId, 'quantity': l.quantity},
          ],
        'notes': _notes.text.trim(),
        'date': _date.toUtc().toIso8601String(),
        if (_status != widget.invoice.status) 'status': _status,
      });
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تعديل ${widget.invoice.number}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            widget.invoice.customerName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_cancelled)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'الفاتورة ملغاة: لا يمكن تعديل بنودها. غيّر حالتها أولاً.',
                style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
          const Text('المنتجات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          for (final line in _lines)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                        Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${AppFormat.money(line.unitPrice)} · الحد ${line.maxQuantity}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إنقاص',
                    onPressed: !_cancelled && line.quantity > 1
                        ? () => setState(() => line.quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  IconButton(
                    tooltip: 'زيادة',
                    onPressed: !_cancelled && line.quantity < line.maxQuantity
                        ? () => setState(() => line.quantity++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'حذف المنتج',
                    onPressed: _cancelled ? null : () => setState(() => _lines.remove(line)),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                ],
              ),
            ),
          if (!_cancelled)
            OutlinedButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة منتج'),
            ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tileColor: Colors.white,
            leading: const Icon(Icons.event_rounded, color: AppColors.primary),
            title: const Text('التاريخ'),
            trailing: Text(AppFormat.date(_date), style: const TextStyle(fontWeight: FontWeight.w700)),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'الحالة'),
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('معلقة')),
              DropdownMenuItem(value: 'PAID', child: Text('مدفوعة')),
              DropdownMenuItem(value: 'DRAFT', child: Text('مسودة')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('ملغاة')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ التعديلات'),
            ),
          ),
        ],
      ),
    );
  }
}
