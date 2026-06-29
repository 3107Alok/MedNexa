import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/models/chat_session_model.dart';
import 'package:frontend/models/chat_message.dart';

class ChatHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new session
  Future<String> createSession(String userId, String initialMessage) async {
    final docRef = _db.collection('users').doc(userId).collection('chat_sessions').doc();
    
    // Create title from first 30 chars of initial message
    String title = initialMessage.length > 30 
        ? '${initialMessage.substring(0, 30)}...' 
        : initialMessage;

    final session = ChatSessionModel(
      id: docRef.id,
      userId: userId,
      title: title,
      lastMessage: initialMessage,
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await docRef.set(session.toJson());
    return docRef.id;
  }

  // Get stream of sessions for a user
  Stream<List<ChatSessionModel>> getSessionsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatSessionModel.fromFirestore(doc))
            .toList());
  }

  // Get stream of messages for a session (real-time, not strictly needed for this design)
  Stream<List<ChatMessage>> getMessagesStream(String userId, String sessionId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc.data()))
            .toList());
  }

  // Get all messages for a session once
  Future<List<ChatMessage>> getMessages(String userId, String sessionId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();
    
    return snapshot.docs
        .map((doc) => ChatMessage.fromFirestore(doc.data()))
        .toList();
  }

  // Add a message to an existing session
  Future<void> addMessageToSession(String userId, String sessionId, ChatMessage message) async {
    final sessionRef = _db.collection('users').doc(userId).collection('chat_sessions').doc(sessionId);
    final messagesRef = sessionRef.collection('messages');

    // Batch write to update both the message list and the session's last updated time
    WriteBatch batch = _db.batch();

    // 1. Add the new message
    final newMsgRef = messagesRef.doc();
    batch.set(newMsgRef, message.toFirestore());

    // 2. Update the session's lastMessage and updatedAt
    batch.update(sessionRef, {
      'lastMessage': message.message,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Hard delete a session and all its messages
  Future<void> deleteSession(String userId, String sessionId) async {
    final sessionRef = _db.collection('users').doc(userId).collection('chat_sessions').doc(sessionId);
    
    // First, delete all messages in the subcollection
    final messagesSnapshot = await sessionRef.collection('messages').get();
    WriteBatch batch = _db.batch();
    
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // Finally, delete the session document itself
    batch.delete(sessionRef);
    
    await batch.commit();
  }
}
