import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  LocalNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory LocalNotification.fromJson(Map<String, dynamic> json) => LocalNotification(
    id: json['id'],
    userId: json['userId'],
    title: json['title'],
    body: json['body'],
    createdAt: DateTime.parse(json['createdAt']),
    isRead: json['isRead'] ?? false,
  );
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String _notificationsKey = 'local_notifications';

  static Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledTime) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('reminder_channel', 'Reminders', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<List<LocalNotification>> getNotifications(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notificationsKey) ?? [];
    
    final notifications = list
        .map((item) => LocalNotification.fromJson(jsonDecode(item)))
        .where((n) => n.userId == userId)
        .toList();

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final active = notifications.where((n) => n.createdAt.isAfter(cutoff)).toList();

    if (active.length != notifications.length || list.length != active.length) {
      final allList = list
          .map((item) => LocalNotification.fromJson(jsonDecode(item)))
          .where((n) => n.userId != userId || n.createdAt.isAfter(cutoff))
          .map((n) => jsonEncode(n.toJson()))
          .toList();
      await prefs.setStringList(_notificationsKey, allList);
    }

    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return active;
  }

  static Future<void> addNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notificationsKey) ?? [];
    
    final newNotif = LocalNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );

    list.add(jsonEncode(newNotif.toJson()));
    await prefs.setStringList(_notificationsKey, list);
    
    try {
      await showImmediateNotification(newNotif.id.hashCode, title, body);
    } catch (e) {
      debugPrint('Local push notification error: $e');
    }
  }

  static Future<void> showImmediateNotification(int id, String title, String body) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('alert_channel', 'Alerts', importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> markAllAsRead(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notificationsKey) ?? [];
    
    final updated = list.map((item) {
      final n = LocalNotification.fromJson(jsonDecode(item));
      if (n.userId == userId) {
        return jsonEncode(LocalNotification(
          id: n.id,
          userId: n.userId,
          title: n.title,
          body: n.body,
          createdAt: n.createdAt,
          isRead: true,
        ).toJson());
      }
      return item;
    }).toList();

    await prefs.setStringList(_notificationsKey, updated);
  }

  static Future<void> markAsRead(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_notificationsKey) ?? [];
    
    final updated = list.map((item) {
      final n = LocalNotification.fromJson(jsonDecode(item));
      if (n.id == notificationId) {
        return jsonEncode(LocalNotification(
          id: n.id,
          userId: n.userId,
          title: n.title,
          body: n.body,
          createdAt: n.createdAt,
          isRead: true,
        ).toJson());
      }
      return item;
    }).toList();

    await prefs.setStringList(_notificationsKey, updated);
  }
}
