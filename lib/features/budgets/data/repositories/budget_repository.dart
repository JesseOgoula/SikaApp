import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart' show databaseProvider, autoSyncService;
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Budget global mensuel avec ses sous-budgets
class GlobalBudget {
  final BudgetsTableData budget;
  final List<SubBudget> subBudgets;
  final double totalSpent;

  GlobalBudget({
    required this.budget,
    required this.subBudgets,
    required this.totalSpent,
  });

  double get amount => budget.amount;
  double get remaining => budget.amount - totalSpent;
  double get percentUsed =>
      budget.amount > 0 ? (totalSpent / budget.amount * 100) : 0;
  bool get isOverBudget => totalSpent > budget.amount;
  double get allocatedAmount =>
      subBudgets.fold(0.0, (sum, s) => sum + s.amount);
  double get unallocatedAmount => budget.amount - allocatedAmount;
}

/// Sous-budget d'un budget global
class SubBudget {
  final BudgetsTableData budget;
  final CategoriesTableData? category;
  final double currentSpent;

  SubBudget({required this.budget, this.category, required this.currentSpent});

  double get amount => budget.amount;
  String get categoryName => budget.categoryName;
  String get categoryId => budget.categoryId;
  double get percentUsed => amount > 0 ? (currentSpent / amount * 100) : 0;
  bool get isOverBudget => currentSpent > amount;
  double get remaining => amount - currentSpent;
}

/// Provider pour le repository de budgets
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetRepository(db);
});

/// Provider pour le budget global mensuel
final globalBudgetProvider = StreamProvider<GlobalBudget?>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(budgetRepositoryProvider);

  return db.select(db.budgetsTable).watch().asyncMap((_) async {
    return await repo.getGlobalBudgetWithDetails();
  });
});

/// Repository pour gérer le budget global mensuel
class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  /// Créer ou mettre à jour le budget global mensuel
  Future<String> createOrUpdateGlobalBudget(double amount) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Vérifier si un budget global existe déjà pour ce mois
    final existing =
        await (_db.select(_db.budgetsTable)
              ..where((b) => b.categoryId.equals('global'))
              ..where((b) => b.isActive.equals(true)))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.budgetsTable,
      )..where((b) => b.id.equals(existing.id))).write(
        BudgetsTableCompanion(
          amount: Value(amount),
          syncStatus: const Value(0),
          updatedAt: Value(now),
        ),
      );
      autoSyncService?.forceSync();
      return existing.id;
    } else {
      final id = const Uuid().v4();
      await _db
          .into(_db.budgetsTable)
          .insert(
            BudgetsTableCompanion.insert(
              id: id,
              categoryId: 'global',
              categoryName: 'Budget Mensuel',
              amount: amount,
              startDate: startOfMonth,
              endDate: Value(endOfMonth),
              syncStatus: const Value(0),
            ),
          );
      autoSyncService?.forceSync();
      XPService().awardXP(ActionType.createBudget);
      return id;
    }
  }

  /// Ajouter ou mettre à jour un sous-budget
  Future<void> addOrUpdateSubBudget({
    required String parentBudgetId,
    required String categoryId,
    required String categoryName,
    required double amount,
  }) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final existing =
        await (_db.select(_db.budgetsTable)
              ..where((b) => b.parentBudgetId.equals(parentBudgetId))
              ..where((b) => b.categoryId.equals(categoryId)))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.budgetsTable,
      )..where((b) => b.id.equals(existing.id))).write(
        BudgetsTableCompanion(
          amount: Value(amount),
          categoryName: Value(categoryName),
          syncStatus: const Value(0),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db
          .into(_db.budgetsTable)
          .insert(
            BudgetsTableCompanion.insert(
              id: const Uuid().v4(),
              categoryId: categoryId,
              categoryName: categoryName,
              parentBudgetId: Value(parentBudgetId),
              amount: amount,
              startDate: startOfMonth,
              endDate: Value(endOfMonth),
              syncStatus: const Value(0),
            ),
          );
    }
    autoSyncService?.forceSync();
  }

  /// Supprimer un sous-budget
  Future<void> removeSubBudget(String subBudgetId) async {
    // Supprimer de Supabase
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('budgets')
            .delete()
            .eq('id', subBudgetId)
            .eq('user_id', user.id);
      }
    } catch (_) {}

    await (_db.delete(
      _db.budgetsTable,
    )..where((b) => b.id.equals(subBudgetId))).go();
    autoSyncService?.forceSync();
  }

  /// Supprimer le budget global et tous ses sous-budgets
  Future<void> deleteGlobalBudget(String globalBudgetId) async {
    // Supprimer de Supabase d'abord
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Cascade delete supprimera les sous-budgets côté Supabase
        await Supabase.instance.client
            .from('budgets')
            .delete()
            .eq('id', globalBudgetId)
            .eq('user_id', user.id);
      }
    } catch (_) {}

    // Supprimer localement
    await (_db.delete(
      _db.budgetsTable,
    )..where((b) => b.parentBudgetId.equals(globalBudgetId))).go();
    await (_db.delete(
      _db.budgetsTable,
    )..where((b) => b.id.equals(globalBudgetId))).go();
    autoSyncService?.forceSync();
  }

  /// Récupérer le budget global actif avec tous ses sous-budgets et les dépenses
  Future<GlobalBudget?> getGlobalBudgetWithDetails() async {
    final globalBudget =
        await (_db.select(_db.budgetsTable)
              ..where((b) => b.categoryId.equals('global'))
              ..where((b) => b.isActive.equals(true)))
            .getSingleOrNull();

    if (globalBudget == null) return null;

    // Chercher les sous-budgets
    final subBudgetsData = await (_db.select(
      _db.budgetsTable,
    )..where((b) => b.parentBudgetId.equals(globalBudget.id))).get();

    // Charger les catégories
    final categories = await _db.select(_db.categoriesTable).get();
    final categoriesMap = {for (final c in categories) c.id: c};

    // Calculer les dépenses du mois
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final monthlyExpenses =
        await (_db.select(_db.transactionsTable)
              ..where((t) => t.type.equals('expense'))
              ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth)))
            .get();

    // Dépenses totales
    final totalSpent = monthlyExpenses.fold<double>(
      0,
      (sum, tx) => sum + tx.amount,
    );

    // Dépenses par catégorie
    final expensesByCategory = <String, double>{};
    for (final tx in monthlyExpenses) {
      final catId = tx.categoryId ?? 'unknown';
      expensesByCategory[catId] = (expensesByCategory[catId] ?? 0) + tx.amount;
    }

    // Construire les sous-budgets
    final subBudgets = subBudgetsData.map((sb) {
      return SubBudget(
        budget: sb,
        category: categoriesMap[sb.categoryId],
        currentSpent: expensesByCategory[sb.categoryId] ?? 0,
      );
    }).toList();

    subBudgets.sort((a, b) => b.percentUsed.compareTo(a.percentUsed));

    final result = GlobalBudget(
      budget: globalBudget,
      subBudgets: subBudgets,
      totalSpent: totalSpent,
    );

    return result;
  }
}
