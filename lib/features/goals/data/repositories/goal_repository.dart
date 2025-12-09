import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/main.dart';

/// Provider pour le GoalRepository
final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalRepository(db);
});

/// Provider pour la liste des objectifs actifs (stream)
final activeGoalsProvider = StreamProvider<List<GoalsTableData>>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return repo.watchActiveGoals();
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
    await _db
        .into(_db.goalsTable)
        .insert(
          GoalsTableCompanion.insert(
            id: _uuid.v4(),
            name: name,
            targetAmount: targetAmount,
            iconKey: Value(iconKey),
            deadline: Value(deadline),
          ),
        );
  }

  /// Ajouter de l'épargne à un objectif
  Future<void> addSavings(String goalId, double amount) async {
    final goal = await (_db.select(
      _db.goalsTable,
    )..where((g) => g.id.equals(goalId))).getSingleOrNull();

    if (goal != null) {
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
    await (_db.delete(_db.goalsTable)..where((g) => g.id.equals(goalId))).go();
  }

  /// Alimenter un objectif (ajoute épargne + crée transaction)
  ///
  /// Exécute une transaction atomique:
  /// 1. Met à jour savedAmount dans Goals
  /// 2. Crée une Transaction de type EXPENSE catégorisée "Épargne"
  Future<bool> feedGoal(String goalId, double amount) async {
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

      // 2. Créer une transaction "Dépense d'épargne"
      await _db
          .into(_db.transactionsTable)
          .insert(
            TransactionsTableCompanion.insert(
              id: _uuid.v4(),
              amount: amount,
              type: 'expense',
              merchantName: Value('Épargne : ${goal.name}'),
              categoryId: const Value('cat-epargne'),
              date: DateTime.now(),
              smsSender: const Value('MANUAL_SAVING'),
              smsRawContent: const Value(''),
              validationStatus: const Value(1),
              syncStatus: const Value(0),
            ),
          );
    });

    return true;
  }

  /// Récupérer un objectif par son ID
  Future<GoalsTableData?> getGoalById(String goalId) async {
    return await (_db.select(
      _db.goalsTable,
    )..where((g) => g.id.equals(goalId))).getSingleOrNull();
  }
}
