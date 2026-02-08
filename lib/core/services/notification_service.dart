import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        // TODO: Handle notification tap logic if needed
      },
    );

    // Create channel for high importance notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sika_reminders', // id
      'Rappels et Échéances', // title
      description: 'Notifications pour les factures et dettes à payer',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  /// Schedule a notification for a debt or bill
  Future<void> scheduleDebtReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    if (!_isInitialized) await init();

    // Schedule for 9:00 AM on the due date
    var scheduledDate = tz.TZDateTime.from(dueDate, tz.local);

    // Ensure we don't schedule in the past.
    // If due date is today but passed, or in past, maybe show immediately or ignore?
    // Let's simplified: if in past, don't schedule.
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    // Set to 9:00 AM
    scheduledDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9, // 9 AM
      0,
    );

    // If 9 AM passed today, schedule for next day (rare case logic, simplified here)
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      // Just schedule 1 minute from now for testing?
      // Or ignore. Let's ignore for now to avoid spam.
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sika_reminders',
          'Rappels et Échéances',
          channelDescription:
              'Notifications pour les factures et dettes à payer',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF1A237E), // Bleu Nuit
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Request permissions (Android 13+)
  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
