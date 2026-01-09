import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    debugPrint(
      '✅ [Transactions] Added manual transaction ${txId} - sync handled by AutoSyncService',
    );
  }

  /// Lie rétroactivement les transactions existantes aux comptes
  /// basé sur le champ smsSender
  Future<int> linkExistingTransactionsToAccounts() async {
    int linkedCount = 0;

    // Récupère les transactions sans accountId
    final transactions = await (_db.select(
      _db.transactionsTable,
    )..where((t) => t.accountId.isNull())).get();

    debugPrint(
      '🔗 [LinkAccounts] Found ${transactions.length} transactions without accountId',
    );

    for (final tx in transactions) {
      if (tx.smsSender == null) continue;

      // Détermine l'opérateur depuis le smsSender stocké
      String? accountName;
      final sender = tx.smsSender!.toUpperCase();

      if (sender.contains('AIRTEL') || sender == 'AIRTEL_MONEY') {
        accountName = 'Airtel Money';
      } else if (sender.contains('MOOV') || sender == 'MOOV_MONEY') {
        accountName = 'Moov Money';
      } else if (sender.contains('UBA')) {
        accountName = 'UBA';
      }

      if (accountName == null) continue;

      // Cherche le compte correspondant
      final account =
          await (_db.select(_db.accountsTable)
                ..where((a) => a.name.equals(accountName!))
                ..where((a) => a.isActive.equals(true)))
              .getSingleOrNull();

      if (account != null) {
        // Met à jour la transaction avec l'accountId
        await (_db.update(
          _db.transactionsTable,
        )..where((t) => t.id.equals(tx.id))).write(
          TransactionsTableCompanion(
            accountId: Value(account.id),
            updatedAt: Value(DateTime.now()),
          ),
        );
        linkedCount++;
        debugPrint(
          '✅ [LinkAccounts] Linked tx ${tx.id.substring(0, 8)} to ${account.name}',
        );
      }
    }

    debugPrint('🔗 [LinkAccounts] Total linked: $linkedCount');
    return linkedCount;
  }

  @override
  Future<void> updateTransaction(
    String id,
    TransactionsTableCompanion updates,
  ) async {
    // Ajoute la date de mise à jour
    final updatesWithTimestamp = updates.copyWith(
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value(0), // Marque comme à re-synchroniser
    );

    // 1. Met à jour localement
    await (_db.update(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).write(updatesWithTimestamp);

    // 2. Met à jour dans Supabase
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        // Récupère la transaction mise à jour pour avoir toutes les valeurs
        final tx = await getTransactionById(id);
        if (tx != null) {
          await supabase.from('transactions').upsert({
            'id': tx.id,
            'user_id': userId,
            'amount': tx.amount,
            'type': tx.type,
            'merchant_name': tx.merchantName,
            'date': tx.date.toIso8601String(),
            'sync_status': 1,
            'updated_at': DateTime.now().toIso8601String(),
          });
          // Marque comme synchronisé localement
          await markAsSynced(id);
          debugPrint('✅ [Transactions] Updated and synced $id to Supabase');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Transactions] Update sync failed (will retry): $e');
    }
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
    // 1. Supprime dans Supabase d'abord
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('transactions').delete().eq('id', id);
        debugPrint('✅ [Transactions] Deleted $id from Supabase');
      }
    } catch (e) {
      debugPrint('⚠️ [Transactions] Delete from Supabase failed: $e');
    }

    // 2. Supprime localement
    await (_db.delete(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).go();
    debugPrint('✅ [Transactions] Deleted $id locally');
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
