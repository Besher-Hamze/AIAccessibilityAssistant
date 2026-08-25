class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool isLoading;
  final String? speakerGender;
  final String? speakerGenderAr;
  final double? confidence;
  final String? toolUsed;
  final String? intent;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isLoading = false,
    this.speakerGender,
    this.speakerGenderAr,
    this.confidence,
    this.toolUsed,
    this.intent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    String? toolUsed;
    String? intent;
    if (meta is Map) {
      toolUsed = meta['toolUsed']?.toString();
      intent = meta['intent']?.toString();
    }
    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      toolUsed: toolUsed,
      intent: intent,
    );
  }

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      isLoading: isLoading ?? this.isLoading,
      speakerGender: speakerGender,
      speakerGenderAr: speakerGenderAr,
      confidence: confidence,
      toolUsed: toolUsed,
      intent: intent,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  String? get toolLabel {
    if (toolUsed == null || toolUsed!.isEmpty) return null;
    const names = {
      'list_customers': 'عرض العملاء',
      'search_customers': 'بحث عملاء',
      'create_customer': 'إضافة عميل',
      'update_customer': 'تعديل عميل',
      'list_products': 'عرض المنتجات',
      'create_product': 'إضافة منتج',
      'update_product_stock': 'تحديث مخزون',
      'get_customer_invoices': 'فواتير عميل',
      'get_latest_invoice': 'آخر فاتورة',
      'search_invoices': 'عرض الفواتير',
      'create_invoice': 'إنشاء فاتورة',
      'update_invoice_status': 'حالة فاتورة',
      'get_accounting_summary': 'ملخص المحاسبة',
      'generate_report': 'تقرير',
    };
    final source = switch (intent) {
      'ollama' => 'النموذج',
      'direct' || 'loose' => 'مطابقة احتياط',
      _ => null,
    };
    final label = names[toolUsed] ?? toolUsed!;
    return source == null ? label : '$label · $source';
  }
}
