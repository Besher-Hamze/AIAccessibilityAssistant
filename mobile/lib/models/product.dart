class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: _toDouble(json['price']),
      stock: json['stock'] as int? ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  bool get lowStock => stock > 0 && stock <= 10;
  bool get outOfStock => stock <= 0;
}
