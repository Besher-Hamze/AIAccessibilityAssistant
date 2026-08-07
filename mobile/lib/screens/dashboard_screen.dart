import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onOpenChat;

  const DashboardScreen({super.key, required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final data = context.watch<DataProvider>();
    final s = data.summary;

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: data.loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.deepTeal, AppColors.teal],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، ${auth.user?.name ?? ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  auth.user?.isAdmin == true
                      ? 'مدير النظام — تحكم كامل بالعمليات'
                      : 'مستخدم — بحث وإنشاء فواتير وعملاء',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('تحدث مع المساعد'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (data.loadingSummary && s == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    title: 'الفواتير',
                    value: '${s?['totalInvoices'] ?? 0}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    title: 'العملاء',
                    value: '${s?['customersCount'] ?? 0}',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    title: 'المنتجات',
                    value: '${s?['productsCount'] ?? 0}',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    title: 'معلقة',
                    value: '${s?['pendingCount'] ?? 0}',
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MoneyTile(
                    title: 'المبلغ المدفوع',
                    value: AppFormat.money(
                      num.tryParse('${s?['paidAmount'] ?? 0}') ?? 0,
                    ),
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyTile(
                    title: 'المبلغ المعلق',
                    value: AppFormat.money(
                      num.tryParse('${s?['pendingAmount'] ?? 0}') ?? 0,
                    ),
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'أوامر سريعة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'اعرض قائمة المنتجات',
              'ما ملخص المحاسبة؟',
              'اعرض فواتير محمد',
              'أنشئ تقريراً عن الفواتير المعلقة',
            ].map((cmd) {
              return ActionChip(
                avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.teal),
                label: Text(cmd),
                onPressed: () async {
                  onOpenChat();
                  await Future.delayed(const Duration(milliseconds: 250));
                  if (!context.mounted) return;
                  final mutated =
                      await context.read<ChatProvider>().sendTextMessage(cmd);
                  if (mutated && context.mounted) {
                    await context.read<DataProvider>().loadAll();
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'آخر الفواتير',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('تحديث', style: TextStyle(color: AppColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (s?['recentInvoices'] is List && (s!['recentInvoices'] as List).isNotEmpty)
            ...((s['recentInvoices'] as List).map((raw) {
              final inv = raw as Map<String, dynamic>;
              final customer = inv['customer'] as Map<String, dynamic>?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.deepTeal.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_rounded, color: AppColors.teal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv['number']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            customer?['name']?.toString() ?? '',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormat.money(num.tryParse('${inv['total']}') ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        StatusBadge(status: inv['status']?.toString() ?? 'PENDING'),
                      ],
                    ),
                  ],
                ),
              );
            }))
          else
            const Text('لا توجد فواتير حديثة', style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.deepTeal.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MoneyTile({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
