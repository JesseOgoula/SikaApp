import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Import des tables
import 'tables/transactions_table.dart';
import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';

// Export des tables pour faciliter les imports
export 'tables/transactions_table.dart';
export 'tables/accounts_table.dart';
export 'tables/categories_table.dart';

// Fichier généré par build_runner (drift)
part 'app_database.g.dart';

/// Modèle de jointure Transaction + Catégorie
class TransactionWithCategory {
  final TransactionsTableData transaction;
  final CategoriesTableData? category;

  TransactionWithCategory({required this.transaction, this.category});
}

/// Base de données principale de l'application SIKA
///
/// Utilise Drift (SQLite) comme source de vérité locale (Offline-First).
/// Compatible avec PowerSync pour la synchronisation vers Supabase.
///
/// Tables:
/// - [TransactionsTable] : Transactions financières
/// - [AccountsTable] : Comptes (Bank, Mobile Money, Cash)
/// - [CategoriesTable] : Catégories avec support Smart Labeling
///
/// Usage:
/// ```dart
/// final db = AppDatabase();
/// final transactions = await db.select(db.transactionsTable).get();
/// ```
@DriftDatabase(tables: [TransactionsTable, AccountsTable, CategoriesTable])
class AppDatabase extends _$AppDatabase {
  /// Constructeur par défaut - ouvre la base de données
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests avec un executor personnalisé
  AppDatabase.forTesting(super.executor);

  /// Version du schéma de la base de données
  /// Incrémenter à chaque modification du schéma
  @override
  int get schemaVersion => 2;

