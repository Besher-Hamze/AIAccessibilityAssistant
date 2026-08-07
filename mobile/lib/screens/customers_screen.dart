import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

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

  Future<void> _openForm({Customer? customer}) async {
    final isAdmin = context.read<AuthProvider>().user?.isAdmin == true;
    if (customer != null && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التعديل متاح للمدير فقط')),
      );
      return;
    }

    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final email = TextEditingController(text: customer?.email ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  customer == null ? 'إضافة عميل' : 'تعديل عميل',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => v != null && v.trim().length >= 2 ? null : 'اسم مطلوب',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'البريد'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await context.read<DataProvider>().saveCustomer(
                        {
                          'name': name.text.trim(),
                          if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
                          if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
                          if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
                        },
                        id: customer?.id,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin == true;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
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
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.deepTeal.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.mint.withValues(alpha: 0.15),
                                    foregroundColor: AppColors.teal,
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
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal),
                                      ),
                                      const Text('فاتورة', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _openForm(customer: c);
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
