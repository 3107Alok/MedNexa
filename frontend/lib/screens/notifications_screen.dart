import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<LocalNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final list = await NotificationService.getNotifications(user.uid);
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    await NotificationService.markAllAsRead(userId);
    await _loadNotifications();
  }

  Future<void> _markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;
    final user = authProvider.user;

    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[700];

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getBackgroundGradient(isDark),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () => _markAllAsRead(user.uid),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Info Tip about 24h retention
                      GlassContainer(
                        isDarkMode: isDark,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: Notifications are automatically cleared after 24 hours.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadNotifications,
                          child: _notifications.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.notifications_off_outlined,
                                            size: 64,
                                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No notifications yet',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: subtitleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Alerts regarding approvals and bookings will appear here.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: isDark ? Colors.white60 : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: _notifications.length,
                                  itemBuilder: (context, index) {
                                    final notif = _notifications[index];
                                    final isRead = notif.isRead;
                                    final timeStr = DateFormat('hh:mm a').format(notif.createdAt);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: GlassContainer(
                                        isDarkMode: isDark,
                                        borderRadius: 16,
                                        border: isRead
                                            ? null
                                            : Border.all(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                width: 1.5,
                                              ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: CircleAvatar(
                                            backgroundColor: isRead
                                                ? (isDark ? Colors.white10 : Colors.grey[100])
                                                : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                            child: Icon(
                                              Icons.notifications,
                                              color: isRead
                                                  ? (isDark ? Colors.white54 : Colors.grey)
                                                  : Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                    fontSize: 15,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              notif.body,
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: isRead
                                                    ? (isDark ? Colors.white60 : Colors.grey[600])
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            if (!isRead) {
                                              _markAsRead(notif.id);
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
