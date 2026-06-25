import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/utils/logger.dart';
import 'package:sika_app/features/notification_sync/data/parsers/notification_parser.dart';
import 'package:sika_app/features/notification_sync/data/services/pending_transaction_queue.dart';
import 'package:sika_app/features/notification_sync/data/services/sms_listener_service.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// Service principal d'orchestration de la détection automatique de transactions
///
/// Coordonne :
/// 1. L'écoute des notifications push via NotificationListenerService (Android)
/// 2. L'écoute des SMS via SmsListenerService (Android)
/// 3. Le parsing via NotificationParser
/// 4. L'ajout dans PendingTransactionQueue
/// 5. L'affichage de notifications locales pour informer l'utilisateur
class NotificationSyncService {
  static final NotificationSyncService _instance =
      NotificationSyncService._internal();

  factory NotificationSyncService() => _instance;

  NotificationSyncService._internal();

  static const String _tag = 'NOTIF_SYNC';
  static const String _prefKey = 'notification_sync_enabled';
  static const String _channelId = 'sika_auto_detect';
  static const int _notifIdBase = 10000;

  /// MethodChannel pour communiquer avec le NotificationListenerService Android natif
  static const MethodChannel _notifChannel =
      MethodChannel('sika/notification_listener');

  final PendingTransactionQueue _queue = PendingTransactionQueue();
  final SmsListenerService _smsListener = SmsListenerService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isEnabled = false;

  /// Initialise le service de détection automatique
  ///
  /// Doit être appelé une seule fois dans main.dart après les autres initialisations.
  Future<void> init(AppDatabase database) async {
    if (_isInitialized) return;

    _queue.database = database;

    // Charger la préférence
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;

    if (!_isEnabled) {
      SikaLogger.info('Notification sync disabled by user', tag: _tag);
      _isInitialized = true;
      return;
    }

    // Créer le channel de notification locale pour les alertes de détection
    await _createNotificationChannel();

    if (Platform.isAndroid) {
      // 1. Écouter les notifications d'autres apps
      await _startNotificationListener();

      // 2. Écouter les SMS
      await _smsListener.startListening();
    }

    _isInitialized = true;
    SikaLogger.info('NotificationSyncService initialized', tag: _tag);
  }

  /// Active ou désactive la détection automatique
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);

    if (enabled) {
      if (Platform.isAndroid) {
        await _startNotificationListener();
        await _smsListener.startListening();
      }
      SikaLogger.info('Notification sync enabled', tag: _tag);
    } else {
      _stopListeners();
      SikaLogger.info('Notification sync disabled', tag: _tag);
    }
  }

  /// Vérifie si le NotificationListenerService Android est activé
  Future<bool> isNotificationListenerEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _notifChannel.invokeMethod<bool>('isListenerEnabled');
      return result ?? false;
    } catch (e) {
      SikaLogger.error('Failed to check listener status: $e', tag: _tag);
      return false;
    }
  }

  /// Ouvre les paramètres Android pour activer le NotificationListenerService
  Future<void> openNotificationListenerSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _notifChannel.invokeMethod('openListenerSettings');
    } catch (e) {
      SikaLogger.error('Failed to open listener settings: $e', tag: _tag);
    }
  }

  /// Démarre l'écoute des notifications d'autres applications
  Future<void> _startNotificationListener() async {
    try {
      _notifChannel.setMethodCallHandler(_handleNotificationFromNative);
      SikaLogger.info('Notification listener channel ready', tag: _tag);
    } catch (e) {
      SikaLogger.error('Failed to start notification listener: $e', tag: _tag);
    }
  }

  /// Handler des notifications reçues depuis le code natif Android
  Future<dynamic> _handleNotificationFromNative(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final args = call.arguments as Map<dynamic, dynamic>;
        await _processNotification(
          packageName: args['packageName'] as String? ?? '',
          title: args['title'] as String? ?? '',
          text: args['text'] as String? ?? '',
        );
        break;
      default:
        break;
    }
  }

  /// Traite une notification interceptée
  Future<void> _processNotification({
    required String packageName,
    required String title,
    required String text,
  }) async {
    // Parse la notification
    final parsed = NotificationParser.parseMessage(
      sender: packageName,
      title: title,
      body: text,
      receivedAt: DateTime.now().toIso8601String(),
      source: ParsedSource.notificationPush,
    );

    if (parsed == null) return;

    // Ajouter à la file d'attente
    final added = await _queue.push(parsed);
    if (added != null) {
      SikaLogger.info(
        'Notification transaction detected: ${parsed.operatorLabel} '
        '${parsed.type} ${parsed.amount} FCFA',
        tag: _tag,
      );

      // Afficher une notification locale discrète
      await _showDetectionNotification(parsed);
    }
  }

  /// Affiche une notification locale quand une transaction est détectée
  Future<void> _showDetectionNotification(ParsedTransaction tx) async {
    final emoji = tx.isIncome ? '📥' : '📤';
    final sign = tx.isIncome ? '+' : '-';
    final formattedAmount = _formatAmount(tx.amount);

    await _localNotifications.show(
      _notifIdBase + DateTime.now().millisecondsSinceEpoch % 1000,
      '$emoji Transaction détectée — ${tx.operatorLabel}',
      '$sign $formattedAmount FCFA · ${tx.description}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Détection automatique',
          channelDescription:
              'Notifications quand une transaction est détectée automatiquement',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_stat_notification',
        ),
      ),
    );
  }

  /// Crée le channel de notification Android pour les alertes de détection
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Détection automatique',
          description:
              'Notifications quand une transaction est détectée automatiquement',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Arrête tous les listeners
  void _stopListeners() {
    _notifChannel.setMethodCallHandler(null);
    _smsListener.stopListening();
  }

  /// Formate un montant en FCFA avec des espaces comme séparateurs de milliers
  String _formatAmount(int amount) {
    return amount
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  /// Libère les ressources
  void dispose() {
    _stopListeners();
    _queue.dispose();
  }

  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
}
