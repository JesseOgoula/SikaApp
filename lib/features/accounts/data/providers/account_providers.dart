import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart' show databaseProvider, autoSyncService;
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Les 4 types de comptes supportés (un seul par catégorie par user)
class AccountTypeConfig {
  final String name;
  final String type;
  final String? iconPath;
  final String color;

  const AccountTypeConfig({
    required this.name,
    required this.type,
    this.iconPath,
    required this.color,
  });
}

/// Définition des 4 comptes possibles
const List<AccountTypeConfig> kAllAccountTypes = [
  AccountTypeConfig(
    name: 'Airtel Money',
    type: 'mobileMoney',
    iconPath: 'assets/icons/airtel.png',
    color: '#E53935',
  ),
  AccountTypeConfig(
    name: 'Moov Money',
    type: 'mobileMoney',
    iconPath: 'assets/icons/moov.png',
    color: '#1E88E5',
  ),
  AccountTypeConfig(
    name: 'UBA',
    type: 'bank',
    iconPath: 'assets/icons/uba.png',
    color: '#C62828',
  ),
  AccountTypeConfig(
    name: 'Cash',
    type: 'cash',
    iconPath: null,
    color: '#43A047',
  ),
];

/// Provider pour le repository des comptes
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepository(db);
});

/// Provider pour la liste des comptes actifs (données brutes)
final activeAccountsProvider = StreamProvider<List<AccountsTableData>>((ref) {
  ref.keepAlive(); // Garde en cache pour navigation instantanée
  final repo = ref.watch(accountRepositoryProvider);
  return repo.watchActiveAccounts();
});

/// Classe pour représenter un compte avec son solde calculé
class AccountWithBalance {
  final AccountsTableData account;
  final double calculatedBalance;

  AccountWithBalance({required this.account, required this.calculatedBalance});

  // Propriétés accessibles facilement
  String get id => account.id;
  String get name => account.name;
  String get type => account.type;
  String get iconKey => account.iconKey;
  String get color => account.color;
  double get balance => calculatedBalance;
}

