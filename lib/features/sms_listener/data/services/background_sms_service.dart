import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:permission_handler/permission_handler.dart';

// Imports absolus avec le nom du package
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/notifications/notification_controller.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/features/sms_parser/domain/entities/parsed_transaction.dart';
import 'package:sika_app/features/sms_parser/data/services/sms_parser_service.dart';
import 'package:sika_app/features/sms_parser/data/services/sms_parser_worker.dart';

/// Service d'écoute des SMS avec polling intelligent
///
/// Ce service:
/// - Polling périodique des nouveaux SMS via flutter_sms_inbox
/// - Parse les SMS financiers
/// - Enregistre les transactions selon le mode choisi:
///   - Auto-save: Enregistrement direct + notification simple
///   - Manuel: Enregistrement PENDING + notification actionnable
class BackgroundSmsService {
  final SmsQuery _smsQuery = SmsQuery();
  final SmsParserService _parser = SmsParserService();
  final SettingsService _settings = SettingsService();
  final Uuid _uuid = const Uuid();

  AppDatabase? _database;
  Timer? _pollingTimer;
  DateTime? _lastCheckTime;
  bool _isRunning = false;

  /// Singleton
  static final BackgroundSmsService _instance =
      BackgroundSmsService._internal();
  factory BackgroundSmsService() => _instance;
  BackgroundSmsService._internal();

  /// Injecte la base de données
  void setDatabase(AppDatabase db) {
    _database = db;
    NotificationController.setDatabase(db);
  }

  /// Démarre le polling des SMS
  Future<void> startListening({int intervalSeconds = 30}) async {
    if (_isRunning) return;

    // Initialise les settings
    await _settings.init();

    // Marque l'heure de début pour ne traiter que les nouveaux SMS
    _lastCheckTime = DateTime.now();

    // Démarre le timer de polling
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _checkForNewSms(),
    );

