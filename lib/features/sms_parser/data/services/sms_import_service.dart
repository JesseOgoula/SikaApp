import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sika_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:sika_app/features/sms_parser/data/services/sms_parser_service.dart';

/// Résultat de l'import des SMS
class SmsImportResult {
  /// Nombre de SMS analysés
  final int totalAnalyzed;

  /// Nombre de transactions importées avec succès
  final int imported;

  /// Nombre de doublons ignorés
  final int duplicatesSkipped;

  /// Nombre de SMS non reconnus (non financiers)
  final int unrecognized;

  /// Erreurs rencontrées (si any)
  final List<String> errors;

  const SmsImportResult({
    required this.totalAnalyzed,
    required this.imported,
    required this.duplicatesSkipped,
    required this.unrecognized,
    this.errors = const [],
  });

  @override
  String toString() {
    return 'SmsImportResult(analyzed: $totalAnalyzed, imported: $imported, '
        'duplicates: $duplicatesSkipped, unrecognized: $unrecognized)';
  }
}

/// Service d'import en masse des SMS depuis la boîte de réception
class SmsImportService {
  final SmsParserService _parserService;
  final TransactionRepository _repository;
  final SmsQuery _smsQuery;

  SmsImportService(this._parserService, this._repository, {SmsQuery? smsQuery})
    : _smsQuery = smsQuery ?? SmsQuery();

  /// Vérifie si la permission SMS est accordée
  Future<bool> hasPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  /// Demande la permission SMS à l'utilisateur
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Importe les SMS depuis la boîte de réception
  Future<SmsImportResult> syncMessagesFromInbox({
    int? maxMessages,
    int daysBack = 90,
  }) async {
    // 1. Vérifie/demande la permission
    if (!(await hasPermission())) {
      final granted = await requestPermission();
      if (!granted) {
        return const SmsImportResult(
          totalAnalyzed: 0,
          imported: 0,
          duplicatesSkipped: 0,
          unrecognized: 0,
          errors: ['Permission SMS refusée'],
        );
      }
    }

    // 2. Récupère les SMS de la boîte de réception
    final List<SmsMessage> messages;
    try {
      messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: maxMessages,
      );
    } catch (e) {
      return SmsImportResult(
        totalAnalyzed: 0,
        imported: 0,
        duplicatesSkipped: 0,
        unrecognized: 0,
        errors: ['Erreur lors de la lecture des SMS: $e'],
      );
    }

    // 3. Filtre par date (DÉFENSIF - pas de !)
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));
    final filteredMessages = messages.where((sms) {
      final date = sms.date;
      if (date == null) return false;
      return date.isAfter(cutoffDate);
    }).toList();

    // 4. Analyse et importe
    int imported = 0;
    int duplicatesSkipped = 0;
    int unrecognized = 0;
    final errors = <String>[];

    for (final sms in filteredMessages) {
      // DÉFENSIF: Utilise des variables locales pour éviter les !
      final sender = sms.sender ?? '';
      final body = sms.body ?? '';

      // Ignore les SMS sans expéditeur ou corps valide
      if (sender.isEmpty || body.isEmpty) {
        continue;
      }

      // Pré-filtre rapide : est-ce un SMS financier potentiel ?
      if (!_parserService.isFinancialSms(sender, body)) {
        continue;
      }

      // Parse le SMS (DÉFENSIF - pas de !)
      final parsed = _parserService.parseSms(
        sender,
        body,
        receivedAt: sms.date,
      );

      if (parsed == null) {
        unrecognized++;
        continue;
      }

      // Tente d'insérer (la déduplication est gérée par le repository)
      try {
        final wasInserted = await _repository.addParsedTransaction(parsed);
        if (wasInserted) {
          imported++;
        } else {
          duplicatesSkipped++;
        }
      } catch (e) {
        errors.add('Erreur insertion: $e');
      }
    }

    return SmsImportResult(
      totalAnalyzed: filteredMessages.length,
      imported: imported,
      duplicatesSkipped: duplicatesSkipped,
      unrecognized: unrecognized,
      errors: errors,
    );
  }

  /// Importe uniquement les nouveaux SMS depuis le dernier import
  Future<SmsImportResult> syncRecentMessages() async {
    return syncMessagesFromInbox(daysBack: 1, maxMessages: 100);
  }
}
