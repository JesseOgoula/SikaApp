import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service de notifications locales pour SikaApp
///
/// Gère tous les types de notifications:
/// - Rappels de dettes/factures (jour J, J-3, J-1)
/// - Alertes solde faible
/// - Rappels objectifs d'épargne
/// - Résumés hebdomadaires
/// - Célébrations d'objectifs atteints
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Notification Channel IDs
  static const String _channelReminders = 'sika_reminders';
  static const String _channelBalance = 'sika_balance_alerts';
  static const String _channelGoals = 'sika_goal_reminders';
  static const String _channelSummary = 'sika_weekly_summary';
  static const String _channelCelebrations = 'sika_celebrations';

  // Notification ID Ranges (pour éviter les conflits)
  static const int _idDebtBase = 1000;
  static const int _idDebtPre3Days = 2000;
  static const int _idDebtPre1Day = 3000;
  static const int _idGoalReminder = 4000;
  static const int _idWeeklySummary = 5000;
  static const int _idLowBalance = 6000;
  static const int _idGoalCompleted = 7000;

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
        debugPrint('📱 [Notification] Tapped: ${details.payload}');
      },
    );

    // Create all notification channels
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // 1. Rappels et Échéances
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelReminders,
          'Rappels et Échéances',
          description: 'Notifications pour les factures et dettes à payer',
          importance: Importance.high,
        ),
      );

      // 2. Alertes Solde
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelBalance,
          'Alertes Solde',
          description: 'Notifications quand votre solde est faible',
          importance: Importance.high,
        ),
      );

      // 3. Objectifs d'épargne
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelGoals,
          'Objectifs d\'épargne',
          description: 'Rappels pour alimenter vos objectifs',
          importance: Importance.defaultImportance,
        ),
      );

      // 4. Résumé hebdomadaire
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelSummary,
          'Résumé Hebdomadaire',
          description: 'Récap de vos finances chaque semaine',
          importance: Importance.defaultImportance,
        ),
      );

      // 5. Célébrations
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelCelebrations,
          'Félicitations',
          description: 'Célébrations quand vous atteignez vos objectifs',
          importance: Importance.high,
        ),
      );
    }

    _isInitialized = true;
    debugPrint('✅ [Notifications] Service initialized with all channels');
  }

  // ==================== DEBT REMINDERS ====================

  /// Schedule reminders for a debt: J-3, J-1, and J (due date)
  Future<void> scheduleDebtReminders({
    required String debtId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (!_isInitialized) await init();

    final idHash = debtId.hashCode.abs();
    final formattedAmount = _formatAmount(amount);

    // J-3: 3 days before
    final threeDaysBefore = dueDate.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: _idDebtPre3Days + (idHash % 1000),
        title: '⏰ Rappel: $title dans 3 jours',
        body: 'Préparez $formattedAmount FCFA pour le ${_formatDate(dueDate)}',
        scheduledDate: _setTime(threeDaysBefore, 9, 0),
        channelId: _channelReminders,
        channelName: 'Rappels et Échéances',
      );
    }

    // J-1: 1 day before
    final oneDayBefore = dueDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: _idDebtPre1Day + (idHash % 1000),
        title: '⚠️ Demain: $title',
        body: '$formattedAmount FCFA à payer demain!',
        scheduledDate: _setTime(oneDayBefore, 18, 0), // 18h la veille
        channelId: _channelReminders,
        channelName: 'Rappels et Échéances',
      );
    }

    // J: Due date
    if (dueDate.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: _idDebtBase + (idHash % 1000),
        title: '🔔 Aujourd\'hui: $title',
        body: '$formattedAmount FCFA à payer aujourd\'hui!',
        scheduledDate: _setTime(dueDate, 9, 0),
        channelId: _channelReminders,
        channelName: 'Rappels et Échéances',
      );
    }

    debugPrint('✅ [Notifications] Scheduled debt reminders for $title');
  }

  /// Cancel all reminders for a specific debt
  Future<void> cancelDebtReminders(String debtId) async {
    final idHash = debtId.hashCode.abs();
    await cancel(_idDebtBase + (idHash % 1000));
    await cancel(_idDebtPre1Day + (idHash % 1000));
    await cancel(_idDebtPre3Days + (idHash % 1000));
  }

  // ==================== LOW BALANCE ALERT ====================

  /// Show immediate low balance alert
  Future<void> showLowBalanceAlert({
    required double currentBalance,
    required double threshold,
  }) async {
    if (!_isInitialized) await init();

    final formattedBalance = _formatAmount(currentBalance);
    final formattedThreshold = _formatAmount(threshold);

    await _notificationsPlugin.show(
      _idLowBalance,
      '📉 Solde faible!',
      'Votre solde ($formattedBalance FCFA) est sous $formattedThreshold FCFA',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBalance,
          'Alertes Solde',
          channelDescription: 'Notifications quand votre solde est faible',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFE53935), // Rouge
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
    );

    debugPrint('⚠️ [Notifications] Low balance alert shown');
  }

  // ==================== GOAL REMINDERS ====================

  /// Schedule weekly goal reminder (every Sunday at 10 AM)
  Future<void> scheduleWeeklyGoalReminder({
    required String goalId,
    required String goalName,
    required double currentAmount,
    required double targetAmount,
  }) async {
    if (!_isInitialized) await init();

    final idHash = goalId.hashCode.abs();
    final remaining = targetAmount - currentAmount;
    final formattedRemaining = _formatAmount(remaining);

    // Find next Sunday
    var nextSunday = DateTime.now();
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _idGoalReminder + (idHash % 1000),
      title: '🎯 Objectif: $goalName',
      body: 'Plus que $formattedRemaining FCFA pour atteindre votre objectif!',
      scheduledDate: _setTime(nextSunday, 10, 0),
      channelId: _channelGoals,
      channelName: 'Objectifs d\'épargne',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint('✅ [Notifications] Weekly reminder scheduled for $goalName');
  }

  /// Cancel goal reminder
  Future<void> cancelGoalReminder(String goalId) async {
    final idHash = goalId.hashCode.abs();
    await cancel(_idGoalReminder + (idHash % 1000));
  }

  // ==================== GOAL COMPLETED ====================

  /// Show celebration notification when goal is completed
  Future<void> showGoalCompletedNotification({
    required String goalName,
    required double amount,
  }) async {
    if (!_isInitialized) await init();

    final formattedAmount = _formatAmount(amount);

    await _notificationsPlugin.show(
      _idGoalCompleted + DateTime.now().millisecondsSinceEpoch % 1000,
      '🎉 Félicitations!',
      'Objectif "$goalName" atteint! Vous avez épargné $formattedAmount FCFA',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelCelebrations,
          'Félicitations',
          channelDescription: 'Célébrations quand vous atteignez vos objectifs',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF4CAF50), // Vert
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
    );

    debugPrint('🎉 [Notifications] Goal completed: $goalName');
  }

  // ==================== WEEKLY SUMMARY ====================

  /// Schedule weekly summary notification (every Sunday at 6 PM)
  Future<void> scheduleWeeklySummary() async {
    if (!_isInitialized) await init();

    // Find next Sunday
    var nextSunday = DateTime.now();
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _idWeeklySummary,
      title: '📊 Résumé de la semaine',
      body: 'Découvrez vos statistiques financières de la semaine!',
      scheduledDate: _setTime(nextSunday, 18, 0),
      channelId: _channelSummary,
      channelName: 'Résumé Hebdomadaire',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint('✅ [Notifications] Weekly summary scheduled');
  }

  /// Show weekly summary with actual data
  Future<void> showWeeklySummaryNow({
    required double totalExpenses,
    required double totalIncome,
    required double savings,
  }) async {
    if (!_isInitialized) await init();

    final formattedExpenses = _formatAmount(totalExpenses);
    final formattedIncome = _formatAmount(totalIncome);

    await _notificationsPlugin.show(
      _idWeeklySummary + 1,
      '📊 Résumé de la semaine',
      'Revenus: $formattedIncome FCFA | Dépenses: $formattedExpenses FCFA',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelSummary,
          'Résumé Hebdomadaire',
          channelDescription: 'Récap de vos finances chaque semaine',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFF5E35B1), // Violet
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF5E35B1),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  tz.TZDateTime _setTime(DateTime date, int hour, int minute) {
    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
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
