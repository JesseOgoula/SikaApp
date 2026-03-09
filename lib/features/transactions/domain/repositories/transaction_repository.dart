import '../../../../core/database/app_database.dart';
import '../../../analytics/domain/entities/category_stat.dart';
import '../../../analytics/domain/entities/daily_summary.dart';

/// Interface du repository de transactions
///
/// Définit le contrat pour l'accès aux données de transactions.
/// L'implémentation concrète utilise Drift (SQLite).
///
/// Cette abstraction permet:
/// - De tester facilement avec des mocks
/// - De changer l'implémentation sans impacter le domain
/// - De respecter le principe d'inversion de dépendance (SOLID)
abstract class TransactionRepository {
  /// Écoute toutes les transactions en temps réel
  ///
  /// Retourne un Stream qui émet la liste mise à jour
  /// à chaque modification de la base de données.
  /// Triées par date décroissante (plus récentes en premier).
  Stream<List<TransactionsTableData>> watchAllTransactions();

  /// Écoute toutes les transactions avec leurs catégories jointes
  ///
  /// Retourne un Stream de TransactionWithCategory pour afficher
  /// les icônes et couleurs de catégorie dans l'UI.
  Stream<List<TransactionWithCategory>> watchTransactionsWithCategories();

  /// Écoute les transactions d'un compte spécifique
  ///
  /// [accountId] : UUID du compte à filtrer
  Stream<List<TransactionsTableData>> watchTransactionsByAccount(
    String accountId,
  );

  /// Écoute les transactions d'une période donnée
  ///
  /// [startDate] : Date de début (incluse)
  /// [endDate] : Date de fin (incluse)
  Stream<List<TransactionsTableData>> watchTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Récupère une transaction par son ID
  ///
  /// Retourne `null` si non trouvée.
  Future<TransactionsTableData?> getTransactionById(String id);

  /// Ajoute une transaction manuelle (saisie utilisateur)
  ///
  /// [transaction] : Companion Drift avec tous les champs
  Future<void> addManualTransaction(TransactionsTableCompanion transaction);

  /// Met à jour une transaction existante
  ///
  /// [id] : UUID de la transaction
  /// [updates] : Champs à mettre à jour
  Future<void> updateTransaction(String id, TransactionsTableCompanion updates);

  /// Met à jour la catégorie d'une transaction
  ///
  /// Utilisé par le Smart Labeling IA et les corrections utilisateur.
  /// [isAiCategorized] indique si c'est l'IA qui a assigné la catégorie.
  Future<void> updateCategory(
    String id,
    String categoryId, {
    bool isAiCategorized = false,
  });

  /// Supprime une transaction
  ///
  /// [id] : UUID de la transaction à supprimer
  Future<void> deleteTransaction(String id);

  /// Vérifie si une transaction existe par son external_id
  ///
  /// Utilisé pour la déduplication des transactions.
  Future<bool> existsByExternalId(String externalId);

  /// Récupère les transactions en attente de synchronisation
  ///
  /// Retourne les transactions avec `sync_status = 0`.
  Future<List<TransactionsTableData>> getPendingSyncTransactions();

  /// Marque une transaction comme synchronisée
  ///
  /// Met `sync_status = 1`.
  Future<void> markAsSynced(String id);

  /// Marque une liste de transactions comme synchronisées
  Future<void> markMultipleAsSynced(List<String> ids);

  Future<List<CategoryStat>> getExpensesByCategory(DateTime month);

  /// Récupère les dépenses groupées par catégorie pour une période donnée
  Future<List<CategoryStat>> getExpensesByCategoryRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Récupère le résumé quotidien des transactions pour un mois
  Future<List<DailySummary>> getDailySummary(DateTime month);

  /// Récupère le résumé quotidien pour une période donnée
  Future<List<DailySummary>> getDailySummaryRange(
    DateTime startDate,
    DateTime endDate,
  );

  /// Récupère le total des revenus pour un mois
  Future<double> getTotalIncome(DateTime month);

  /// Récupère le total des revenus pour une période donnée
  Future<double> getTotalIncomeRange(DateTime startDate, DateTime endDate);

  /// Récupère le total des dépenses pour un mois
  Future<double> getTotalExpense(DateTime month);

  /// Récupère le total des dépenses pour une période donnée
  Future<double> getTotalExpenseRange(DateTime startDate, DateTime endDate);

  /// Récupère le total des économies (cat-epargne) pour une période donnée
  Future<double> getTotalSavingsRange(DateTime startDate, DateTime endDate);

  /// Récupère le total de tous les revenus depuis la création du compte
  Future<double> getTotalIncomeAllTime();

  /// Récupère le total de toutes les dépenses depuis la création du compte
  Future<double> getTotalExpenseAllTime();

  /// Écoute le total de tous les revenus en temps réel
  Stream<double> watchTotalIncomeAllTime();

  /// Écoute le total de toutes les dépenses en temps réel
  Stream<double> watchTotalExpenseAllTime();
}
