class InvoiceItem {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  InvoiceItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return InvoiceItem(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? product?['id'] as String? ?? '',
      productName: product?['name'] as String? ?? 'منتج',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: _toDouble(json['unitPrice']),
      subtotal: _toDouble(json['subtotal']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

class Invoice {
  final String id;
  final String number;
  final String customerId;
  final String customerName;
  final double total;
  final String status;
  final String? notes;
  final DateTime date;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.total,
    required this.status,
    this.notes,
    required this.date,
    this.items = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    return Invoice(
      id: json['id'] as String,
      number: json['number'] as String,
      customerId: json['customerId'] as String? ?? customer?['id'] as String? ?? '',
      customerName: customer?['name'] as String? ?? 'عميل',
      total: InvoiceItem._toDouble(json['total']),
      status: json['status'] as String? ?? 'PENDING',
      notes: json['notes'] as String?,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      items: itemsJson
          .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get statusAr {
    switch (status) {
      case 'PAID':
        return 'مدفوعة';
      case 'PENDING':
        return 'معلقة';
      case 'DRAFT':
        return 'مسودة';
      case 'CANCELLED':
        return 'ملغاة';
      default:
        return status;
    }
  }
}
