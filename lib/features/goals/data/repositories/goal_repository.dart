import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/main.dart' show autoSyncService, databaseProvider;
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Provider pour le GoalRepository
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalRepository(db);
});

/// Provider pour la liste de tous les objectifs (stream)
final activeGoalsProvider = StreamProvider<List<GoalsTableData>>((ref) {
  ref.keepAlive(); // Garde en cache pour navigation instantanée
  final repo = ref.watch(goalRepositoryProvider);
  return repo.watchAllGoals();
});

/// Repository pour gérer les objectifs d'épargne
class GoalRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  GoalRepository(this._db);

  /// Stream des objectifs actifs (non terminés)
  Stream<List<GoalsTableData>> watchActiveGoals() {
    return (_db.select(_db.goalsTable)
          ..where((g) => g.isCompleted.equals(false))
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  /// Stream de tous les objectifs
  Stream<List<GoalsTableData>> watchAllGoals() {
    return (_db.select(_db.goalsTable)..orderBy([
          (g) => OrderingTerm.asc(g.isCompleted),
          (g) => OrderingTerm.desc(g.createdAt),
        ]))
        .watch();
  }

  /// Ajouter un nouvel objectif
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    String? iconKey,
    DateTime? deadline,
  }) async {
    final goalId = _uuid.v4();

    await _db
        .into(_db.goalsTable)
        .insert(
          GoalsTableCompanion.insert(
            id: goalId,
            name: name,
            targetAmount: targetAmount,
            iconKey: Value(iconKey),
            deadline: Value(deadline),
          ),
        );

    // Schedule weekly reminder (non-blocking)
    try {
      await NotificationService().scheduleWeeklyGoalReminder(
        goalId: goalId,
        goalName: name,
        currentAmount: 0,
        targetAmount: targetAmount,
      );
    } catch (e) {
      debugPrint('⚠️ [Goals] Notification scheduling failed: $e');
    }

    // Sync vers Supabase
    autoSyncService?.forceSync();

    // Award XP for creating goal
    XPService().awardXP(ActionType.createGoal);
  }

  /// Ajouter de l'épargne à un objectif
  Future<void> addSavings(String goalId, double amount) async {
    final goal = await (_db.select(
      _db.goalsTable,
    )..where((g) => g.id.equals(goalId))).getSingleOrNull();

    if (goal != null) {
      final newSavedAmount = goal.savedAmount + amount;
      final isNowCompleted = newSavedAmount >= goal.targetAmount;
      final wasNotCompleted = !goal.isCompleted;

      await (_db.update(
        _db.goalsTable,
      )..where((g) => g.id.equals(goalId))).write(
        GoalsTableCompanion(
          savedAmount: Value(newSavedAmount),
          isCompleted: Value(isNowCompleted),
        ),
      );

      // Show celebration if just completed
      if (isNowCompleted && wasNotCompleted) {
        try {
          await NotificationService().showGoalCompletedNotification(
            goalName: goal.name,
            amount: newSavedAmount,
          );
          await NotificationService().cancelGoalReminder(goalId);
        } catch (e) {
          debugPrint('⚠️ [Goals] Celebration notification failed: $e');
        }

        // Award XP for reaching goal
        XPService().awardXP(ActionType.reachGoal);
      } else {
        try {
          await NotificationService().scheduleWeeklyGoalReminder(
            goalId: goalId,
            goalName: goal.name,
            currentAmount: newSavedAmount,
            targetAmount: goal.targetAmount,
          );
        } catch (e) {
          debugPrint('⚠️ [Goals] Reminder update failed: $e');
        }
      }

      // Sync vers Supabase
      autoSyncService?.forceSync();
    }
  }

  /// Marquer un objectif comme terminé
  Future<void> markAsCompleted(String goalId) async {
    await (_db.update(_db.goalsTable)..where((g) => g.id.equals(goalId))).write(
      const GoalsTableCompanion(isCompleted: Value(true)),
    );
  }

  /// Supprimer un objectif
  Future<void> deleteGoal(String goalId) async {
    // Cancel weekly reminder (non-blocking)
    try {
      await NotificationService().cancelGoalReminder(goalId);
    } catch (e) {
      debugPrint('⚠️ [Goals] Cancel reminder failed: $e');
    }

    // Supprimer localement
    await (_db.delete(_db.goalsTable)..where((g) => g.id.equals(goalId))).go();

    // Supprimer sur Supabase
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('goals')
            .delete()
            .eq('id', goalId)
            .eq('user_id', user.id);
      }
    } catch (e) {
      debugPrint('❌ [Goals] Error deleting from Supabase: $e');
    }

    // Sync
    autoSyncService?.forceSync();
  }

  /// Alimenter un objectif (ajoute épargne + crée transaction)
  ///
  /// Exécute une transaction atomique:
  /// 1. Met à jour savedAmount dans Goals
  /// 2. Crée une Transaction de type EXPENSE catégorisée "Épargne"
  ///    rattachée au compte [accountId] pour impacter le solde
  Future<bool> feedGoal(String goalId, double amount, String accountId) async {
    // Récupérer l'objectif
    final goal = await (_db.select(
      _db.goalsTable,
    )..where((g) => g.id.equals(goalId))).getSingleOrNull();

    if (goal == null) return false;

    // Exécuter en transaction atomique
    await _db.transaction(() async {
      // 1. Mettre à jour le montant épargné
      final newSavedAmount = goal.savedAmount + amount;
      final isNowCompleted = newSavedAmount >= goal.targetAmount;

      await (_db.update(
        _db.goalsTable,
      )..where((g) => g.id.equals(goalId))).write(
        GoalsTableCompanion(
          savedAmount: Value(newSavedAmount),
          isCompleted: Value(isNowCompleted),
        ),
      );

      // 2. Créer une transaction "Dépense d'épargne" liée au compte
      await _db
          .into(_db.transactionsTable)
          .insert(
            TransactionsTableCompanion.insert(
              id: _uuid.v4(),
              amount: amount,
              type: 'expense',
              merchantName: Value('Épargne : ${goal.name}'),
              categoryId: const Value('cat-epargne'),
              accountId: Value(accountId),
              date: DateTime.now(),
              smsSender: const Value('MANUAL_SAVING'),
              smsRawContent: const Value(''),
              validationStatus: const Value(1),
              syncStatus: const Value(0),
            ),
          );
    });

    // Sync vers Supabase
    autoSyncService?.forceSync();

    // Award XP for feeding goal
    XPService().awardXP(ActionType.feedGoal);

    return true;
  }

  /// Récupérer un objectif par son ID
  Future<GoalsTableData?> getGoalById(String goalId) async {
    return await (_db.select(
      _db.goalsTable,
    )..where((g) => g.id.equals(goalId))).getSingleOrNull();
  }

  /// Récupérer le total épargné sur tous les objectifs
  Future<double> getTotalSavedAmount() async {
    final goals = await _db.select(_db.goalsTable).get();
    return goals.fold<double>(0, (sum, goal) => sum + goal.savedAmount);
  }
}
