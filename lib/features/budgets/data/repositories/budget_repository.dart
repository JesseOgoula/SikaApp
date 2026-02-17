import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Classe représentant un budget de catégorie avec les dépenses actuelles
class CategoryBudget {
  final CategoriesTableData category;
  final double budgetLimit;
  final double currentSpent;
  final double percentUsed;
  final bool isOverBudget;

  CategoryBudget({
    required this.category,
    required this.budgetLimit,
    required this.currentSpent,
  }) : percentUsed = budgetLimit > 0 ? (currentSpent / budgetLimit * 100) : 0,
       isOverBudget = currentSpent > budgetLimit;

  String get categoryName => category.name;
  String get iconKey => category.iconKey;
  String get color => category.color;
  double get remaining => budgetLimit - currentSpent;
}

/// Provider pour le repository de budgets
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetRepository(db);
});

/// Provider pour les budgets avec dépenses calculées (mois en cours)
final categoryBudgetsProvider = Provider<AsyncValue<List<CategoryBudget>>>((
  ref,
) {
  ref.keepAlive();

  final categoriesAsync = ref.watch(categoriesProvider);
  final transactionsAsync = ref.watch(transactionWithCategoryListProvider);

  return categoriesAsync.when(
    data: (categories) => transactionsAsync.when(
      data: (transactions) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        // Filtrer les transactions du mois en cours (dépenses uniquement)
        final monthlyExpenses = transactions
            .where(
              (t) =>
                  t.transaction.type == 'expense' &&
                  t.transaction.date.isAfter(
                    startOfMonth.subtract(const Duration(seconds: 1)),
                  ) &&
                  t.transaction.date.isBefore(
                    endOfMonth.add(const Duration(seconds: 1)),
                  ),
            )
            .toList();

        // Calculer les dépenses par catégorie
        final expensesByCategory = <String, double>{};
        for (final tx in monthlyExpenses) {
          final catId = tx.transaction.categoryId ?? 'unknown';
          expensesByCategory[catId] =
              (expensesByCategory[catId] ?? 0) + tx.transaction.amount;
        }

        // Créer les CategoryBudget pour les catégories avec un budget défini
        final budgets = categories
            .where((cat) => cat.budgetLimit != null && cat.budgetLimit! > 0)
            .map(
              (cat) => CategoryBudget(
                category: cat,
                budgetLimit: cat.budgetLimit!,
                currentSpent: expensesByCategory[cat.id] ?? 0,
              ),
            )
            .toList();

        // Trier par pourcentage utilisé (décroissant)
        budgets.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

        return AsyncValue.data(budgets);
      },
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    ),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Repository pour gérer les budgets par catégorie
class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  /// Définir le budget d'une catégorie
  Future<void> setCategoryBudget(String categoryId, double budgetLimit) async {
    await (_db.update(
      _db.categoriesTable,
    )..where((c) => c.id.equals(categoryId))).write(
      CategoriesTableCompanion(
        budgetLimit: Value(budgetLimit),
        syncStatus: const Value(0), // Marquer pour sync
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Award XP for creating budget
    XPService().awardXP(ActionType.createBudget);
  }

  /// Supprimer le budget d'une catégorie
  Future<void> removeCategoryBudget(String categoryId) async {
    await (_db.update(
      _db.categoriesTable,
    )..where((c) => c.id.equals(categoryId))).write(
      CategoriesTableCompanion(
        budgetLimit: const Value(null),
        syncStatus: const Value(0), // Marquer pour sync
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Récupérer toutes les catégories avec leur budget
  Future<List<CategoriesTableData>> getCategoriesWithBudgets() async {
    return await (_db.select(
      _db.categoriesTable,
    )..where((c) => c.budgetLimit.isNotNull())).get();
  }

  /// Récupérer les dépenses du mois pour une catégorie
  Future<double> getMonthlySpentForCategory(String categoryId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final expenses =
        await (_db.select(_db.transactionsTable)
              ..where((t) => t.categoryId.equals(categoryId))
              ..where((t) => t.type.equals('expense'))
              ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth)))
            .get();

    return expenses.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  /// Récupérer les dépenses d'un mois spécifique pour une catégorie
  Future<double> getSpentForCategoryInMonth(
    String categoryId,
    int year,
    int month,
  ) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final expenses =
        await (_db.select(_db.transactionsTable)
              ..where((t) => t.categoryId.equals(categoryId))
              ..where((t) => t.type.equals('expense'))
              ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth)))
            .get();

    return expenses.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  /// Helper: Marquer toutes les catégories pour synchronisation
  /// À utiliser une seule fois pour forcer la sync initiale
  Future<void> markAllCategoriesForSync() async {
    await _db.customUpdate(
      'UPDATE categories SET sync_status = 0',
      updates: {_db.categoriesTable},
    );
  }
}
