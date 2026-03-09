import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sika_app/core/services/settings_service.dart';

/// Service de synchronisation automatique
///
/// - Sync au démarrage si connecté
/// - Sync à chaque changement de connectivité (retour réseau)
/// - Sync périodique toutes les 5 minutes
/// - `forceSync()` peut être appelé après une action utilisateur
class AutoSyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _hasInternet = false;

  /// Durée entre chaque sync périodique
  static const _syncInterval = Duration(minutes: 5);

  AutoSyncService(this._db) : _supabase = Supabase.instance.client;

  /// Démarre l'écoute des changements de connectivité + timer périodique
  void startListening() {
    // Écoute connectivité
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    // Timer périodique
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      if (_hasInternet) {
        _checkAndSync();
      }
    });
    // Sync initiale
    _checkAndSync();
  }

  /// Arrête l'écoute et le timer
  void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Appelé quand la connectivité change
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _hasInternet = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    if (_hasInternet) {
      _checkAndSync();
    } else {}
  }

  /// Force une synchronisation (à appeler après une action utilisateur)
  ///
  /// Délai court pour laisser Drift écrire dans la DB avant de lire.
  Future<void> forceSync() async {
    // Petit délai pour laisser la transaction DB se terminer
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkAndSync();
  }

  /// Vérifie la connectivité et lance la sync
  Future<void> _checkAndSync() async {
    if (_isSyncing) {
      return;
    }

    // Vérifie que l'utilisateur est connecté
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    _isSyncing = true;

    try {
      await _syncCategories(user.id);
      await _syncTransactions(user.id);
      await _syncAccounts(user.id);
      await _syncDebts(user.id);
      await _syncGoals(user.id);
      await _syncBudgets(user.id);
    } finally {
      _isSyncing = false;
    }
  }

  // ==================== SYNC METHODS ====================

  /// Synchronise les catégories (syncStatus == 0) vers Supabase
  Future<void> _syncCategories(String userId) async {
    final pending = await (_db.select(
      _db.categoriesTable,
    )..where((c) => c.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    for (final category in pending) {
      try {
        await _supabase.from('categories').upsert({
          'id': category.id,
          'user_id': userId,
          'name': category.name,
          'icon_key': category.iconKey,
          'color': category.color,
          'keywords_json': category.keywordsJson,
          'parent_id': category.parentId,
          'is_system': category.isSystem ? 1 : 0,
          'budget_limit': category.budgetLimit,
          'sort_order': category.sortOrder,
          'sync_status': 1,
          'created_at': category.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.categoriesTable)
              ..where((c) => c.id.equals(category.id)))
            .write(const CategoriesTableCompanion(syncStatus: Value(1)));
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  /// Synchronise les transactions (syncStatus == 0) vers Supabase
  Future<void> _syncTransactions(String userId) async {
    final pending = await (_db.select(
      _db.transactionsTable,
    )..where((t) => t.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    for (final tx in pending) {
      try {
        await _supabase.from('transactions').upsert({
          'id': tx.id,
          'user_id': userId,
          'amount': tx.amount,
          'type': tx.type,
          'merchant_name': tx.merchantName,
          'category_id': tx.categoryId,
          'account_id': tx.accountId,
          'date': tx.date.toIso8601String(),
          'external_id': tx.externalId,
          'is_ai_categorized': tx.isAiCategorized ? 1 : 0,
          'sync_status': 1,
          'validation_status': tx.validationStatus,
          'created_at': tx.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.transactionsTable)
              ..where((t) => t.id.equals(tx.id)))
            .write(const TransactionsTableCompanion(syncStatus: Value(1)));
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  /// Synchronise les comptes vers Supabase
  Future<void> _syncAccounts(String userId) async {
    final allAccounts = await _db.select(_db.accountsTable).get();

    if (allAccounts.isEmpty) return;

    for (final account in allAccounts) {
      try {
        await _supabase.from('accounts').upsert({
          'id': account.id,
          'user_id': userId,
          'name': account.name,
          'type': account.type,
          'balance': account.balance,
          'currency': account.currency,
          'phone_number': account.phoneNumber,
          'icon_key': account.iconKey,
          'color': account.color,
          'is_default': account.isDefault,
          'is_active': account.isActive,
          'sync_status': 1,
          'created_at': account.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.accountsTable)
              ..where((a) => a.id.equals(account.id)))
            .write(const AccountsTableCompanion(syncStatus: Value(1)));
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  /// Synchronise les dettes (syncStatus == 0) vers Supabase
  Future<void> _syncDebts(String userId) async {
    final pending = await (_db.select(
      _db.debtsTable,
    )..where((d) => d.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    for (final debt in pending) {
      try {
        await _supabase.from('debts').upsert({
          'id': debt.id,
          'user_id': userId,
          'name': debt.name,
          'amount': debt.amount,
          'type': _toSnakeCaseDebtType(debt.type),
          'due_date': debt.dueDate.toIso8601String(),
          'status': debt.status,
          'person_name': debt.personName,
          'notes': debt.notes,
          'is_recurring': debt.isRecurring ? 1 : 0,
          'recurrence_rule': debt.recurrenceRule,
          'notification_id': debt.notificationId,
          'sync_status': 1,
          'created_at': debt.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.debtsTable)..where((d) => d.id.equals(debt.id)))
            .write(const DebtsTableCompanion(syncStatus: Value(1)));
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  /// Synchronise TOUS les objectifs vers Supabase
  /// (goals n'a pas de syncStatus, on sync toujours tout)
  Future<void> _syncGoals(String userId) async {
    final goals = await _db.select(_db.goalsTable).get();

    if (goals.isEmpty) return;

    for (final goal in goals) {
      try {
        await _supabase.from('goals').upsert({
          'id': goal.id,
          'user_id': userId,
          'name': goal.name,
          'target_amount': goal.targetAmount,
          'saved_amount': goal.savedAmount,
          'icon_key': goal.iconKey,
          'deadline': goal.deadline?.toIso8601String(),
          'is_completed': goal.isCompleted ? 1 : 0,
          'created_at': goal.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  /// Synchronise les budgets vers Supabase
  Future<void> _syncBudgets(String userId) async {
    final pending = await (_db.select(
      _db.budgetsTable,
    )..where((b) => b.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    for (final budget in pending) {
      try {
        await _supabase.from('budgets').upsert({
          'id': budget.id,
          'user_id': userId,
          'category_id': budget.categoryId,
          'category_name': budget.categoryName,
          'parent_budget_id': budget.parentBudgetId,
          'amount': budget.amount,
          'period_type': budget.periodType,
          'start_date': budget.startDate.toIso8601String(),
          'end_date': budget.endDate?.toIso8601String(),
          'is_active': budget.isActive,
          'alert_threshold': budget.alertThreshold,
          'sync_status': 1,
          'created_at': budget.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.budgetsTable)
              ..where((b) => b.id.equals(budget.id)))
            .write(const BudgetsTableCompanion(syncStatus: Value(1)));
      } catch (e, stackTrace) {
        Sentry.captureException(e, stackTrace: stackTrace);
      }
    }
  }

  // ==================== RESTORE FROM CLOUD ====================

  /// Restaure TOUTES les données depuis Supabase vers la base locale
  ///
  /// Appelé quand l'utilisateur se reconnecte après une réinstallation.
  /// Utilise insertOrReplace pour gérer les doublons.
  Future<bool> restoreFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      await _restoreCategories(user.id);
      await _restoreAccounts(user.id);
      await _restoreTransactions(user.id);
      await _restoreGoals(user.id);
      await _restoreDebts(user.id);
      await _restoreBudgets(user.id);
      await _restoreXP(user.id);

      return true;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Restaure les catégories depuis Supabase
  Future<void> _restoreCategories(String userId) async {
    try {
      final data = await _supabase
          .from('categories')
          .select()
          .eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.categoriesTable)
            .insertOnConflictUpdate(
              CategoriesTableCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                iconKey: Value(row['icon_key'] as String? ?? 'question'),
                color: Value(row['color'] as String? ?? '#9E9E9E'),
                keywordsJson: Value(row['keywords_json'] as String? ?? ''),
                parentId: Value(row['parent_id'] as String?),
                isSystem: Value(row['is_system'] == true),
                budgetLimit: Value((row['budget_limit'] as num?)?.toDouble()),
                sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
                syncStatus: const Value(1),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les comptes depuis Supabase
  Future<void> _restoreAccounts(String userId) async {
    try {
      final data = await _supabase
          .from('accounts')
          .select()
          .eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.accountsTable)
            .insertOnConflictUpdate(
              AccountsTableCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                type: row['type'] as String,
                balance: Value((row['balance'] as num?)?.toDouble() ?? 0.0),
                currency: Value(row['currency'] as String? ?? 'XAF'),
                phoneNumber: Value(row['phone_number'] as String?),
                iconKey: Value(row['icon_key'] as String? ?? 'wallet'),
                color: Value(row['color'] as String? ?? '#1E3A5F'),
                isDefault: Value(row['is_default'] as bool? ?? false),
                isActive: Value(row['is_active'] as bool? ?? true),
                syncStatus: const Value(1),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les transactions depuis Supabase
  Future<void> _restoreTransactions(String userId) async {
    try {
      final data = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.transactionsTable)
            .insertOnConflictUpdate(
              TransactionsTableCompanion.insert(
                id: row['id'] as String,
                amount: (row['amount'] as num).toDouble(),
                type: row['type'] as String,
                merchantName: Value(row['merchant_name'] as String?),
                date: DateTime.parse(row['date'] as String),
                externalId: Value(row['external_id'] as String?),
                categoryId: Value(row['category_id'] as String?),
                accountId: Value(row['account_id'] as String?),
                isAiCategorized: Value(row['is_ai_categorized'] == true),
                validationStatus: Value(
                  (row['validation_status'] as num?)?.toInt() ?? 0,
                ),
                syncStatus: const Value(1),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les objectifs depuis Supabase
  Future<void> _restoreGoals(String userId) async {
    try {
      final data = await _supabase.from('goals').select().eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.goalsTable)
            .insertOnConflictUpdate(
              GoalsTableCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                targetAmount: (row['target_amount'] as num).toDouble(),
                savedAmount: Value(
                  (row['saved_amount'] as num?)?.toDouble() ?? 0.0,
                ),
                iconKey: Value(row['icon_key'] as String?),
                deadline: Value(
                  row['deadline'] != null
                      ? DateTime.parse(row['deadline'] as String)
                      : null,
                ),
                isCompleted: Value(row['is_completed'] == true),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les dettes depuis Supabase
  Future<void> _restoreDebts(String userId) async {
    try {
      final data = await _supabase.from('debts').select().eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.debtsTable)
            .insertOnConflictUpdate(
              DebtsTableCompanion.insert(
                id: row['id'] as String,
                userId: userId,
                name: row['name'] as String,
                amount: (row['amount'] as num).toDouble(),
                type: row['type'] as String,
                dueDate: DateTime.parse(row['due_date'] as String),
                status: Value(row['status'] as String? ?? 'pending'),
                personName: Value(row['person_name'] as String?),
                notes: Value(row['notes'] as String?),
                isRecurring: Value(row['is_recurring'] == true),
                recurrenceRule: Value(row['recurrence_rule'] as String?),
                notificationId: Value(
                  (row['notification_id'] as num?)?.toInt(),
                ),
                syncStatus: const Value(1),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les budgets depuis Supabase
  Future<void> _restoreBudgets(String userId) async {
    try {
      final data = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', userId);

      if (data.isEmpty) {
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.budgetsTable)
            .insertOnConflictUpdate(
              BudgetsTableCompanion.insert(
                id: row['id'] as String,
                categoryId: row['category_id'] as String,
                categoryName: row['category_name'] as String,
                parentBudgetId: Value(row['parent_budget_id'] as String?),
                amount: (row['amount'] as num).toDouble(),
                periodType: Value(row['period_type'] as String? ?? 'monthly'),
                startDate: DateTime.parse(row['start_date'] as String),
                endDate: Value(
                  row['end_date'] != null
                      ? DateTime.parse(row['end_date'] as String)
                      : null,
                ),
                isActive: Value(row['is_active'] as bool? ?? true),
                alertThreshold: Value(
                  (row['alert_threshold'] as num?)?.toDouble() ?? 80.0,
                ),
                syncStatus: const Value(1),
              ),
            );
      }
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Restaure les XP depuis la table user_ranks de Supabase
  Future<void> _restoreXP(String userId) async {
    try {
      final data = await _supabase
          .from('user_ranks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) {
        return;
      }

      final totalXP = (data['total_xp'] as num?)?.toInt() ?? 0;
      final settings = SettingsService();
      await settings.init();
      await settings.setTotalXP(totalXP);
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
    }
  }

  /// Convertit le type de dette camelCase en snake_case pour Supabase
  String _toSnakeCaseDebtType(String type) {
    switch (type) {
      case 'debtIn':
        return 'debt_in';
      case 'debtOut':
        return 'debt_out';
      default:
        return type; // 'bill', 'pending', etc. restent inchangés
    }
  }
}
