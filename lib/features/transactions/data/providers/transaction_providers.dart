import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:sika_app/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:sika_app/features/transactions/data/repositories/transaction_repository_impl.dart';

/// Provider pour le repository de transactions
///
/// Injecte automatiquement la base de données.
/// Utiliser ce provider pour toutes les opérations sur les transactions.
///
/// Exemple:
/// ```dart
/// final repo = ref.read(transactionRepositoryProvider);
/// await repo.addParsedTransaction(parsed);
/// ```
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepositoryImpl(db);
});

/// StreamProvider pour la liste de toutes les transactions
///
/// Écoute les modifications en temps réel de la base de données.
/// Utiliser avec `ref.watch()` dans un widget pour une mise à jour automatique.
///
/// Exemple:
/// ```dart
/// final transactionsAsync = ref.watch(transactionListProvider);
/// transactionsAsync.when(
///   data: (transactions) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Erreur: $err'),
/// );
/// ```
final transactionListProvider = StreamProvider<List<TransactionsTableData>>((
  ref,
) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchAllTransactions();
});

/// Provider pour les transactions d'un compte spécifique
///
/// Utilise un family provider pour passer l'accountId.
///
/// Exemple:
/// ```dart
/// final transactions = ref.watch(transactionsByAccountProvider('account-uuid'));
/// ```
final transactionsByAccountProvider =
    StreamProvider.family<List<TransactionsTableData>, String>((
      ref,
      accountId,
    ) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchTransactionsByAccount(accountId);
    });

/// Provider pour les transactions d'une période donnée
///
/// Utilise un record (startDate, endDate) comme paramètre.
///
/// Exemple:
/// ```dart
/// final thisMonth = ref.watch(transactionsByDateRangeProvider((
///   DateTime(2024, 1, 1),
///   DateTime(2024, 1, 31),
/// )));
/// ```
final transactionsByDateRangeProvider =
    StreamProvider.family<
      List<TransactionsTableData>,
      ({DateTime startDate, DateTime endDate})
    >((ref, dateRange) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchTransactionsByDateRange(
        dateRange.startDate,
        dateRange.endDate,
      );
    });

/// Provider pour les transactions en attente de synchronisation
///
/// Utilisé par le service de sync PowerSync.
final pendingSyncTransactionsProvider =
    FutureProvider<List<TransactionsTableData>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.getPendingSyncTransactions();
    });

/// Provider pour le nombre de transactions en attente de sync
///
/// Utile pour afficher un badge de notification.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final pending = await ref.watch(pendingSyncTransactionsProvider.future);
  return pending.length;
});
