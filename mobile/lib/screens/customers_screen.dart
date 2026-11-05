import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/customer_form.dart';
import '../widgets/empty_state.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin == true;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCustomerForm(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('عميل جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    _search.clear();
                    data.loadCustomers();
                  },
                  icon: const Icon(Icons.clear_rounded),
                ),
              ),
              onSubmitted: (v) => data.loadCustomers(search: v.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => data.loadCustomers(search: _search.text.trim()),
              child: data.loadingCustomers && data.customers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : data.customers.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline,
                          title: 'لا يوجد عملاء',
                          subtitle: 'أضف عميلاً جديداً أو استخدم المساعد الصوتي',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: data.customers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = data.customers[index];
                            return Material(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: AppColors.navy.withValues(alpha: 0.06)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                              onTap: () => context
                                  .read<NavigationProvider>()
                                  .push(CustomerDetailScreen(customerId: c.id)),
                              child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                    foregroundColor: AppColors.primary,
                                    child: Text(
                                      c.name.isNotEmpty ? c.name.characters.first : '؟',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        if (c.phone != null)
                                          Text(c.phone!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                        if (c.address != null)
                                          Text(c.address!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${c.invoicesCount}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                      const Text('فاتورة', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await showCustomerForm(context, customer: c);
                                      } else if (value == 'delete' && isAdmin) {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('حذف العميل؟'),
                                            content: Text('سيتم حذف ${c.name} وكل فواتيره.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                                            ],
                                          ),
                                        );
                                        if (ok == true && context.mounted) {
                                          try {
                                            await data.removeCustomer(c.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                      if (isAdmin) const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                    ],
                                  ),
                                ],
                              ),
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
