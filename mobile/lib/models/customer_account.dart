import 'customer.dart';
import 'invoice.dart';

/// One product across all of a customer's invoices.
class CustomerProduct {
  final String productId;
  final String name;
  final int quantity;
  final double amount;
  final DateTime? lastDate;

  CustomerProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.amount,
    this.lastDate,
  });

  factory CustomerProduct.fromJson(Map<String, dynamic> json) {
    return CustomerProduct(
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      amount: double.tryParse('${json['amount']}') ?? 0,
      lastDate: DateTime.tryParse('${json['lastDate']}'),
    );
  }
}

/// Everything shown on a customer's page.
class CustomerAccount {
  final Customer customer;
  final List<Invoice> invoices;
  final List<CustomerProduct> products;
  final int invoiceCount;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final int totalUnits;
  final Map<String, int> counts;

  CustomerAccount({
    required this.customer,
    required this.invoices,
    required this.products,
    required this.invoiceCount,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.totalUnits,
    required this.counts,
  });

  factory CustomerAccount.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    double money(String key) => double.tryParse('${stats[key]}') ?? 0;
    return CustomerAccount(
      customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
      invoices: (json['invoices'] as List<dynamic>)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>)
          .map((e) => CustomerProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      invoiceCount: stats['invoiceCount'] as int? ?? 0,
      totalAmount: money('totalAmount'),
      paidAmount: money('paidAmount'),
      pendingAmount: money('pendingAmount'),
      totalUnits: stats['totalUnits'] as int? ?? 0,
      counts: (stats['counts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
    );
  }

  /// What the assistant says when opening this page.
  String get spokenSummary {
    final name = customer.name;
    if (invoiceCount == 0) return 'حساب $name. لا توجد فواتير بعد.';
    final top = products.take(3).map((p) => '${p.name} ${p.quantity}').join('، ');
    return 'حساب $name: عدد الفواتير $invoiceCount، '
        'الإجمالي ${_spoken(totalAmount)} ليرة، '
        'المدفوع ${_spoken(paidAmount)}، والمعلق ${_spoken(pendingAmount)}.'
        '${top.isEmpty ? '' : ' أكثر ما اشتراه: $top.'}';
  }

  static String _spoken(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
}
