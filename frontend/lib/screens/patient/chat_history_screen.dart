import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/chat_history_service.dart';
import 'package:frontend/models/chat_session_model.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/screens/patient/chatbot_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final ChatHistoryService _chatHistoryService = ChatHistoryService();

  void _navigateToSession(String? sessionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatbotScreen(sessionId: sessionId),
      ),
    );
  }

  void _deleteSession(String userId, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Conversation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete this conversation?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatHistoryService.deleteSession(userId, sessionId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted permanently')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete conversation')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];

    final userId = authProvider.user?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat History')),
        body: const Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chat History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: theme.primaryColor),
            tooltip: 'New Chat',
            onPressed: () => _navigateToSession(null), // Always open a new empty session
          ),
        ],
      ),
      body: StreamBuilder<List<ChatSessionModel>>(
        stream: _chatHistoryService.getSessionsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}', style: TextStyle(color: textColor)));
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No previous conversations', style: GoogleFonts.outfit(fontSize: 16, color: subtitleColor)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToSession(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Start a New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (context, index) => Divider(color: isDark ? Colors.white12 : Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  _deleteSession(userId, session.id);
                  return false; // Dialog handles the actual deletion
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.smart_toy, color: theme.primaryColor),
                  ),
                  title: Text(
                    session.title,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    session.lastMessage,
                    style: GoogleFonts.outfit(color: subtitleColor, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    _formatDate(session.updatedAt),
                    style: GoogleFonts.outfit(color: subtitleColor, fontSize: 11),
                  ),
                  onTap: () => _navigateToSession(session.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && now.day == date.day) {
      return DateFormat.jm().format(date); // e.g., 5:30 PM
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(date); // e.g., Mon, Tue
    } else {
      return DateFormat('MMM d').format(date); // e.g., Oct 24
    }
  }
}
