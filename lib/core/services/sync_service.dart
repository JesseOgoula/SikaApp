import 'package:flutter/foundation.dart';
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

    debugPrint('🔄 [Sync] Starting full sync...');

    int categoriesCount = 0;
    int transactionsCount = 0;
    int goalsCount = 0;
    List<String> errors = [];

    try {
      // 1. Sync des catégories
      categoriesCount = await _syncCategories();
      debugPrint('✅ [Sync] Categories: $categoriesCount');
    } catch (e) {
      errors.add('Categories: $e');
      debugPrint('❌ [Sync] Categories error: $e');
    }

    try {
      // 2. Sync des transactions
      transactionsCount = await _syncTransactions();
      debugPrint('✅ [Sync] Transactions: $transactionsCount');
    } catch (e) {
      errors.add('Transactions: $e');
      debugPrint('❌ [Sync] Transactions error: $e');
    }

    try {
      // 3. Sync des objectifs
      goalsCount = await _syncGoals();
      debugPrint('✅ [Sync] Goals: $goalsCount');
    } catch (e) {
      errors.add('Goals: $e');
      debugPrint('❌ [Sync] Goals error: $e');
    }

    final total = categoriesCount + transactionsCount + goalsCount;
    debugPrint('✅ [Sync] Complete! Total: $total items');

    return SyncResult(
      success: errors.isEmpty,
      message: errors.isEmpty
          ? '$total éléments synchronisés'
          : 'Sync partielle: ${errors.join(', ')}',
      categoriesCount: categoriesCount,
      transactionsCount: transactionsCount,
      goalsCount: goalsCount,
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
            'sms_sender': t.smsSender,
            'sms_raw_content': t.smsRawContent,
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
}

/// Résultat de la synchronisation
class SyncResult {
  final bool success;
  final String message;
  final int categoriesCount;
  final int transactionsCount;
  final int goalsCount;

  SyncResult({
    required this.success,
    required this.message,
    this.categoriesCount = 0,
    this.transactionsCount = 0,
    this.goalsCount = 0,
  });

  int get totalCount => categoriesCount + transactionsCount + goalsCount;
}