    _isRunning = true;
  }

  /// Arrête le polling
  void stopListening() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isRunning = false;
  }

  /// Vérifie manuellement les nouveaux SMS (pour test)
  Future<int> checkNow() async {
    return await _checkForNewSms();
  }

  /// Synchronise tous les SMS manuellement (sans limite de temps)
  ///
  /// Cette méthode lit TOUS les SMS et les traite, en ignorant
  /// les doublons grâce à l'external_id stocké en base.
  Future<int> syncSmsNow() async {
    if (_database == null) return 0;

    // Demande la permission SMS si nécessaire
    final status = await Permission.sms.status;
    if (!status.isGranted) {
      final result = await Permission.sms.request();
      if (!result.isGranted) return 0;
    }

    try {
      // Récupère TOUS les SMS (max 1000 pour éviter les timeouts)
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 1000,
      );

      int processed = 0;

      for (final sms in messages) {
        // Pas de filtre par date - on traite tous les SMS
        final result = await _processSms(sms);
        if (result) processed++;
      }

      print(
        '📬 [BackgroundSmsService] Sync terminée: $processed transactions importées',
      );
      return processed;
    } catch (e) {
      print('❌ [BackgroundSmsService] Erreur sync SMS: $e');
      return 0;
    }
  }

  /// Vérifie s'il y a de nouveaux SMS
  Future<int> _checkForNewSms() async {
    if (_database == null) return 0;

    // Vérifie la permission avant tout pour éviter un crash
    if (!await Permission.sms.isGranted) {
      print(
        '⚠️ [BackgroundSmsService] Permission SMS non accordée. Polling ignoré.',
      );
      return 0;
    }

    try {
      // Récupère les SMS reçus depuis le dernier check
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 20,
      );

      int processed = 0;

      for (final sms in messages) {
        // Ignore les SMS avant notre dernière vérification
        if (_lastCheckTime != null &&
            sms.date != null &&
            sms.date!.isBefore(_lastCheckTime!)) {
          continue;
        }

        final result = await _processSms(sms);
        if (result) processed++;
      }

      // Met à jour l'heure du dernier check
      _lastCheckTime = DateTime.now();

      return processed;
    } catch (e) {
      print('Erreur lors du check SMS: $e');
      return 0;
    }
  }

  /// Traite un SMS reçu
  Future<bool> _processSms(SmsMessage message) async {
    final db = _database;
    if (db == null) return false;

    final sender = message.address ?? '';
    final body = message.body ?? '';

    if (sender.isEmpty || body.isEmpty) return false;

    // Vérifie si c'est un SMS financier
    if (!_parser.isFinancialSms(sender, body)) return false;

    // Parse le SMS via un isolat pour ne pas bloquer l'UI
    final parsed = await SmsParserWorker.parse(
      sender,
      body,
      date: message.date,
    );

    if (parsed == null) return false;

    // Vérifie les doublons via external_id
    if (parsed.transactionId.isNotEmpty) {
      final exists = await db.transactionExists(parsed.transactionId);
      if (exists) return false;
    }

    // Récupère le mode d'enregistrement
    final isAutoSave = await _settings.isAutoSaveEnabled();

    if (isAutoSave) {
      await _saveAutomatic(parsed);
    } else {
      await _saveManual(parsed);
    }

    return true;
  }

  /// Traite un SMS reçu en temps réel (appelé par RealtimeSmsService)
  ///
  /// Cette méthode est publique pour permettre l'intégration avec
  /// le service d'écoute en temps réel.
  Future<bool> processRealTimeSms(
    String sender,
    String body,
    DateTime? date,
  ) async {
    final db = _database;
    if (db == null) return false;

    if (sender.isEmpty || body.isEmpty) return false;

    // Vérifie si c'est un SMS financier
    if (!_parser.isFinancialSms(sender, body)) return false;

    // Parse le SMS via un isolat pour ne pas bloquer l'UI
    final parsed = await SmsParserWorker.parse(sender, body, date: date);

    if (parsed == null) return false;

    // Vérifie les doublons via external_id
    if (parsed.transactionId.isNotEmpty) {
      final exists = await db.transactionExists(parsed.transactionId);
      if (exists) return false;
    }

    // Récupère le mode d'enregistrement
    final isAutoSave = await _settings.isAutoSaveEnabled();

    if (isAutoSave) {
      await _saveAutomatic(parsed);
    } else {
      await _saveManual(parsed);
    }

    return true;
  }

  /// Mode Auto-Save: Enregistre directement + notification simple
  Future<void> _saveAutomatic(ParsedTransaction parsed) async {
    final db = _database;
    if (db == null) return;

    final transactionId = _uuid.v4();
    final accountId = await _getAccountIdForOperator(parsed.operator);

    await db
        .into(db.transactionsTable)
        .insert(
          TransactionsTableCompanion(
            id: Value(transactionId),
            amount: Value(parsed.amount),
            type: Value(_typeToString(parsed.type)),
            merchantName: Value(parsed.merchantName),
            accountId: accountId != null
                ? Value(accountId)
                : const Value.absent(),
            date: Value(parsed.date),
            smsSender: Value(_operatorToString(parsed.operator)),
            smsRawContent: Value(parsed.rawSmsContent),
            externalId: Value(
              parsed.transactionId.isNotEmpty
                  ? parsed.transactionId
                  : 'sms_${parsed.amount}_${parsed.date.millisecondsSinceEpoch}_${parsed.rawSmsContent.hashCode}',
            ),
            isAiCategorized: const Value(false),
            syncStatus: const Value(0),
            validationStatus: const Value(1), // VALIDATED
          ),
        );

    await NotificationController.showSuccessNotification(
      amount: parsed.amount,
      merchant: parsed.merchantName,
      isExpense: parsed.type == TransactionType.expense,
    );
  }

  /// Mode Manuel: Enregistre en PENDING + notification actionnable
  Future<void> _saveManual(ParsedTransaction parsed) async {
    final db = _database;
    if (db == null) return;

    final transactionId = _uuid.v4();
    final accountId = await _getAccountIdForOperator(parsed.operator);

    await db
        .into(db.transactionsTable)
        .insert(
          TransactionsTableCompanion(
            id: Value(transactionId),
            amount: Value(parsed.amount),
            type: Value(_typeToString(parsed.type)),
            merchantName: Value(parsed.merchantName),
            accountId: accountId != null
                ? Value(accountId)
                : const Value.absent(),
            date: Value(parsed.date),
            smsSender: Value(_operatorToString(parsed.operator)),
            smsRawContent: Value(parsed.rawSmsContent),
            externalId: Value(
              parsed.transactionId.isNotEmpty
                  ? parsed.transactionId
                  : 'sms_${parsed.amount}_${parsed.date.millisecondsSinceEpoch}_${parsed.rawSmsContent.hashCode}',
            ),
            isAiCategorized: const Value(false),
            syncStatus: const Value(0),
            validationStatus: const Value(0), // PENDING
          ),
        );

    await NotificationController.showActionableNotification(
      transactionId: transactionId,
      amount: parsed.amount,
      merchant: parsed.merchantName,
      isExpense: parsed.type == TransactionType.expense,
    );
  }

  /// Trouve le compte correspondant à l'opérateur
  Future<String?> _getAccountIdForOperator(MobileOperator operator) async {
    final db = _database;
    if (db == null) return null;

    String accountName;
    switch (operator) {
      case MobileOperator.airtelMoney:
        accountName = 'Airtel Money';
        break;
      case MobileOperator.moovMoney:
        accountName = 'Moov Money';
        break;
      case MobileOperator.uba:
        accountName = 'UBA';
        break;
      case MobileOperator.unknown:
        return null;
    }

    final account =
        await (db.select(db.accountsTable)
              ..where((a) => a.name.equals(accountName))
              ..where((a) => a.isActive.equals(true)))
            .getSingleOrNull();

    return account?.id;
  }

  String _typeToString(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'expense';
      case TransactionType.income:
        return 'income';
      case TransactionType.transfer:
        return 'transfer';
    }
  }

  String _operatorToString(MobileOperator operator) {
    switch (operator) {
      case MobileOperator.airtelMoney:
        return 'AIRTEL_MONEY';
      case MobileOperator.moovMoney:
        return 'MOOV_MONEY';
      case MobileOperator.uba:
        return 'UBA';
      case MobileOperator.unknown:
        return 'UNKNOWN';
    }
  }
}
