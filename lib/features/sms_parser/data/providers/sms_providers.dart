import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/sms_parser/data/services/sms_import_service.dart';
import 'package:sika_app/features/sms_parser/data/services/sms_parser_service.dart';

/// Provider pour le service de parsing SMS
///
/// Service stateless réutilisable pour parser les SMS.
final smsParserServiceProvider = Provider<SmsParserService>((ref) {
  return SmsParserService();
});

/// Provider pour le service d'import SMS
///
/// Dépend du parser et du repository de transactions.
/// Utiliser ce provider pour importer l'historique des SMS.
///
/// Exemple:
/// ```dart
/// final importService = ref.read(smsImportServiceProvider);
/// final result = await importService.syncMessagesFromInbox();
/// ```
final smsImportServiceProvider = Provider<SmsImportService>((ref) {
  final parser = ref.watch(smsParserServiceProvider);
  final repository = ref.watch(transactionRepositoryProvider);
  return SmsImportService(parser, repository);
});

/// État de l'import SMS en cours
class SmsImportState {
  final bool isImporting;
  final SmsImportResult? lastResult;
  final String? errorMessage;

  const SmsImportState({
    this.isImporting = false,
    this.lastResult,
    this.errorMessage,
  });

  SmsImportState copyWith({
    bool? isImporting,
    SmsImportResult? lastResult,
    String? errorMessage,
  }) {
    return SmsImportState(
      isImporting: isImporting ?? this.isImporting,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier pour gérer l'état de l'import SMS
class SmsImportNotifier extends StateNotifier<SmsImportState> {
  final SmsImportService _importService;

  SmsImportNotifier(this._importService) : super(const SmsImportState());

  /// Lance l'import des SMS depuis la boîte de réception
  Future<SmsImportResult> importFromInbox({int daysBack = 90}) async {
    state = state.copyWith(isImporting: true, errorMessage: null);

    try {
      final result = await _importService.syncMessagesFromInbox(
        daysBack: daysBack,
      );
      state = state.copyWith(
        isImporting: false,
        lastResult: result,
        errorMessage: result.errors.isNotEmpty ? result.errors.first : null,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isImporting: false, errorMessage: 'Erreur: $e');
      rethrow;
    }
  }

  /// Import rapide des SMS récents (dernières 24h)
  Future<SmsImportResult> importRecent() async {
    state = state.copyWith(isImporting: true, errorMessage: null);

    try {
      final result = await _importService.syncRecentMessages();
      state = state.copyWith(isImporting: false, lastResult: result);
      return result;
    } catch (e) {
      state = state.copyWith(isImporting: false, errorMessage: 'Erreur: $e');
      rethrow;
    }
  }
}

/// Provider pour le notifier d'import SMS
///
/// Gère l'état de l'import (en cours, résultat, erreurs).
///
/// Exemple:
/// ```dart
/// // Lancer un import
/// await ref.read(smsImportNotifierProvider.notifier).importFromInbox();
///
/// // Lire l'état
/// final state = ref.watch(smsImportNotifierProvider);
/// if (state.isImporting) {
///   return CircularProgressIndicator();
/// }
/// ```
final smsImportNotifierProvider =
    StateNotifierProvider<SmsImportNotifier, SmsImportState>((ref) {
      final importService = ref.watch(smsImportServiceProvider);
      return SmsImportNotifier(importService);
    });
