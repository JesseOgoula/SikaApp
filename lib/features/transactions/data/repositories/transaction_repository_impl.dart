import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/main.dart' show autoSyncService;
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/core/services/notification_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../analytics/domain/entities/category_stat.dart';
import '../../../analytics/domain/entities/daily_summary.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Implémentation du repository de transactions avec Drift (SQLite)
///
/// Cette classe gère:
/// - La persistance des transactions dans SQLite
/// - Les requêtes réactives (Streams)
/// - La synchronisation est gérée par AutoSyncService (connectivity-based)
class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  TransactionRepositoryImpl(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  // ==================== WATCH METHODS (STREAMS) ====================

  @override
  Stream<List<TransactionsTableData>> watchAllTransactions() {
    return (_db.select(
      _db.transactionsTable,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  @override
  Stream<List<TransactionWithCategory>> watchTransactionsWithCategories() {
    return _db.watchTransactionsWithCategories();
  }

  @override
  Stream<List<TransactionsTableData>> watchTransactionsByAccount(
    String accountId,
  ) {
    return (_db.select(_db.transactionsTable)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  @override
  Stream<List<TransactionsTableData>> watchTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return (_db.select(_db.transactionsTable)
          ..where((t) => t.date.isBetweenValues(startDate, endDate))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  // ==================== READ METHODS ====================

  @override
  Future<TransactionsTableData?> getTransactionById(String id) {
    return (_db.select(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<bool> existsByExternalId(String externalId) async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.externalId.equals(externalId));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  @override
  Future<List<TransactionsTableData>> getPendingSyncTransactions() {
    return (_db.select(
      _db.transactionsTable,
    )..where((t) => t.syncStatus.equals(0))).get();
  }

  // ==================== WRITE METHODS ====================

  @override
  Future<void> addManualTransaction(
    TransactionsTableCompanion transaction,
  ) async {
    // Assure qu'un ID est présent
    final txId = transaction.id.present ? transaction.id.value : _uuid.v4();
    final companion = transaction.id.present
        ? transaction
        : transaction.copyWith(id: Value(txId));

    // 1. Stocke localement dans Drift
    await _db.into(_db.transactionsTable).insert(companion);
    // 2. Déclenche la sync vers Supabase
    autoSyncService?.forceSync();

    // 3. Award XP for transaction
    XPService().awardXP(ActionType.addTransaction);

    // 3. Vérifie le solde après une dépense
    final txType = companion.type.present ? companion.type.value : '';
    if (txType == 'expense') {
      _checkLowBalance();
    }
  }

  /// Vérifie si le solde total est sous le seuil d'alerte et notifie l'utilisateur
  Future<void> _checkLowBalance() async {
    try {
      final prefs = NotificationPreferences();
      final threshold = await prefs.lowBalanceThreshold;

      // Calculer le solde total (comptes + transactions)
      final accounts = await _db.select(_db.accountsTable).get();
      double totalBalance = 0;
      for (final account in accounts) {
        totalBalance += account.balance;
      }

      // Ajouter les revenus et soustraire les dépenses
      final incomeQuery = _db.select(_db.transactionsTable)
        ..where((t) => t.type.equals('income'));
      final incomes = await incomeQuery.get();
      totalBalance += incomes.fold<double>(0, (sum, tx) => sum + tx.amount);

      final expenseQuery = _db.select(_db.transactionsTable)
        ..where((t) => t.type.equals('expense'));
      final expenses = await expenseQuery.get();
      totalBalance -= expenses.fold<double>(0, (sum, tx) => sum + tx.amount);

      if (totalBalance <= threshold) {
        await NotificationService().showLowBalanceAlert(
          currentBalance: totalBalance,
          threshold: threshold,
        );
      }
    } catch (e) {
      /* ignore */
    }
  }

  @override
  Future<void> updateTransaction(
    String id,
    TransactionsTableCompanion updates,
  ) async {
    // Ajoute la date de mise à jour et remet le syncStatus à pending
    final updatesWithTimestamp = updates.copyWith(
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value(0), // Marque comme à re-synchroniser
    );

    // Met à jour localement — AutoSyncService sync vers Supabase
    await (_db.update(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).write(updatesWithTimestamp);

    // Déclenche la sync
    autoSyncService?.forceSync();
  }

  @override
  Future<void> updateCategory(
    String id,
    String categoryId, {
    bool isAiCategorized = false,
  }) async {
    await (_db.update(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).write(
      TransactionsTableCompanion(
        categoryId: Value(categoryId),
        isAiCategorized: Value(isAiCategorized),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(0), // À re-synchroniser
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    // 1. Supprime localement d'abord (offline-first)
    await (_db.delete(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).go();

    // 2. Supprime dans Supabase en arrière-plan
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('transactions').delete().eq('id', id);
      }
    } catch (e) {
      // Si offline, la transaction reste sur Supabase
      // TODO: Implémenter une file d'attente de suppressions
    }
  }

  // ==================== SYNC METHODS ====================

  @override
  Future<void> markAsSynced(String id) async {
    await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(id)))
        .write(const TransactionsTableCompanion(syncStatus: Value(1)));
  }

  @override
  Future<void> markMultipleAsSynced(List<String> ids) async {
    await _db.batch((batch) {
      for (final id in ids) {
        batch.update(
          _db.transactionsTable,
          const TransactionsTableCompanion(syncStatus: Value(1)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  // ==================== STATISTICS METHODS ====================

  @override
  Future<List<CategoryStat>> getExpensesByCategory(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getExpensesByCategoryRange(startOfMonth, endOfMonth);
  }

  @override
  Future<List<CategoryStat>> getExpensesByCategoryRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Récupère toutes les dépenses de la période avec catégories
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ]);

    query.where(_db.transactionsTable.type.equals('expense'));
    query.where(_db.transactionsTable.categoryId.equals('cat-epargne').not());
    query.where(_db.transactionsTable.date.isBetweenValues(startDate, endDate));

    final results = await query.get();

    // Grouper par catégorie
    final Map<String, _CategoryAccumulator> grouped = {};
    double totalExpenses = 0;

    for (final row in results) {
      final tx = row.readTable(_db.transactionsTable);
      final cat = row.readTableOrNull(_db.categoriesTable);

      final categoryId = cat?.id ?? 'uncategorized';
      final categoryName = cat?.name ?? 'Non catégorisé';

      totalExpenses += tx.amount;

      if (grouped.containsKey(categoryId)) {
        grouped[categoryId]!.total += tx.amount;
      } else {
        grouped[categoryId] = _CategoryAccumulator(
          id: categoryId,
          name: categoryName,
          iconKey: cat?.iconKey,
          color: cat?.color,
          total: tx.amount,
        );
      }
    }

    // Calculer les pourcentages et trier
    final stats = grouped.values.map((acc) {
      return CategoryStat(
        categoryId: acc.id,
        categoryName: acc.name,
        iconKey: acc.iconKey,
        color: acc.color,
        totalAmount: acc.total,
        percentage: totalExpenses > 0 ? (acc.total / totalExpenses) * 100 : 0,
      );
    }).toList();

    // Trier par montant décroissant
    stats.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return stats;
  }

  // ==================== DAILY SUMMARY METHODS ====================

  @override
  Future<List<DailySummary>> getDailySummary(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getDailySummaryRange(startOfMonth, endOfMonth);
  }

  @override
  Future<List<DailySummary>> getDailySummaryRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.date.isBetweenValues(startDate, endDate));

    final transactions = await query.get();

    // Grouper par jour (clé : yyyy-MM-dd pour gérer plusieurs mois)
    final Map<String, _DailyAccumulator> dailyData = {};

    for (final tx in transactions) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      dailyData.putIfAbsent(
        key,
        () => _DailyAccumulator(
          date: DateTime(tx.date.year, tx.date.month, tx.date.day),
        ),
      );

      if (tx.type == 'income') {
        dailyData[key]!.income += tx.amount;
      } else if (tx.type == 'expense') {
        // Exclure l'épargne du total des dépenses journalières
        if (tx.categoryId != 'cat-epargne') {
          dailyData[key]!.expense += tx.amount;
        }
      }
    }

    // Convertir en liste triée
    final summaries = dailyData.values
        .map(
          (acc) => DailySummary(
            date: acc.date,
            totalIncome: acc.income,
            totalExpense: acc.expense,
          ),
        )
        .toList();

    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  @override
  Future<double> getTotalIncome(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getTotalIncomeRange(startOfMonth, endOfMonth);
  }

  @override
  Future<double> getTotalIncomeRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('income'))
      ..where((t) => t.date.isBetweenValues(startDate, endDate));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  @override
  Future<double> getTotalExpense(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return getTotalExpenseRange(startOfMonth, endOfMonth);
  }

  @override
  Future<double> getTotalExpenseRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.categoryId.equals('cat-epargne').not())
      ..where((t) => t.date.isBetweenValues(startDate, endDate));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  @override
  Future<double> getTotalSavingsRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.categoryId.equals('cat-epargne'))
      ..where((t) => t.date.isBetweenValues(startDate, endDate));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  /// Calcule le total de tous les revenus depuis la création du compte
  @override
  Future<double> getTotalIncomeAllTime() async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('income'));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  /// Calcule le total de toutes les dépenses depuis la création du compte
  @override
  Future<double> getTotalExpenseAllTime() async {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('expense'));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  @override
  Stream<double> watchTotalIncomeAllTime() {
    return (_db.select(_db.transactionsTable)
          ..where((t) => t.type.equals('income')))
        .watch()
        .map((txs) => txs.fold<double>(0, (sum, tx) => sum + tx.amount));
  }

  @override
  Stream<double> watchTotalExpenseAllTime() {
    return (_db.select(_db.transactionsTable)
          ..where((t) => t.type.equals('expense')))
        .watch()
        .map((txs) => txs.fold<double>(0, (sum, tx) => sum + tx.amount));
  }
}

/// Helper class pour accumuler les totaux par catégorie
class _CategoryAccumulator {
  final String id;
  final String name;
  final String? iconKey;
  final String? color;
  double total;

  _CategoryAccumulator({
    required this.id,
    required this.name,
    this.iconKey,
    this.color,
    required this.total,
  });
}

/// Helper class pour accumuler les totaux quotidiens
class _DailyAccumulator {
  final DateTime date;
  double income = 0.0;
  double expense = 0.0;

  _DailyAccumulator({required this.date});
}
