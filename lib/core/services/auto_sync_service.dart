import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';

/// Service de synchronisation automatique
///
/// Détecte les changements de connectivité et synchronise
/// automatiquement les données locales vers Supabase.
class AutoSyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  AutoSyncService(this._db) : _supabase = Supabase.instance.client;

  /// Démarre l'écoute des changements de connectivité
  void startListening() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    debugPrint('🔄 [AutoSync] Started listening for connectivity changes');

    // Sync initiale si connecté
    _checkAndSync();
  }

  /// Arrête l'écoute
  void stopListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('🔄 [AutoSync] Stopped listening');
  }

  /// Appelé quand la connectivité change
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasInternet = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    if (hasInternet) {
      debugPrint('🌐 [AutoSync] Internet available - triggering sync');
      _checkAndSync();
    } else {
      debugPrint('📴 [AutoSync] No internet - sync paused');
    }
  }

  /// Vérifie s'il y a des données à synchroniser et les envoie
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

      debugPrint('✅ [AutoSync] Sync complete');
    } catch (e) {
      debugPrint('❌ [AutoSync] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Force une synchronisation manuelle
  Future<void> forceSync() async {
    debugPrint('🔄 [AutoSync] Force sync requested');
    await _checkAndSync();
  }

  /// Synchronise les catégories (incluant budget_limit) vers Supabase
  Future<void> _syncCategories(String userId) async {
    final pending = await (_db.select(
      _db.categoriesTable,
    )..where((c) => c.syncStatus.equals(0))).get();

    if (pending.isEmpty) {
      debugPrint('📤 [Categories] No pending categories');
      return;
    }

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

  /// Synchronise les transactions non-sync vers Supabase
  Future<void> _syncTransactions(String userId) async {
    final pending = await (_db.select(
      _db.transactionsTable,
    )..where((t) => t.syncStatus.equals(0))).get();

    if (pending.isEmpty) {
      debugPrint('📤 [Transactions] No pending transactions');
      return;
    }

    debugPrint('📤 [Transactions] Syncing ${pending.length} transactions...');

    for (final tx in pending) {
      try {
        await _supabase.from('transactions').upsert({
          'id': tx.id,
          'user_id': userId,
          'amount': tx.amount,
          'type': tx.type,
          'merchant_name': tx.merchantName,
          // Pas de category_id/account_id pour éviter les FK errors
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

        // Marque comme synchronisé localement
        await (_db.update(_db.transactionsTable)
              ..where((t) => t.id.equals(tx.id)))
            .write(const TransactionsTableCompanion(syncStatus: Value(1)));

        debugPrint('✅ [Transactions] Synced ${tx.id}');
      } catch (e) {
        debugPrint('❌ [Transactions] Failed to sync ${tx.id}: $e');
      }
    }
  }

  /// Synchronise les comptes (tous, pas seulement pending)
  Future<void> _syncAccounts(String userId) async {
    // Sync ALL accounts, not just pending (to catch accounts created before AutoSync)
    final allAccounts = await _db.select(_db.accountsTable).get();

    if (allAccounts.isEmpty) {
      debugPrint('📤 [Accounts] No accounts to sync');
      return;
    }

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

  /// Synchronise les dettes
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

  /// Synchronise les objectifs
  Future<void> _syncGoals(String userId) async {
    final pending = await (_db.select(_db.goalsTable)).get();

    if (pending.isEmpty) return;

    debugPrint('📤 [Goals] Syncing ${pending.length} goals...');

    for (final goal in pending) {
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
}
