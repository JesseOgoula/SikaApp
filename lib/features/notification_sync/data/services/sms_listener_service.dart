import 'dart:io';

import 'package:flutter/services.dart';

import 'package:sika_app/core/utils/logger.dart';
import 'package:sika_app/features/notification_sync/data/parsers/notification_parser.dart';
import 'package:sika_app/features/notification_sync/data/services/pending_transaction_queue.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// Service d'écoute des SMS financiers (Android uniquement)
///
/// Utilise un MethodChannel pour recevoir les SMS via un BroadcastReceiver natif.
/// Fonctionne en complément du NotificationListenerService pour les opérateurs
/// mobile money (Airtel Money, Moov Money) qui communiquent principalement par SMS.
class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._internal();

  factory SmsListenerService() => _instance;

  SmsListenerService._internal();

  static const String _tag = 'SMS_LISTENER';
  static const MethodChannel _channel = MethodChannel('sika/sms');

  bool _isListening = false;
  final PendingTransactionQueue _queue = PendingTransactionQueue();

  /// Démarre l'écoute des SMS entrants
  ///
  /// Android uniquement. Ne fait rien sur iOS.
  Future<void> startListening() async {
    if (!Platform.isAndroid) {
      SikaLogger.info('SMS listening not supported on iOS', tag: _tag);
      return;
    }

    if (_isListening) return;

    try {
      // Écouter les SMS entrants via le MethodChannel natif
      _channel.setMethodCallHandler(_handleMethodCall);
      _isListening = true;
      SikaLogger.info('SMS listener started', tag: _tag);
    } catch (e) {
      SikaLogger.error('Failed to start SMS listener: $e', tag: _tag);
    }
  }

  /// Arrête l'écoute des SMS
  void stopListening() {
    _channel.setMethodCallHandler(null);
    _isListening = false;
    SikaLogger.info('SMS listener stopped', tag: _tag);
  }

  /// Handler des appels depuis le code natif Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSmsReceived':
        final args = call.arguments as Map<dynamic, dynamic>;
        await _processSms(
          sender: args['sender'] as String? ?? '',
          body: args['body'] as String? ?? '',
        );
        break;
      default:
        SikaLogger.warn('Unknown SMS method: ${call.method}', tag: _tag);
    }
  }

  /// Traite un SMS reçu
  Future<void> _processSms({
    required String sender,
    required String body,
  }) async {
    SikaLogger.info('SMS received from: $sender', tag: _tag);

    // Vérifie rapidement si c'est un expéditeur financier connu
    if (!NotificationParser.isKnownFinancialSender(sender)) {
      return;
    }

    // Parse le SMS
    final parsed = NotificationParser.parseMessage(
      sender: sender,
      body: body,
      receivedAt: DateTime.now().toIso8601String(),
      source: ParsedSource.sms,
    );

    if (parsed == null) {
      SikaLogger.info('SMS from $sender not recognized as financial', tag: _tag);
      return;
    }

    // Ajouter à la file d'attente
    final added = await _queue.push(parsed);
    if (added != null) {
      SikaLogger.info(
        'SMS transaction detected: ${parsed.operatorLabel} '
        '${parsed.type} ${parsed.amount} FCFA',
        tag: _tag,
      );
    } else {
      SikaLogger.info('SMS transaction duplicate, ignored', tag: _tag);
    }
  }

  /// Vérifie si la permission SMS est accordée
  Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Demande la permission SMS
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get isListening => _isListening;
}