  /// Migrations de la base de données
  ///
  /// Gère les mises à jour du schéma entre les versions.
  /// IMPORTANT: Toujours ajouter des migrations, ne jamais modifier les anciennes.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Création initiale de la base de données
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insérer les catégories par défaut
        await _seedDefaultCategories();
      },
      // Mise à jour de la base de données
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Re-seed pour la mise à jour des icônes/catégories
          await batch((batch) {
            batch.deleteWhere(categoriesTable, (row) => const Constant(true));
          });
          await _seedDefaultCategories();
        }
      },
      // Exécuté à chaque ouverture de la base
      beforeOpen: (details) async {
        // Activer les clés étrangères pour l'intégrité référentielle
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Insère les catégories par défaut pour le marché gabonais
  Future<void> _seedDefaultCategories() async {
    final defaultCategories = [
      _createCategory(
        id: 'cat-alimentation',
        name: 'Alimentation',
        iconKey: 'utensils', // FontAwesome: utensils
        color: '#4CAF50',
        keywords: [
          'boulangerie',
          'supermarche',
          'mbolo',
          'geant',
          'cecado',
          'market',
          'pain',
          'alimentation',
          'kiosque',
        ],
        isSystem: true,
        sortOrder: 1,
      ),
      _createCategory(
        id: 'cat-transport',
        name: 'Transport',
        iconKey: 'taxi', // FontAwesome: taxi
        color: '#2196F3',
        keywords: [
          'taxi',
          'clando',
          'total',
          'petro',
          'essence',
          'transport',
          'carburant',
          'peage',
        ],
        isSystem: true,
        sortOrder: 2,
      ),
      _createCategory(
        id: 'cat-factures',
        name: 'Factures',
        iconKey: 'bolt', // FontAwesome: bolt
        color: '#FF9800',
        keywords: [
          'seeg',
          'edan',
          'canal',
          'startimes',
          'ebilling',
          'forfait',
          'loyer',
          'eau',
          'electricite',
        ],
        isSystem: true,
        sortOrder: 3,
      ),
      _createCategory(
        id: 'cat-sante',
        name: 'Santé',
        iconKey: 'heartPulse', // FontAwesome: heartPulse
        color: '#F44336',
        keywords: [
          'pharmacie',
          'hopital',
          'clinique',
          'docteur',
          'medicament',
          'sante',
        ],
        isSystem: true,
        sortOrder: 4,
      ),
      _createCategory(
        id: 'cat-transferts',
        name: 'Transferts',
        iconKey: 'exchangeAlt', // FontAwesome: exchangeAlt
        color: '#00BCD4',
        keywords: [
          'envoi',
          'reception',
          'transfert',
          'retrait',
          'depot',
          'virement',
        ],
        isSystem: true,
        sortOrder: 5,
      ),
      _createCategory(
        id: 'cat-loisirs',
        name: 'Loisirs',
        iconKey: 'gamepad', // FontAwesome: gamepad
        color: '#9C27B0',
        keywords: ['bar', 'resto', 'club', 'netflix', 'cinema', 'sortie'],
        isSystem: true,
        sortOrder: 6,
      ),
      _createCategory(
        id: 'cat-autres',
        name: 'Autre',
        iconKey: 'question', // FontAwesome: question
        color: '#9E9E9E',
        keywords: ['divers'],
        isSystem: true,
        sortOrder: 99,
      ),
    ];

    await batch((batch) {
      batch.insertAll(categoriesTable, defaultCategories);
    });
  }

  /// Helper pour créer un CategoriesTableCompanion avec keywordsJson formaté
  CategoriesTableCompanion _createCategory({
    required String id,
    required String name,
    required String iconKey,
    required String color,
    required List<String> keywords,
    required bool isSystem,
    required int sortOrder,
  }) {
    final keywordsJson =
        '{"keywords": ${_listToJson(keywords)}, "patterns": [], "confidence_boost": 0.0}';

    return CategoriesTableCompanion(
      id: Value(id),
      name: Value(name),
      iconKey: Value(iconKey),
      color: Value(color),
      keywordsJson: Value(keywordsJson),
      isSystem: Value(isSystem),
      sortOrder: Value(sortOrder),
      syncStatus: const Value(1), // Catégories système = déjà synchronisées
    );
  }

  /// Convertit une liste de strings en JSON array
  String _listToJson(List<String> list) {
    return '[${list.map((e) => '"$e"').join(', ')}]';
  }

  // ==================== QUERIES UTILITAIRES ====================

  /// Récupère toutes les transactions triées par date décroissante
  Future<List<TransactionsTableData>> getAllTransactions() {
    return (select(
      transactionsTable,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
  }

  /// Récupère toutes les transactions avec leurs catégories
  Stream<List<TransactionWithCategory>> watchTransactionsWithCategories() {
    final query = select(transactionsTable).join([
      leftOuterJoin(
        categoriesTable,
        categoriesTable.id.equalsExp(transactionsTable.categoryId),
      ),
    ]);

    // Sort by date desc
    query.orderBy([OrderingTerm.desc(transactionsTable.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(transactionsTable),
          category: row.readTableOrNull(categoriesTable),
        );
      }).toList();
    });
  }

  /// Récupère les transactions en attente de synchronisation
  Future<List<TransactionsTableData>> getPendingSyncTransactions() {
    return (select(
      transactionsTable,
    )..where((t) => t.syncStatus.equals(0))).get();
  }

  /// Récupère tous les comptes actifs
  Future<List<AccountsTableData>> getActiveAccounts() {
    return (select(accountsTable)..where((a) => a.isActive.equals(true))).get();
  }

  /// Récupère toutes les catégories triées
  Future<List<CategoriesTableData>> getAllCategories() {
    return (select(
      categoriesTable,
    )..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();
  }

  /// Vérifie si une transaction avec cet externalId existe déjà
  Future<bool> transactionExists(String externalId) async {
    final query = select(transactionsTable)
      ..where((t) => t.externalId.equals(externalId));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Met à jour le solde d'un compte
  Future<void> updateAccountBalance(String accountId, double newBalance) {
    return (update(accountsTable)..where((a) => a.id.equals(accountId))).write(
      AccountsTableCompanion(
        balance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Marque une transaction comme synchronisée
  Future<void> markTransactionSynced(String transactionId) {
    return (update(transactionsTable)..where((t) => t.id.equals(transactionId)))
        .write(const TransactionsTableCompanion(syncStatus: Value(1)));
  }
}

/// Ouvre la connexion à la base de données SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Récupère le dossier de l'application
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sika_database.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
