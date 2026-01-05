import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:easy_sms_receiver/easy_sms_receiver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/sms_listener/data/services/background_sms_service.dart';
import 'package:sika_app/features/sms_listener/data/services/pending_sms_storage.dart';

/// Service d'écoute SMS en temps réel avec Foreground Service
///
/// Architecture:
/// 1. Le foreground service (isolat séparé) écoute les SMS
/// 2. Les SMS reçus sont stockés dans SharedPreferences
/// 3. L'app principale traite les SMS au démarrage ou quand elle devient active
class RealtimeSmsService {
  static final RealtimeSmsService _instance = RealtimeSmsService._internal();
  factory RealtimeSmsService() => _instance;
  RealtimeSmsService._internal();

  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();

  bool _isInitialized = false;
  AppDatabase? _database;

  /// Configure et initialise le service d'arrière-plan
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _backgroundService.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          autoStartOnBoot: false, // Désactivé pour éviter les crash loops
          isForegroundMode: true,
          notificationChannelId: 'sika_sms_channel',
          initialNotificationTitle: 'SIKA - Détection SMS',
          initialNotificationContent: 'Initialisation...',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      _isInitialized = true;
      print('✅ [RealtimeSmsService] Configuration terminée');
    } catch (e) {
      print('❌ [RealtimeSmsService] Erreur configuration: $e');
    }
  }

  /// Démarre le service d'écoute SMS en temps réel
  Future<void> startService() async {
    // Vérifie les permissions
    final smsPermission = await Permission.sms.request();
    if (!smsPermission.isGranted) {
      print('⚠️ [RealtimeSmsService] Permission SMS refusée');
      throw Exception('Permission SMS requise');
    }

    final notificationPermission = await Permission.notification.request();
    if (!notificationPermission.isGranted) {
      print('⚠️ [RealtimeSmsService] Permission Notification refusée');
    }

    await initialize();
    await _backgroundService.startService();
    print('✅ [RealtimeSmsService] Service démarré');
  }

  /// Arrête le service
  Future<void> stopService() async {
    _backgroundService.invoke('stopService');
    print('⛔ [RealtimeSmsService] Service arrêté');
  }

  /// Vérifie si le service est en cours d'exécution
  Future<bool> isRunning() async {
    return await _backgroundService.isRunning();
  }

  /// Injecte la base de données et traite les SMS en attente
  Future<void> setDatabase(AppDatabase db) async {
    _database = db;
    BackgroundSmsService().setDatabase(db);

    // Traite les SMS en attente
    await processPendingSms();
  }

  /// Traite tous les SMS stockés en attente
  Future<void> processPendingSms() async {
    if (_database == null) return;

    final pendingSms = await PendingSmsStorage.getPendingSms();
    if (pendingSms.isEmpty) {
      print('ℹ️ [RealtimeSmsService] Aucun SMS en attente');
      return;
    }

    print(
      '📬 [RealtimeSmsService] Traitement de ${pendingSms.length} SMS en attente',
    );

    final bgService = BackgroundSmsService();
    for (final sms in pendingSms) {
      await bgService.processRealTimeSms(
        sms['sender'] as String,
        sms['body'] as String,
        sms['receivedAt'] as DateTime,
      );
    }

    // Efface les SMS traités
    await PendingSmsStorage.clearPendingSms();
    print('✅ [RealtimeSmsService] SMS en attente traités');
  }

  /// Met à jour le contenu de la notification
  void updateNotification(String title, String content) {
    _backgroundService.invoke('updateNotification', {
      'title': title,
      'content': content,
    });
  }
}

// ============= CALLBACKS TOP-LEVEL (requis pour isolat) =============

/// Clé pour SharedPreferences
const String _keyPendingSms = 'pending_sms_list';

/// Callback appelé quand le service démarre (Android)
/// IMPORTANT: S'exécute dans un isolat séparé, pas d'accès à la DB
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialise les bindings Flutter dans l'isolat
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // IMPACT: Affiche la notification immédiatement pour éviter le crash "CannotPostForegroundServiceNotificationException"
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'SIKA - Détection SMS',
      content: 'Service actif',
    );
  }

  final smsReceiver = EasySmsReceiver.instance;

  // Met en place l'écoute SMS en temps réel
  smsReceiver.listenIncomingSms(
    onNewMessage: (message) async {
      print('📨 [BackgroundService] SMS reçu de: ${message.address}');

      try {
        // Stocke le SMS directement dans SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final List<String> pending = prefs.getStringList(_keyPendingSms) ?? [];

        final smsData = jsonEncode({
          'sender': message.address ?? '',
          'body': message.body ?? '',
          'receivedAt': DateTime.now().toIso8601String(),
        });

        pending.add(smsData);
        await prefs.setStringList(_keyPendingSms, pending);
        print('📥 [BackgroundService] SMS stocké pour traitement');

        // Met à jour la notification
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'SIKA - SMS Détecté',
            content: '${pending.length} transaction(s) en attente',
          );
        }
      } catch (e) {
        print('❌ [BackgroundService] Erreur stockage SMS: $e');
      }
    },
  );

  // Écoute les commandes depuis l'app
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('updateNotification').listen((event) {
    if (event != null && service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: event['title'] ?? 'SIKA',
        content: event['content'] ?? 'En cours...',
      );
    }
  });

  // Met à jour la notification périodiquement
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final count = prefs.getStringList(_keyPendingSms)?.length ?? 0;
          final now = DateTime.now();
          service.setForegroundNotificationInfo(
            title: 'SIKA - Détection SMS Active',
            content: count > 0
                ? '$count SMS en attente • ${now.hour}:${now.minute.toString().padLeft(2, '0')}'
                : 'Dernière vérif: ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
          );
        } catch (e) {
          print('❌ [BackgroundService] Erreur mise à jour notif: $e');
        }
      }
    }
  });
}

/// Callback iOS en arrière-plan
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
