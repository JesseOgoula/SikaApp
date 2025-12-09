/// Transactions Feature
///
/// Module de gestion des transactions financières.
///
/// Ce module fournit:
/// - Repository pour l'accès aux données (Drift/SQLite)
/// - Providers Riverpod pour l'injection de dépendances
/// - Streams réactifs pour l'UI
///
/// Usage:
/// ```dart
/// import 'package:sika_app/features/transactions/transactions.dart';
///
/// // Dans un widget ConsumerWidget
/// final transactions = ref.watch(transactionListProvider);
///
/// // Pour ajouter une transaction
/// final repo = ref.read(transactionRepositoryProvider);
/// await repo.addParsedTransaction(parsedTx);
/// ```
library;

// Domain
export 'domain/repositories/transaction_repository.dart';

// Data
export 'data/repositories/transaction_repository_impl.dart';
export 'data/providers/transaction_providers.dart';
