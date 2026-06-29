import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSessionModel {
  final String id;
  final String userId;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;
  final DateTime createdAt;

  ChatSessionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    required this.createdAt,
  });

  factory ChatSessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSessionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'New Conversation',
      lastMessage: data['lastMessage'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'lastMessage': lastMessage,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt, // Keep original creation time if passed
    };
  }
}
