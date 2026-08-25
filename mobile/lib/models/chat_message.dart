class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool isLoading;
  final String? speakerGender;
  final String? speakerGenderAr;
  final double? confidence;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isLoading = false,
    this.speakerGender,
    this.speakerGenderAr,
    this.confidence,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