/// Provider pour les comptes avec solde calculé dynamiquement
/// Balance = Solde initial + Revenus liés au compte - Dépenses liées au compte
final accountsWithBalanceProvider =
    Provider<AsyncValue<List<AccountWithBalance>>>((ref) {
      final accountsAsync = ref.watch(activeAccountsProvider);
      final transactionsAsync = ref.watch(transactionWithCategoryListProvider);

      return accountsAsync.when(
        data: (accounts) => transactionsAsync.when(
          data: (transactions) {
            // Calculer le solde pour chaque compte
            final result = accounts.map((account) {
              double transactionSum = 0;

              for (final txWithCat in transactions) {
                final tx = txWithCat.transaction;
                if (tx.accountId == account.id) {
                  if (tx.type == 'income') {
                    transactionSum += tx.amount;
                  } else if (tx.type == 'expense') {
                    transactionSum -= tx.amount;
                  } else if (tx.type == 'transfer') {
                    transactionSum -= tx.amount; // Sortie du compte source
                  }
                }
                if (tx.toAccountId == account.id) {
                  if (tx.type == 'transfer') {
                    transactionSum += tx.amount; // Entrée dans le compte destination
                  }
                }
              }

              // Solde = Balance initiale + transactions
              final calculatedBalance = account.balance + transactionSum;

              return AccountWithBalance(
                account: account,
                calculatedBalance: calculatedBalance,
              );
            }).toList();

            return AsyncValue.data(result);
          },
          loading: () => const AsyncValue.loading(),
          error: (e, st) => AsyncValue.error(e, st),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Provider pour le solde total de tous les comptes (calculé)
final totalAccountsBalanceProvider = Provider<double>((ref) {
  final accountsAsync = ref.watch(accountsWithBalanceProvider);
  return accountsAsync.whenOrNull(
        data: (accounts) => accounts.fold<double>(
          0.0,
          (sum, acc) => sum + acc.calculatedBalance,
        ),
      ) ??
      0.0;
});

/// Repository pour gérer les comptes financiers
class AccountRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  AccountRepository(this._db);

  // ==================== CLOUD METHODS ====================

  /// Fetch les comptes depuis Supabase et les insère dans la DB locale (Drift)
  /// Retourne true si des comptes ont été trouvés sur le cloud
  Future<bool> fetchAccountsFromSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      final response = await Supabase.instance.client
          .from('accounts')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true);

      if (response.isEmpty) return false;

      // Insérer/mettre à jour dans Drift local
      for (final row in response) {
        await _db
            .into(_db.accountsTable)
            .insertOnConflictUpdate(
              AccountsTableCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                type: row['type'] as String,
                balance: Value((row['balance'] as num?)?.toDouble() ?? 0.0),
                phoneNumber: Value(row['phone_number'] as String?),
                iconKey: Value(row['icon_key'] as String? ?? 'wallet'),
                color: Value(row['color'] as String? ?? '#4CAF50'),
                isDefault: Value(row['is_default'] as bool? ?? false),
                isActive: const Value(true),
                syncStatus: const Value(1), // Déjà synced
              ),
            );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Vérifie si un compte avec ce nom existe déjà (localement)
  Future<bool> hasAccountOfName(String name) async {
    final existing =
        await (_db.select(_db.accountsTable)
              ..where((a) => a.name.equals(name))
              ..where((a) => a.isActive.equals(true)))
            .getSingleOrNull();
    return existing != null;
  }

  /// Retourne les types de comptes pas encore créés par l'utilisateur
  Future<List<AccountTypeConfig>> getAvailableAccountTypes() async {
    final existingAccounts = await getActiveAccounts();
    final existingNames = existingAccounts.map((a) => a.name).toSet();

    return kAllAccountTypes
        .where((config) => !existingNames.contains(config.name))
        .toList();
  }

  /// Retourne les comptes déjà créés sous forme de AccountTypeConfig names
  Future<Set<String>> getExistingAccountNames() async {
    final accounts = await getActiveAccounts();
    return accounts.map((a) => a.name).toSet();
  }

  // ==================== LOCAL METHODS ====================

  /// Crée un nouveau compte avec solde initial
  /// Vérifie d'abord qu'un compte du même nom n'existe pas
  Future<bool> createAccount({
    required String name,
    required String type,
    required double initialBalance,
    String? phoneNumber,
    required String iconKey,
    required String color,
    bool isDefault = false,
  }) async {
    // Guard : un seul compte par nom/catégorie
    if (await hasAccountOfName(name)) {
      return false;
    }

    final id = _uuid.v4();
    await _db
        .into(_db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: id,
            name: name,
            type: type,
            balance: Value(initialBalance),
            phoneNumber: Value(phoneNumber),
            iconKey: Value(iconKey),
            color: Value(color),
            isDefault: Value(isDefault),
            isActive: const Value(true),
          ),
        );

    // Award XP for adding account
    XPService().awardXP(ActionType.addAccount);

    // Sync vers Supabase
    autoSyncService?.forceSync();

    return true;
  }

  /// Récupère tous les comptes actifs
  Future<List<AccountsTableData>> getActiveAccounts() async {
    return (_db.select(
      _db.accountsTable,
    )..where((t) => t.isActive.equals(true))).get();
  }

  /// Stream des comptes actifs
  Stream<List<AccountsTableData>> watchActiveAccounts() {
    return (_db.select(_db.accountsTable)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Trouve un compte par son type et nom
  Future<AccountsTableData?> findAccountByName(String name) async {
    return (_db.select(_db.accountsTable)
          ..where((t) => t.name.equals(name))
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
  }

  /// Met à jour le solde d'un compte
  Future<void> updateBalance(String accountId, double newBalance) async {
    await (_db.update(
      _db.accountsTable,
    )..where((t) => t.id.equals(accountId))).write(
      AccountsTableCompanion(
        balance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Ajoute ou soustrait du solde
  Future<void> adjustBalance(String accountId, double amount) async {
    final account = await (_db.select(
      _db.accountsTable,
    )..where((t) => t.id.equals(accountId))).getSingleOrNull();

    if (account != null) {
      final newBalance = account.balance + amount;
      await updateBalance(accountId, newBalance);
    }
  }

  /// Vérifie si des comptes existent
  Future<bool> hasAnyAccounts() async {
    final accounts = await getActiveAccounts();
    return accounts.isNotEmpty;
  }

  /// Supprime tous les comptes (pour reset)
  Future<void> deleteAllAccounts() async {
    await _db.delete(_db.accountsTable).go();
  }
}
