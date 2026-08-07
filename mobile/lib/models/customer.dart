class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int invoicesCount;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.invoicesCount = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      invoicesCount: count is Map ? (count['invoices'] as int? ?? 0) : 0,
    );
  }
}
