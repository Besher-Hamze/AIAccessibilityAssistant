import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'customer_detail_screen.dart';

/// Best customers and products, who still owes money, sales per month.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  late final NavigationProvider _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavigationProvider>();
    _nav.subpageReader = _spoken;
    _load();
  }

  @override
  void dispose() {
    _nav.subpageReader = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<DataProvider>().api.getInsights();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<Map<String, dynamic>> _rows(String key) =>
      ((_data?[key] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

  String _spoken() {
    if (_data == null) return 'التحليلات قيد التحميل.';
    final top = _rows('topCustomers').take(3).map((c) => c['name']).join('، ');
    final owing = _rows('balances').take(3).map((c) => c['name']).join('، ');
    return 'صفحة التحليلات.'
        '${top.isEmpty ? '' : ' أفضل العملاء: $top.'}'
        '${owing.isEmpty ? '' : ' عليهم مبالغ معلقة: $owing.'}';
  }

  void _openCustomer(String id) => _nav.push(CustomerDetailScreen(customerId: id));

  static num _num(dynamic v) => num.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحليلات')),
      body: _data == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _Section(
                    title: 'المبيعات شهرياً',
                    empty: 'لا توجد مبيعات بعد',
                    rows: [
                      for (final m in _rows('sales').reversed)
                        _Row(
                          title: '${m['month']}',
                          subtitle: '${m['invoices']} فاتورة',
                          value: AppFormat.money(_num(m['amount'])),
                        ),
                    ],
                  ),
                  _Section(
                    title: 'عليهم مبالغ معلقة',
                    empty: 'لا توجد مبالغ معلقة',
                    rows: [
                      for (final c in _rows('balances'))
                        _Row(
                          title: '${c['name']}',
                          subtitle: '${c['invoices']} فاتورة معلقة',
                          value: AppFormat.money(_num(c['amount'])),
                          color: AppColors.warning,
                          onTap: () => _openCustomer('${c['customerId']}'),
                        ),
                    ],
                  ),
                  _Section(
                    title: 'أفضل العملاء',
                    empty: 'لا توجد مبيعات بعد',
                    rows: [
                      for (final c in _rows('topCustomers'))
                        _Row(
                          title: '${c['name']}',
                          subtitle: '${c['invoices']} فاتورة',
                          value: AppFormat.money(_num(c['amount'])),
                          onTap: () => _openCustomer('${c['customerId']}'),
                        ),
                    ],
                  ),
                  _Section(
                    title: 'أكثر المنتجات مبيعاً',
                    empty: 'لا توجد مبيعات بعد',
                    rows: [
                      for (final p in _rows('topProducts'))
                        _Row(
                          title: '${p['name']}',
                          subtitle: '${p['quantity']} قطعة',
                          value: AppFormat.money(_num(p['amount'])),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String empty;
  final List<_Row> rows;

  const _Section({required this.title, required this.empty, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(empty, style: const TextStyle(color: AppColors.muted))
          else
            ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _Row({
    required this.title,
    required this.subtitle,
    required this.value,
    this.color = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                if (onTap != null) const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
