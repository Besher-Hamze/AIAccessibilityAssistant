import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/empty_state.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm({Product? product}) async {
    final isAdmin = context.read<AuthProvider>().user?.isAdmin == true;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إدارة المنتجات متاحة للمدير فقط')),
      );
      return;
    }

    final name = TextEditingController(text: product?.name ?? '');
    final desc = TextEditingController(text: product?.description ?? '');
    final price = TextEditingController(text: product?.price.toString() ?? '');
    final stock = TextEditingController(text: product?.stock.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
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
                  product == null ? 'إضافة منتج' : 'تعديل منتج',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                  validator: (v) => v != null && v.trim().length >= 2 ? null : 'اسم مطلوب',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'السعر'),
                  keyboardType: TextInputType.number,
                  validator: (v) => double.tryParse(v ?? '') != null ? null : 'سعر غير صالح',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: stock,
                  decoration: const InputDecoration(labelText: 'المخزون'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') != null ? null : 'مخزون غير صالح',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await context.read<DataProvider>().saveProduct(
                        {
                          'name': name.text.trim(),
                          if (desc.text.trim().isNotEmpty) 'description': desc.text.trim(),
                          'price': double.parse(price.text.trim()),
                          'stock': int.parse(stock.text.trim()),
                        },
                        id: product?.id,
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
        const SnackBar(content: Text('تم حفظ المنتج')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin == true;

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('منتج جديد'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث عن منتج...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    _search.clear();
                    data.loadProducts();
                  },
                  icon: const Icon(Icons.clear_rounded),
                ),
              ),
              onSubmitted: (v) => data.loadProducts(search: v.trim()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => data.loadProducts(search: _search.text.trim()),
              child: data.loadingProducts && data.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : data.products.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'لا توجد منتجات',
                          subtitle: 'أضف منتجات لبدء إنشاء الفواتير',
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: data.products.length,
                          itemBuilder: (context, index) {
                            final p = data.products[index];
                            return InkWell(
                              onTap: isAdmin ? () => _openForm(product: p) : null,
                              onLongPress: isAdmin
                                  ? () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('حذف المنتج؟'),
                                          content: Text(p.name),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
                                          ],
                                        ),
                                      );
                                      if (ok == true && context.mounted) {
                                        try {
                                          await data.removeProduct(p.id);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                            );
                                          }
                                        }
                                      }
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.navy.withValues(alpha: 0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.amber.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.inventory_2_rounded, color: AppColors.amber, size: 20),
                                    ),
                                    const Spacer(),
                                    Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppFormat.money(p.price),
                                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: p.outOfStock
                                            ? AppColors.danger.withValues(alpha: 0.12)
                                            : p.lowStock
                                                ? AppColors.warning.withValues(alpha: 0.12)
                                                : AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        p.outOfStock
                                            ? 'نفد المخزون'
                                            : p.lowStock
                                                ? 'منخفض: ${p.stock}'
                                                : 'المخزون: ${p.stock}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: p.outOfStock
                                              ? AppColors.danger
                                              : p.lowStock
                                                  ? AppColors.warning
                                                  : AppColors.success,
                                        ),
                                      ),
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
