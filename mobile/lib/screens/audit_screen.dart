import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await context.read<AuthProvider>().apiService.getAuditLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _actionAr(String action) {
    return switch (action) {
      'create_invoice' => 'إنشاء فاتورة',
      'create_customer' => 'إضافة عميل',
      'create_product' => 'إضافة منتج',
      'update_invoice_status' => 'تغيير حالة فاتورة',
      'update_product_stock' => 'تحديث مخزون',
      'update_customer' => 'تعديل عميل',
      'generate_report' => 'إنشاء تقرير',
      'list_products' => 'عرض منتجات',
      'search_invoices' => 'بحث فواتير',
      'get_customer_invoices' => 'فواتير عميل',
      'get_accounting_summary' => 'ملخص محاسبة',
      'search_customers' => 'بحث عملاء',
      'get_latest_invoice' => 'آخر فاتورة',
      _ => action,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل العمليات'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                : _logs.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'لا يوجد سجل بعد',
                        subtitle: 'ستظهر هنا عمليات المساعد الذكي',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final user = log['user'] as Map<String, dynamic>?;
                            final date = DateTime.tryParse(log['createdAt']?.toString() ?? '');
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.rose.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.bolt_rounded, color: AppColors.rose),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _actionAr(log['action']?.toString() ?? ''),
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          user?['name']?.toString() ?? 'مستخدم',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        ),
                                        if (date != null)
                                          Text(
                                            AppFormat.date(date),
                                            style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
