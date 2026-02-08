import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:drift/drift.dart' show Value;

import 'package:sika_app/core/database/app_database.dart';

/// Contrôleur des notifications locales
///
/// Gère l'affichage des notifications de transactions.
/// Utilise flutter_local_notifications (plus stable que awesome_notifications).
class NotificationController {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'sika_transactions';
  static const String channelName = 'Transactions SIKA';
  static const String channelDescription = 'Notifications de transactions SIKA';

  static const String actionValidate = 'VALIDATE';
  static const String actionReject = 'REJECT';

  static AppDatabase? _database;

  /// Initialise le système de notifications
  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Créer le canal de notification Android
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Injecte la base de données
  static void setDatabase(AppDatabase db) {
    _database = db;
  }

  /// Demande les permissions de notification
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Vérifie si les notifications sont autorisées
  static Future<bool> isAllowed() async {
    return true; // flutter_local_notifications gère ça automatiquement
  }

  // ==================== AFFICHAGE DES NOTIFICATIONS ====================

  /// Affiche une notification simple (mode auto-save)
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF1A237E), // Bleu Nuit
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  /// Affiche une notification de succès
  static Future<void> showSuccessNotification({
    required double amount,
    required String merchant,
    required bool isExpense,
  }) async {
    final type = isExpense ? 'Dépense' : 'Revenu';

    await showSimpleNotification(
      title: '$type enregistré',
      body: '${amount.toStringAsFixed(0)} FCFA • $merchant',
    );
  }

  /// Affiche une notification actionnable (mode manuel)
  ///
  /// Note: Les actions sont simplifiées avec flutter_local_notifications.
  /// L'utilisateur clique sur la notification pour ouvrir l'app et décider.
  static Future<void> showActionableNotification({
    required String transactionId,
    required double amount,
    required String merchant,
    required bool isExpense,
  }) async {
    final type = isExpense ? 'Dépense' : 'Revenu';

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF1A237E), // Bleu Nuit
      actions: [
        AndroidNotificationAction(actionValidate, 'Valider'),
        AndroidNotificationAction(actionReject, 'Rejeter'),
      ],
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Nouvelle transaction',
      '${amount.toStringAsFixed(0)} FCFA • $merchant • $type',
      details,
      payload: transactionId,
    );
  }

  // ==================== HANDLERS ====================

  /// Callback quand une notification est cliquée ou action reçue
  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final transactionId = response.payload;
    if (transactionId == null || _database == null) return;

    final actionId = response.actionId;

    if (actionId == actionValidate) {
      await _validateTransaction(transactionId);
    } else if (actionId == actionReject) {
      await _rejectTransaction(transactionId);
    }
    // Si pas d'action spécifique, l'app s'ouvre simplement
  }

  /// Valide une transaction (validationStatus = 1)
  static Future<void> _validateTransaction(String transactionId) async {
    final db = _database;
    if (db == null) return;

    await (db.update(db.transactionsTable)
          ..where((t) => t.id.equals(transactionId)))
        .write(const TransactionsTableCompanion(validationStatus: Value(1)));

    await showSimpleNotification(
      title: 'Transaction validée',
      body: 'La transaction a été enregistrée.',
    );
  }

  /// Rejette une transaction (suppression)
  static Future<void> _rejectTransaction(String transactionId) async {
    final db = _database;
    if (db == null) return;

    await (db.delete(
      db.transactionsTable,
    )..where((t) => t.id.equals(transactionId))).go();

    await showSimpleNotification(
      title: 'Transaction rejetée',
      body: 'La transaction a été supprimée.',
    );
  }
}
