import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart' show databaseProvider;

/// Provider pour le service de synchronisation
final syncServiceProvider = Provider<SyncService>((ref) {
  final database = ref.watch(databaseProvider);
  return SyncService(database);
});

/// Service pour synchroniser les données locales vers Supabase
class SyncService {
  final AppDatabase _localDb;
  final SupabaseClient _supabase = Supabase.instance.client;

  SyncService(this._localDb);

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  /// ID de l'utilisateur connecté
  String? get userId => _supabase.auth.currentUser?.id;

  /// Synchronise toutes les données locales vers Supabase
  Future<SyncResult> syncAll() async {
    if (!isLoggedIn) {
      return SyncResult(success: false, message: 'Non connecté');
    }

    int categoriesCount = 0;
    int transactionsCount = 0;
    int goalsCount = 0;
    int debtsCount = 0;
    List<String> errors = [];

    try {
      // 1. Sync des catégories
      categoriesCount = await _syncCategories();
    } catch (e) {
      errors.add('Categories: $e');
    }

    try {
      // 2. Sync des transactions
      transactionsCount = await _syncTransactions();
    } catch (e) {
      errors.add('Transactions: $e');
    }

    try {
      // 3. Sync des objectifs
      goalsCount = await _syncGoals();
    } catch (e) {
      errors.add('Goals: $e');
    }

    try {
      // 4. Sync des dettes
      debtsCount = await _syncDebts();
    } catch (e) {
      errors.add('Debts: $e');
    }

    final total = categoriesCount + transactionsCount + goalsCount + debtsCount;
    return SyncResult(
      success: errors.isEmpty,
      message: errors.isEmpty
          ? '$total éléments synchronisés'
          : 'Sync partielle: ${errors.join(', ')}',
      categoriesCount: categoriesCount,
      transactionsCount: transactionsCount,
      goalsCount: goalsCount,
      debtsCount: debtsCount,
    );
  }

  /// Synchronise les catégories
  Future<int> _syncCategories() async {
    final categories = await _localDb.select(_localDb.categoriesTable).get();

    if (categories.isEmpty) return 0;

    final data = categories
        .map(
          (c) => {
            'id': c.id,
            'user_id': userId,
            'name': c.name,
            'icon_key': c.iconKey,
            'color': c.color,
            'keywords_json': c.keywordsJson,
            'parent_id': c.parentId,
            'is_system': c.isSystem,
            'budget_limit': c.budgetLimit,
            'sort_order': c.sortOrder,
            'created_at': c.createdAt.toIso8601String(),
            'updated_at': c.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await _supabase.from('categories').upsert(data, onConflict: 'id');

    return categories.length;
  }

  /// Synchronise les transactions
  Future<int> _syncTransactions() async {
    final transactions = await _localDb
        .select(_localDb.transactionsTable)
        .get();

    if (transactions.isEmpty) return 0;

    final data = transactions
        .map(
          (t) => {
            'id': t.id,
            'user_id': userId,
            'amount': t.amount,
            'type': t.type,
            'merchant_name': t.merchantName,
            'category_id': t.categoryId,
            'account_id': t.accountId,
            'date': t.date.toIso8601String(),
            'external_id': t.externalId,
            'is_ai_categorized': t.isAiCategorized,
            'validation_status': t.validationStatus,
            'created_at': t.createdAt.toIso8601String(),
            'updated_at': t.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await _supabase.from('transactions').upsert(data, onConflict: 'id');

    return transactions.length;
  }

  /// Synchronise les objectifs
  Future<int> _syncGoals() async {
    final goals = await _localDb.select(_localDb.goalsTable).get();

    if (goals.isEmpty) return 0;

    final data = goals
        .map(
          (g) => {
            'id': g.id,
            'user_id': userId,
            'name': g.name,
            'target_amount': g.targetAmount,
            'saved_amount': g.savedAmount,
            'icon_key': g.iconKey,
            'deadline': g.deadline?.toIso8601String(),
            'is_completed': g.isCompleted,
            'created_at': g.createdAt.toIso8601String(),
          },
        )
        .toList();

    await _supabase.from('goals').upsert(data, onConflict: 'id');

    return goals.length;
  }

  /// Synchronise les dettes
  Future<int> _syncDebts() async {
    final debts = await _localDb.select(_localDb.debtsTable).get();

    if (debts.isEmpty) return 0;

    final data = debts
        .map(
          (d) => {
            'id': d.id,
            'user_id': userId,
            'name': d.name,
            'amount': d.amount,
            'type': d.type,
            'due_date': d.dueDate.toIso8601String(),
            'status': d.status,
            'person_name': d.personName,
            'notes': d.notes,
            'is_recurring': d.isRecurring,
            'recurrence_rule': d.recurrenceRule,
            'notification_id': d.notificationId,
            'created_at': d.createdAt.toIso8601String(),
            'updated_at': d.updatedAt.toIso8601String(),
          },
        )
        .toList();

    await _supabase.from('debts').upsert(data, onConflict: 'id');

    return debts.length;
  }
}

/// Résultat de la synchronisation
class SyncResult {
  final bool success;
  final String message;
  final int categoriesCount;
  final int transactionsCount;
  final int goalsCount;
  final int debtsCount;

  SyncResult({
    required this.success,
    required this.message,
    this.categoriesCount = 0,
    this.transactionsCount = 0,
    this.goalsCount = 0,
    this.debtsCount = 0,
  });

  int get totalCount =>
      categoriesCount + transactionsCount + goalsCount + debtsCount;
}
