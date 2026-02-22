import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
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
    debugPrint('🔄 [AutoSync] Started listening for connectivity changes');

    // Timer périodique
    _periodicTimer = Timer.periodic(_syncInterval, (_) {
      if (_hasInternet) {
        debugPrint('⏱️ [AutoSync] Periodic sync triggered');
        _checkAndSync();
      }
    });
    debugPrint(
      '⏱️ [AutoSync] Periodic timer started (${_syncInterval.inMinutes} min)',
    );

    // Sync initiale
    _checkAndSync();
  }

  /// Arrête l'écoute et le timer
  void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('🔄 [AutoSync] Stopped listening');
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
      debugPrint('🌐 [AutoSync] Internet available - triggering sync');
      _checkAndSync();
    } else {
      debugPrint('📴 [AutoSync] No internet - sync paused');
    }
  }

  /// Force une synchronisation (à appeler après une action utilisateur)
  ///
  /// Délai court pour laisser Drift écrire dans la DB avant de lire.
  Future<void> forceSync() async {
    // Petit délai pour laisser la transaction DB se terminer
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('🔄 [AutoSync] Force sync requested');
    await _checkAndSync();
  }

  /// Vérifie la connectivité et lance la sync
  Future<void> _checkAndSync() async {
    if (_isSyncing) {
      debugPrint('🔄 [AutoSync] Already syncing, skipping');
      return;
    }

    // Vérifie que l'utilisateur est connecté
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('👤 [AutoSync] No user logged in - skipping sync');
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

      debugPrint('✅ [AutoSync] Sync complete');
    } catch (e) {
      debugPrint('❌ [AutoSync] Sync error: $e');
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

    debugPrint('📤 [Categories] Syncing ${pending.length} categories...');

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

        debugPrint('✅ [Categories] Synced ${category.name}');
      } catch (e) {
        debugPrint('❌ [Categories] Failed to sync ${category.name}: $e');
      }
    }
  }

  /// Synchronise les transactions (syncStatus == 0) vers Supabase
  Future<void> _syncTransactions(String userId) async {
    final pending = await (_db.select(
      _db.transactionsTable,
    )..where((t) => t.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    debugPrint('📤 [Transactions] Syncing ${pending.length} transactions...');

    for (final tx in pending) {
      try {
        await _supabase.from('transactions').upsert({
          'id': tx.id,
          'user_id': userId,
          'amount': tx.amount,
          'type': tx.type,
          'merchant_name': tx.merchantName,
          'date': tx.date.toIso8601String(),
          'sms_sender': tx.smsSender,
          'sms_raw_content': tx.smsRawContent,
          'external_id': tx.externalId,
          'is_ai_categorized': tx.isAiCategorized ? 1 : 0,
          'sync_status': 1,
          'validation_status': 0,
          'created_at': tx.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await (_db.update(_db.transactionsTable)
              ..where((t) => t.id.equals(tx.id)))
            .write(const TransactionsTableCompanion(syncStatus: Value(1)));

        debugPrint('✅ [Transactions] Synced ${tx.id}');
      } catch (e) {
        debugPrint('❌ [Transactions] Failed to sync ${tx.id}: $e');
      }
    }
  }

  /// Synchronise les comptes vers Supabase
  Future<void> _syncAccounts(String userId) async {
    final allAccounts = await _db.select(_db.accountsTable).get();

    if (allAccounts.isEmpty) return;

    debugPrint('📤 [Accounts] Syncing ${allAccounts.length} accounts...');

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

        debugPrint('✅ [Accounts] Synced ${account.name}');
      } catch (e) {
        debugPrint('❌ [Accounts] Failed to sync ${account.name}: $e');
      }
    }
  }

  /// Synchronise les dettes (syncStatus == 0) vers Supabase
  Future<void> _syncDebts(String userId) async {
    final pending = await (_db.select(
      _db.debtsTable,
    )..where((d) => d.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    debugPrint('📤 [Debts] Syncing ${pending.length} debts...');

    for (final debt in pending) {
      try {
        await _supabase.from('debts').upsert({
          'id': debt.id,
          'user_id': userId,
          'name': debt.name,
          'amount': debt.amount,
          'type': debt.type,
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

        debugPrint('✅ [Debts] Synced ${debt.name}');
      } catch (e) {
        debugPrint('❌ [Debts] Failed to sync ${debt.name}: $e');
      }
    }
  }

  /// Synchronise TOUS les objectifs vers Supabase
  /// (goals n'a pas de syncStatus, on sync toujours tout)
  Future<void> _syncGoals(String userId) async {
    final goals = await _db.select(_db.goalsTable).get();

    if (goals.isEmpty) return;

    debugPrint('📤 [Goals] Syncing ${goals.length} goals...');

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

        debugPrint('✅ [Goals] Synced ${goal.name}');
      } catch (e) {
        debugPrint('❌ [Goals] Failed to sync ${goal.name}: $e');
      }
    }
  }

  /// Synchronise les budgets vers Supabase
  Future<void> _syncBudgets(String userId) async {
    final pending = await (_db.select(
      _db.budgetsTable,
    )..where((b) => b.syncStatus.equals(0))).get();

    if (pending.isEmpty) return;

    debugPrint('📤 [Budgets] Syncing ${pending.length} budgets...');

    for (final budget in pending) {
      try {
        await _supabase.from('budgets').upsert({
          'id': budget.id,
          'user_id': userId,
          'category_id': budget.categoryId,
          'category_name': budget.categoryName,
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

        debugPrint('✅ [Budgets] Synced ${budget.categoryName}');
      } catch (e) {
        debugPrint('❌ [Budgets] Failed to sync ${budget.categoryName}: $e');
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
      debugPrint('👤 [Restore] No user logged in - skipping');
      return false;
    }

    debugPrint(
      '📥 [Restore] Starting full cloud restoration for ${user.id}...',
    );

    try {
      await _restoreCategories(user.id);
      await _restoreAccounts(user.id);
      await _restoreTransactions(user.id);
      await _restoreGoals(user.id);
      await _restoreDebts(user.id);
      await _restoreBudgets(user.id);
      await _restoreXP(user.id);

      debugPrint('✅ [Restore] Full cloud restoration complete!');
      return true;
    } catch (e) {
      debugPrint('❌ [Restore] Restoration failed: $e');
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
        debugPrint('📥 [Restore] No categories to restore');
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
                isSystem: Value((row['is_system'] as num?)?.toInt() == 1),
                budgetLimit: Value((row['budget_limit'] as num?)?.toDouble()),
                sortOrder: Value((row['sort_order'] as num?)?.toInt() ?? 0),
                syncStatus: const Value(1),
              ),
            );
      }
      debugPrint('✅ [Restore] Restored ${data.length} categories');
    } catch (e) {
      debugPrint('❌ [Restore] Categories restoration failed: $e');
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
        debugPrint('📥 [Restore] No accounts to restore');
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
                iconKey: Value(row['icon_key'] as String?),
                color: Value(row['color'] as String?),
                isDefault: Value(row['is_default'] as bool? ?? false),
                isActive: Value(row['is_active'] as bool? ?? true),
                syncStatus: const Value(1),
              ),
            );
      }
      debugPrint('✅ [Restore] Restored ${data.length} accounts');
    } catch (e) {
      debugPrint('❌ [Restore] Accounts restoration failed: $e');
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
        debugPrint('📥 [Restore] No transactions to restore');
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
                smsSender: Value(row['sms_sender'] as String?),
                smsRawContent: Value(row['sms_raw_content'] as String?),
                externalId: Value(row['external_id'] as String?),
                categoryId: Value(row['category_id'] as String?),
                accountId: Value(row['account_id'] as String?),
                isAiCategorized: Value(
                  (row['is_ai_categorized'] as num?)?.toInt() == 1,
                ),
                validationStatus: Value(
                  (row['validation_status'] as num?)?.toInt() ?? 0,
                ),
                syncStatus: const Value(1),
              ),
            );
      }
      debugPrint('✅ [Restore] Restored ${data.length} transactions');
    } catch (e) {
      debugPrint('❌ [Restore] Transactions restoration failed: $e');
    }
  }

  /// Restaure les objectifs depuis Supabase
  Future<void> _restoreGoals(String userId) async {
    try {
      final data = await _supabase.from('goals').select().eq('user_id', userId);

      if (data.isEmpty) {
        debugPrint('📥 [Restore] No goals to restore');
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
                isCompleted: Value((row['is_completed'] as num?)?.toInt() == 1),
              ),
            );
      }
      debugPrint('✅ [Restore] Restored ${data.length} goals');
    } catch (e) {
      debugPrint('❌ [Restore] Goals restoration failed: $e');
    }
  }

  /// Restaure les dettes depuis Supabase
  Future<void> _restoreDebts(String userId) async {
    try {
      final data = await _supabase.from('debts').select().eq('user_id', userId);

      if (data.isEmpty) {
        debugPrint('📥 [Restore] No debts to restore');
        return;
      }

      for (final row in data) {
        await _db
            .into(_db.debtsTable)
            .insertOnConflictUpdate(
              DebtsTableCompanion.insert(
                id: row['id'] as String,
                name: row['name'] as String,
                amount: (row['amount'] as num).toDouble(),
                type: row['type'] as String,
                dueDate: DateTime.parse(row['due_date'] as String),
                status: Value(row['status'] as String? ?? 'pending'),
                personName: Value(row['person_name'] as String?),
                notes: Value(row['notes'] as String?),
                isRecurring: Value((row['is_recurring'] as num?)?.toInt() == 1),
                recurrenceRule: Value(row['recurrence_rule'] as String?),
                notificationId: Value(
                  (row['notification_id'] as num?)?.toInt(),
                ),
                syncStatus: const Value(1),
              ),
            );
      }
      debugPrint('✅ [Restore] Restored ${data.length} debts');
    } catch (e) {
      debugPrint('❌ [Restore] Debts restoration failed: $e');
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
        debugPrint('📥 [Restore] No budgets to restore');
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
      debugPrint('✅ [Restore] Restored ${data.length} budgets');
    } catch (e) {
      debugPrint('❌ [Restore] Budgets restoration failed: $e');
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
        debugPrint('📥 [Restore] No XP data to restore');
        return;
      }

      final totalXP = (data['total_xp'] as num?)?.toInt() ?? 0;
      final settings = SettingsService();
      await settings.init();
      await settings.setTotalXP(totalXP);

      debugPrint('✅ [Restore] Restored XP: $totalXP');
    } catch (e) {
      debugPrint('❌ [Restore] XP restoration failed: $e');
    }
  }
}
