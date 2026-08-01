import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../utils/encryption_utils.dart';
import '../utils/logger.dart';

// Import des tables
import 'tables/transactions_table.dart';
import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/goals_table.dart';
import 'tables/debts_table.dart';
import 'tables/budgets_table.dart';

// Export des tables pour faciliter les imports
export 'tables/transactions_table.dart';
export 'tables/accounts_table.dart';
export 'tables/categories_table.dart';
export 'tables/goals_table.dart';
export 'tables/debts_table.dart';
export 'tables/budgets_table.dart';

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
@DriftDatabase(
  tables: [
    TransactionsTable,
    AccountsTable,
    CategoriesTable,
    GoalsTable,
    DebtsTable,
    BudgetsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Constructeur par défaut - ouvre la base de données
  AppDatabase() : super(_openConnection());

  // Constructeur prenant une clé (pour compatibilité future/main.dart)
  // Pour l'instant on ignore la clé car la logique de chiffrement est dans openConnection si nécessaire
  factory AppDatabase.encrypted(String key) {
    return AppDatabase();
  }

  /// Constructeur pour les tests avec un executor personnalisé
  AppDatabase.forTesting(super.executor);

  /// Version du schéma de la base de données
  /// Incrémenter à chaque modification du schéma
  @override
  int get schemaVersion => 11;

  /// Migrations de la base de données
  ///
  /// Gère les mises à jour du schema entre les versions.
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
        if (from < 3) {
          // Ajout de la table GoalsTable
          await m.createTable(goalsTable);
        }
        if (from < 5) {
          // Ajout de la table DebtsTable (si elle n'existe pas déjà)
          try {
            await m.createTable(debtsTable);
          } catch (e) {
            SikaLogger.error('Migration failed for debtsTable (from < 5): $e', tag: 'DB_MIGRATION');
          }
        }
        if (from < 7) {
          // Ajout de la table BudgetsTable
          try {
            await m.createTable(budgetsTable);
          } catch (e) {
            SikaLogger.error('Migration failed for budgetsTable (from < 7): $e', tag: 'DB_MIGRATION');
          }
        }
        if (from < 8) {
          // v8: Colonnes smsSender et smsRawContent supprimées du schema Drift.
          // Les colonnes restent dans SQLite (pas de DROP COLUMN) mais sont
          // simplement ignorées par Drift. Aucune action requise.
        }
        if (from < 9) {
          try {
            await m.addColumn(transactionsTable, transactionsTable.debtId);
          } catch (e) {
            SikaLogger.error('Migration failed for transactionsTable.debtId (from < 9): $e', tag: 'DB_MIGRATION');
          }
        }
        if (from < 10) {
          try {
            await m.addColumn(debtsTable, debtsTable.paidAmount);
          } catch (e) {
            SikaLogger.error('Migration failed for debtsTable.paidAmount (from < 10): $e', tag: 'DB_MIGRATION');
          }
          // Fix existing debts that have a null paid_amount from earlier versions
          await customStatement('UPDATE debts_table SET paid_amount = 0.0 WHERE paid_amount IS NULL');
        }
        if (from < 11) {
          try {
            await m.addColumn(transactionsTable, transactionsTable.toAccountId);
          } catch (e) {
            SikaLogger.error('Migration failed for transactionsTable.toAccountId (from < 11): $e', tag: 'DB_MIGRATION');
          }
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
        id: 'cat-epargne',
        name: 'Épargne',
        iconKey: 'piggyBank', // FontAwesome: piggyBank
        color: '#1E3A5F', // Bleu Nuit (couleur primaire SIKA)
        keywords: ['epargne', 'objectif', 'economie', 'saving'],
        isSystem: true,
        sortOrder: 7,
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
    // 1. Récupère la clé de chiffrement
    final encryptionKey = await EncryptionUtils.getEncryptionKey();

    // 2. Récupère le dossier de l'application
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sika_database.sqlite'));

    // 3. Migration d'une base non chiffrée vers une base chiffrée (SQLCipher)
    if (file.existsSync()) {
      bool isEncrypted = false;
      try {
        final db = sqlite3.open(file.path);
        // Tente de lire sans clé. Si la base est chiffrée, cela va échouer.
        db.execute('SELECT count(*) FROM sqlite_master;');
        db.dispose();
      } catch (e) {
        // La base est déjà chiffrée (ou corrompue)
        isEncrypted = true;
      }

      if (!isEncrypted) {
        // La base existe mais n'est pas chiffrée, on doit la migrer
        final unencryptedDb = sqlite3.open(file.path);
        final tempFile = File(p.join(dbFolder.path, 'sika_database_temp.sqlite'));
        if (tempFile.existsSync()) tempFile.deleteSync();

        // Attache une nouvelle base de données temporaire chiffrée
        unencryptedDb.execute("ATTACH DATABASE '${tempFile.path}' AS encrypted KEY '$encryptionKey';");
        // Exporte les données de la base non chiffrée vers la base chiffrée
        unencryptedDb.execute("SELECT sqlcipher_export('encrypted');");
        unencryptedDb.execute("DETACH DATABASE encrypted;");
        unencryptedDb.dispose();

        // Remplace l'ancienne base non chiffrée par la nouvelle base chiffrée
        tempFile.copySync(file.path);
        tempFile.deleteSync();
      }
    }

    // 4. Ouvre la base avec Drift en appliquant la clé
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute("PRAGMA key = '$encryptionKey';");
      },
    );
  });
}
