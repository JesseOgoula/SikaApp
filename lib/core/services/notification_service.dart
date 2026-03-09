import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:sika_app/core/services/notification_preferences.dart';

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
      '@drawable/ic_stat_notification',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {},
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
  }

  // ==================== DEBT REMINDERS ====================

  /// Schedule reminders for a debt based on user preferences
  Future<void> scheduleDebtReminders({
    required String debtId,
    required String title,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (!_isInitialized) await init();

    final prefs = NotificationPreferences();
    final masterEnabled = await prefs.isEnabled;
    final debtEnabled = await prefs.debtRemindersEnabled;
    if (!masterEnabled || !debtEnabled) return;

    final idHash = debtId.hashCode.abs();
    final formattedAmount = _formatAmount(amount);
    final reminderDays = await prefs.debtReminderDays;
    final reminderHour = await prefs.debtReminderHour;

    // Cancel existing reminders first
    await cancelDebtReminders(debtId);

    // Schedule reminders for each configured day
    for (final days in reminderDays) {
      final reminderDate = dueDate.subtract(Duration(days: days));
      if (reminderDate.isAfter(DateTime.now())) {
        final label = days == 1 ? 'Demain' : 'Dans $days jours';
        await _scheduleNotification(
          id: (idHash + days * 1000) % 100000,
          title: '$label — $title',
          body:
              '$formattedAmount FCFA à prévoir pour le ${_formatDate(dueDate)}',
          scheduledDate: _setTime(reminderDate, reminderHour, 0),
          channelId: _channelReminders,
          channelName: 'Rappels et Échéances',
        );
      }
    }

    // Always schedule on due date
    if (dueDate.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: _idDebtBase + (idHash % 1000),
        title: 'Échéance aujourd\'hui — $title',
        body: 'Montant dû : $formattedAmount FCFA',
        scheduledDate: _setTime(dueDate, reminderHour, 0),
        channelId: _channelReminders,
        channelName: 'Rappels et Échéances',
      );
    }
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

    final prefs = NotificationPreferences();
    final masterEnabled = await prefs.isEnabled;
    final lowBalanceEnabled = await prefs.lowBalanceEnabled;
    if (!masterEnabled || !lowBalanceEnabled) return;

    final formattedBalance = _formatAmount(currentBalance);
    final formattedThreshold = _formatAmount(threshold);

    await _notificationsPlugin.show(
      _idLowBalance,
      'Solde faible',
      'Votre solde est de $formattedBalance FCFA, en dessous du seuil de $formattedThreshold FCFA.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBalance,
          'Alertes Solde',
          channelDescription: 'Notifications quand votre solde est faible',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFE53935), // Rouge
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          icon: '@drawable/ic_stat_notification',
        ),
      ),
    );
  }

  // ==================== GOAL REMINDERS ====================

  /// Schedule weekly goal reminder based on user preferences
  Future<void> scheduleWeeklyGoalReminder({
    required String goalId,
    required String goalName,
    required double currentAmount,
    required double targetAmount,
  }) async {
    if (!_isInitialized) await init();

    final prefs = NotificationPreferences();
    final masterEnabled = await prefs.isEnabled;
    final goalEnabled = await prefs.goalRemindersEnabled;
    if (!masterEnabled || !goalEnabled) return;

    final goalDay = await prefs.goalReminderDay;
    final goalHour = await prefs.goalReminderHour;

    final idHash = goalId.hashCode.abs();
    final remaining = targetAmount - currentAmount;
    final formattedRemaining = _formatAmount(remaining);

    // Find next matching day
    var nextDay = DateTime.now();
    while (nextDay.weekday != goalDay) {
      nextDay = nextDay.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _idGoalReminder + (idHash % 1000),
      title: 'Objectif — $goalName',
      body:
          'Il vous reste $formattedRemaining FCFA à épargner pour atteindre cet objectif.',
      scheduledDate: _setTime(nextDay, goalHour, 0),
      channelId: _channelGoals,
      channelName: 'Objectifs d\'épargne',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
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
      'Objectif atteint',
      'Vous avez atteint votre objectif "$goalName" avec $formattedAmount FCFA épargnés.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelCelebrations,
          'Félicitations',
          channelDescription: 'Célébrations quand vous atteignez vos objectifs',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF4CAF50), // Vert
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          icon: '@drawable/ic_stat_notification',
        ),
      ),
    );
  }

  // ==================== WEEKLY SUMMARY ====================

  /// Schedule weekly summary notification based on user preferences
  Future<void> scheduleWeeklySummary() async {
    if (!_isInitialized) await init();

    final prefs = NotificationPreferences();
    final masterEnabled = await prefs.isEnabled;
    final summaryEnabled = await prefs.weeklySummaryEnabled;
    if (!masterEnabled || !summaryEnabled) {
      await cancel(_idWeeklySummary);
      return;
    }

    final summaryDay = await prefs.weeklySummaryDay;
    final summaryHour = await prefs.weeklySummaryHour;

    // Find next matching day
    var nextDay = DateTime.now();
    while (nextDay.weekday != summaryDay) {
      nextDay = nextDay.add(const Duration(days: 1));
    }

    await _scheduleNotification(
      id: _idWeeklySummary,
      title: 'Résumé hebdomadaire',
      body: 'Votre bilan financier de la semaine est disponible.',
      scheduledDate: _setTime(nextDay, summaryHour, 0),
      channelId: _channelSummary,
      channelName: 'Résumé Hebdomadaire',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
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
      'Résumé hebdomadaire',
      'Revenus : $formattedIncome FCFA · Dépenses : $formattedExpenses FCFA',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelSummary,
          'Résumé Hebdomadaire',
          channelDescription: 'Récap de vos finances chaque semaine',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFF5E35B1), // Violet
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          icon: '@drawable/ic_stat_notification',
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
          icon: '@drawable/ic_stat_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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

  /// Notification immédiate quand un budget est dépassé
  static const int _idBudgetExceeded = 8000;

  Future<void> showBudgetExceededNotification({
    required String categoryName,
    required double budgetLimit,
    required double currentSpent,
  }) async {
    final exceeded = currentSpent - budgetLimit;

    await _notificationsPlugin.show(
      _idBudgetExceeded + categoryName.hashCode.abs() % 1000,
      'Budget dépassé — $categoryName',
      'Vous avez dépassé votre limite de ${exceeded.toStringAsFixed(0)} FCFA sur cette catégorie.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBalance,
          'Alertes Budget',
          channelDescription: 'Alertes de dépassement de budget',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFE53935),
          icon: '@drawable/ic_stat_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      payload: 'budget_exceeded:$categoryName',
    );
  }

  /// Notification quand le budget global mensuel est dépassé
  static const int _idGlobalBudgetExceeded = 9000;

  Future<void> showGlobalBudgetExceededNotification({
    required double budgetLimit,
    required double currentSpent,
  }) async {
    if (!_isInitialized) await init();

    final exceeded = currentSpent - budgetLimit;
    final formattedExceeded = _formatAmount(exceeded);

    await _notificationsPlugin.show(
      _idGlobalBudgetExceeded,
      '⚠️ Budget mensuel dépassé',
      'Vous avez dépassé votre budget global de $formattedExceeded FCFA. Réduisez vos dépenses !',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBalance,
          'Alertes Budget',
          channelDescription: 'Alertes de dépassement de budget',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFE53935),
          icon: '@drawable/ic_stat_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      payload: 'global_budget_exceeded',
    );
  }
}
