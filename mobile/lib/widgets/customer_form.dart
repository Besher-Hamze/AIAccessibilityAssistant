import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';

/// Add or edit a customer. Returns true when something was saved.
Future<bool> showCustomerForm(BuildContext context, {Customer? customer}) async {
  final isAdmin = context.read<AuthProvider>().user?.isAdmin == true;
  final messenger = ScaffoldMessenger.of(context);
  if (customer != null && !isAdmin) {
    messenger.showSnackBar(
      const SnackBar(content: Text('التعديل متاح للمدير فقط')),
    );
    return false;
  }

  final name = TextEditingController(text: customer?.name ?? '');
  final phone = TextEditingController(text: customer?.phone ?? '');
  final email = TextEditingController(text: customer?.email ?? '');
  final address = TextEditingController(text: customer?.address ?? '');
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

  if (saved == true) {
    messenger.showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
    return true;
  }
  return false;
}
