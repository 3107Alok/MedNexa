class ChatMessage {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': message,
      'isUser': isUser,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      message: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is String ? DateTime.parse(json['timestamp']) : DateTime.now()) 
          : DateTime.now(),
    );
  }

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      message: data['message'] ?? '',
      isUser: data['isUser'] ?? false,
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as dynamic).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'isUser': isUser,
      'timestamp': timestamp,
    };
  }
}
