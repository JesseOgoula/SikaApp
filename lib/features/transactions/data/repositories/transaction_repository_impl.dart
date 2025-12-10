import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../analytics/domain/entities/category_stat.dart';
import '../../../analytics/domain/entities/daily_summary.dart';
import '../../../sms_parser/domain/entities/parsed_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Implémentation du repository de transactions avec Drift (SQLite)
///
/// Cette classe gère:
/// - La persistance des transactions dans SQLite
/// - La conversion ParsedTransaction → TransactionsTableCompanion
/// - La déduplication via external_id
/// - Les requêtes réactives (Streams)
class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  TransactionRepositoryImpl(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  // ==================== MAPPING HELPERS ====================

  /// Convertit un TransactionType enum en String pour stockage
  String _transactionTypeToString(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'expense';
      case TransactionType.income:
        return 'income';
      case TransactionType.transfer:
        return 'transfer';
    }
  }

  /// Convertit un MobileOperator enum en String pour stockage
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

  /// Convertit un ParsedTransaction en TransactionsTableCompanion
  ///
  /// Génère un nouvel UUID et mappe tous les champs correctement.
  TransactionsTableCompanion _parsedToCompanion(
    ParsedTransaction parsed,
    String? categoryId,
  ) {
    return TransactionsTableCompanion(
      id: Value(_uuid.v4()),
      amount: Value(parsed.amount),
      type: Value(_transactionTypeToString(parsed.type)),
      merchantName: Value(parsed.merchantName),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      accountId: const Value.absent(),
      date: Value(parsed.date),
      smsSender: Value(_operatorToString(parsed.operator)),
      smsRawContent: Value(parsed.rawSmsContent),
      externalId: Value(parsed.transactionId),
      isAiCategorized: const Value(false),
      syncStatus: const Value(0),
    );
  }

  /// Tente de deviner la catégorie basée sur les mots-clés
  Future<String?> _guessCategory(String merchant, String body) async {
    // Cas spécial: EBILLING -> Factures
    if (merchant.toUpperCase().contains('EBILLING') ||
        body.toUpperCase().contains('EBILLING')) {
      final factureCat = await (_db.select(
        _db.categoriesTable,
      )..where((c) => c.id.equals('cat-factures'))).getSingleOrNull();
      return factureCat?.id;
    }

    final categories = await _db.getAllCategories();
    final text = '$merchant $body'.toLowerCase();

    for (final cat in categories) {
      if (cat.keywordsJson != '{}') {
        // Note: Pour faire simple ici on parse manuellement car keywordsJson est une string
        // Dans l'idéal on aurait une méthode helper dans CategoriesTableData
        final keywordsLower = cat.keywordsJson.toLowerCase();
        // Hack simple: on cherche juste si le mot clé est présent dans le json brut
        // Amélioration: parser le JSON proprement
        // Mais pour l'instant on va utiliser les keywords hardcodés dans le seeding
        // qui correspondent à ce qu'on a mis dans AppDatabase
      }
    }

    // Approche simplifiée: Check direct des mots clés connus
    // Alimentation
    if (text.contains('boulangerie') ||
        text.contains('market') ||
        text.contains('mbolo') ||
        text.contains('cecado') ||
        text.contains('geant')) {
      return 'cat-alimentation';
    }
    // Transport
    if (text.contains('taxi') ||
        text.contains('total') ||
        text.contains('petro') ||
        text.contains('clando')) {
      return 'cat-transport';
    }
    // Factures
    if (text.contains('seeg') ||
        text.contains('canal') ||
        text.contains('edan') ||
        text.contains('startimes')) {
      return 'cat-factures';
    }
    // Santé
    if (text.contains('pharmacie') ||
        text.contains('hopital') ||
        text.contains('clinique')) {
      return 'cat-sante';
    }
    // Loisirs
    if (text.contains('netflix') ||
        text.contains('bar') ||
        text.contains('resto')) {
      return 'cat-loisirs';
    }

    return null;
  }

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
  Future<bool> addParsedTransaction(ParsedTransaction parsedTx) async {
    // DÉDUPLICATION : Vérifie si une transaction avec le même external_id existe
    if (parsedTx.transactionId.isNotEmpty) {
      final exists = await existsByExternalId(parsedTx.transactionId);
      if (exists) {
        // Transaction déjà présente, on ignore
        return false;
      }
    }

    // Devine la catégorie
    final categoryId = await _guessCategory(
      parsedTx.merchantName,
      parsedTx.rawSmsContent,
    );

    // Convertit et insère la nouvelle transaction
    final companion = _parsedToCompanion(parsedTx, categoryId);
    await _db.into(_db.transactionsTable).insert(companion);
    return true;
  }

  @override
  Future<void> addManualTransaction(
    TransactionsTableCompanion transaction,
  ) async {
    // Assure qu'un ID est présent
    final companion = transaction.id.present
        ? transaction
        : transaction.copyWith(id: Value(_uuid.v4()));

    await _db.into(_db.transactionsTable).insert(companion);
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

    await (_db.update(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).write(updatesWithTimestamp);
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
    await (_db.delete(
      _db.transactionsTable,
    )..where((t) => t.id.equals(id))).go();
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

    // Récupère toutes les dépenses du mois avec catégories
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ]);

    query.where(_db.transactionsTable.type.equals('expense'));
    query.where(
      _db.transactionsTable.date.isBetweenValues(startOfMonth, endOfMonth),
    );

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

    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth));

    final transactions = await query.get();

    // Grouper par jour
    final Map<int, _DailyAccumulator> dailyData = {};

    for (final tx in transactions) {
      final day = tx.date.day;
      dailyData.putIfAbsent(
        day,
        () => _DailyAccumulator(date: DateTime(month.year, month.month, day)),
      );

      if (tx.type == 'income') {
        dailyData[day]!.income += tx.amount;
      } else {
        dailyData[day]!.expense += tx.amount;
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

    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('income'))
      ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  @override
  Future<double> getTotalExpense(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.type.equals('expense'))
      ..where((t) => t.date.isBetweenValues(startOfMonth, endOfMonth));

    final transactions = await query.get();
    return transactions.fold<double>(0, (sum, tx) => sum + tx.amount);
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
  double income;
  double expense;

  _DailyAccumulator({required this.date, this.income = 0, this.expense = 0});
}
