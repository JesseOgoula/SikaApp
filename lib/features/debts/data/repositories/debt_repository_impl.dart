import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/main.dart' show autoSyncService;
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

class DebtRepositoryImpl implements DebtRepository {
  final AppDatabase _db;
  final Ref _ref;

  DebtRepositoryImpl(this._db, this._ref);

  @override
  Stream<List<Debt>> watchAllDebts() {
    return (_db.select(_db.debtsTable)..orderBy([
          (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
        ]))
        .watch()
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Stream<double> watchPendingBillsAmountForCurrentMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.debtsTable)
      ..where((t) => t.type.equals('bill'))
      ..where((t) => t.status.equals('pending'))
      ..where((t) => t.dueDate.isBetweenValues(startOfMonth, endOfMonth));

    return query.watch().map((rows) {
      return rows.fold(0.0, (sum, row) => sum + row.amount);
    });
  }

  @override
  Future<void> addDebt(Debt debt) async {
    // Generate notification ID (using hashCode for simplicity, assuming unique enough for local notifs)
    final notifId = debt.id.hashCode;

    await _db
        .into(_db.debtsTable)
        .insert(
          DebtsTableCompanion.insert(
            id: debt.id,
            userId: debt.userId,
            name: debt.name,
            amount: debt.amount,
            paidAmount: Value(debt.paidAmount),
            type: _toDbType(debt.type),
            dueDate: debt.dueDate,
            status: Value(debt.status.name),
            personName: Value(debt.personName),
            notes: Value(debt.notes),
            isRecurring: Value(debt.isRecurring),
            recurrenceRule: Value(debt.recurrenceRule),
            notificationId: Value(notifId),
            updatedAt: Value(DateTime.now()),
          ),
        );

    // Schedule notifications
    if (debt.status == DebtStatus.pending) {
      await NotificationService().scheduleDebtReminders(
        debtId: debt.id,
        title: debt.name,
        amount: debt.amount,
        dueDate: debt.dueDate,
      );
    }

    // Sync vers Supabase
    autoSyncService?.forceSync();

    // Award XP for adding debt
    XPService().awardXP(ActionType.addDebt);
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    await (_db.update(
      _db.debtsTable,
    )..where((t) => t.id.equals(debt.id))).write(
      DebtsTableCompanion(
        name: Value(debt.name),
        amount: Value(debt.amount),
        paidAmount: Value(debt.paidAmount),
        type: Value(_toDbType(debt.type)),
        dueDate: Value(debt.dueDate),
        status: Value(debt.status.name),
        personName: Value(debt.personName),
        notes: Value(debt.notes),
        isRecurring: Value(debt.isRecurring),
        recurrenceRule: Value(debt.recurrenceRule),
        syncStatus: const Value(0), // Marquer pour re-sync
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Re-schedule notifications if still pending
    if (debt.status == DebtStatus.pending) {
      await NotificationService().cancelDebtReminders(debt.id);
      await NotificationService().scheduleDebtReminders(
        debtId: debt.id,
        title: debt.name,
        amount: debt.amount,
        dueDate: debt.dueDate,
      );
    } else {
      // Cancel notifications if paid or overdue
      await NotificationService().cancelDebtReminders(debt.id);
    }

    // Sync vers Supabase
    autoSyncService?.forceSync();
  }

  @override
  Future<void> deleteDebt(String id) async {
    // Cancel notifications before deleting
    await NotificationService().cancelDebtReminders(id);

    // Supprimer de Supabase si connecté
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client
            .from('debts')
            .delete()
            .eq('id', id)
            .eq('user_id', user.id);
      }
    } catch (_) {
      // Ignorer les erreurs Supabase — suppression locale prioritaire
    }

    // Supprimer localement
    await (_db.delete(_db.debtsTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> checkOverdueDebts() async {
    final now = DateTime.now();
    await (_db.update(_db.debtsTable)
          ..where((t) => t.status.equals('pending'))
          ..where((t) => t.dueDate.isSmallerThanValue(now)))
        .write(const DebtsTableCompanion(status: Value('overdue')));
  }

  @override
  Future<void> markAsPaid(
    Debt debt, {
    bool createTransaction = true,
    String? accountId,
    String? categoryId,
  }) async {
    // 1. Préparer le nouveau statut
    final updatedDebt = debt.copyWith(
      status: DebtStatus.paid,
      updatedAt: DateTime.now(),
    );

    // 2. Exécuter toutes les mises à jour de DB dans une transaction atomique
    await _db.transaction(() async {
      await (_db.update(
        _db.debtsTable,
      )..where((t) => t.id.equals(debt.id))).write(
        DebtsTableCompanion(
          status: Value(updatedDebt.status.name),
          syncStatus: const Value(0),
          updatedAt: Value(updatedDebt.updatedAt),
        ),
      );

      // Créer une transaction si demandé
      if (createTransaction && accountId != null) {
        // Pour les factures et dettes sortantes, c'est toujours une dépense (expense)
        await _db
            .into(_db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: const Uuid().v4(),
                amount: debt.amount,
                type: 'expense',
                merchantName: Value(debt.personName ?? debt.name),
                categoryId: Value(categoryId),
                accountId: Value(accountId),
                debtId: Value(debt.id),
                date: DateTime.now(),
                syncStatus: const Value(0),
                validationStatus: const Value(1),
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );

        // Mettre à jour le solde du compte
        final account = await (_db.select(
          _db.accountsTable,
        )..where((t) => t.id.equals(accountId))).getSingle();

        await (_db.update(
          _db.accountsTable,
        )..where((t) => t.id.equals(accountId))).write(
          AccountsTableCompanion(
            balance: Value(account.balance - debt.amount),
            updatedAt: Value(DateTime.now()),
            syncStatus: const Value(0),
          ),
        );
      }
    });

    // 3. Effectuer les opérations non-critiques (notifications, sync, XP)
    try {
      await NotificationService().cancelDebtReminders(debt.id);
    } catch (e) {
      // Ignorer les erreurs de notification pour ne pas bloquer l'UI
    }

    try {
      autoSyncService?.forceSync();
    } catch (e) {
      // Ignorer
    }

    XPService().awardXP(ActionType.payDebt);
  }

  @override
  Future<double> getTotalPendingDebt() async {
    final query = _db.select(_db.debtsTable)
      ..where((t) => t.status.isIn(['pending', 'overdue']))
      ..where((t) => t.type.isNotIn(['debt_in', 'debtIn']));

    final results = await query.get();
    return results.fold<double>(0.0, (sum, row) => sum + (row.amount - (row.paidAmount ?? 0.0)));
  }

  @override
  Future<double> getTotalPendingIncome() async {
    final query = _db.select(_db.debtsTable)
      ..where((t) => t.status.isIn(['pending', 'overdue']))
      ..where((t) => t.type.isIn(['debt_in', 'debtIn']));

    final results = await query.get();
    return results.fold<double>(0.0, (sum, row) => sum + (row.amount - (row.paidAmount ?? 0.0)));
  }

  @override
  Future<void> addPayment({
    required Debt debt,
    required double amount,
    required String accountId,
    String? categoryId,
  }) async {
    final newPaidAmount = debt.paidAmount + amount;
    final isFullyPaid = newPaidAmount >= debt.amount;

    final updatedDebt = debt.copyWith(
      paidAmount: newPaidAmount,
      status: isFullyPaid ? DebtStatus.paid : debt.status,
      updatedAt: DateTime.now(),
    );

    // 1. Transaction atomique pour la DB
    await _db.transaction(() async {
      // Mettre à jour la dette
      await (_db.update(
        _db.debtsTable,
      )..where((t) => t.id.equals(debt.id))).write(
        DebtsTableCompanion(
          paidAmount: Value(updatedDebt.paidAmount),
          status: Value(updatedDebt.status.name),
          syncStatus: const Value(0),
          updatedAt: Value(updatedDebt.updatedAt),
        ),
      );

      // Créer une transaction de type revenu ou dépense
      await _db
          .into(_db.transactionsTable)
          .insert(
            TransactionsTableCompanion.insert(
              id: const Uuid().v4(),
              amount: amount,
              type: debt.type == DebtType.debtIn ? 'income' : 'expense',
              merchantName: Value(debt.personName ?? debt.name),
              categoryId: Value(categoryId),
              accountId: Value(accountId),
              debtId: Value(debt.id),
              date: DateTime.now(),
              syncStatus: const Value(0),
              validationStatus: const Value(1),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Mettre à jour le solde du compte
      final account = await (_db.select(
        _db.accountsTable,
      )..where((t) => t.id.equals(accountId))).getSingle();

      await (_db.update(
        _db.accountsTable,
      )..where((t) => t.id.equals(accountId))).write(
        AccountsTableCompanion(
          balance: Value(
            debt.type == DebtType.debtIn
                ? account.balance + amount
                : account.balance - amount,
          ),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(0),
        ),
      );
    });

    // 2. Mettre à jour les notifications et sync (non-bloquant)
    try {
      if (updatedDebt.status == DebtStatus.pending) {
        await NotificationService().cancelDebtReminders(debt.id);
        await NotificationService().scheduleDebtReminders(
          debtId: debt.id,
          title: debt.name,
          amount: debt.amount,
          dueDate: debt.dueDate,
        );
      } else {
        await NotificationService().cancelDebtReminders(debt.id);
      }
    } catch (e) {
      // Ignorer pour éviter les crashs silencieux
    }

    try {
      autoSyncService?.forceSync();
    } catch (e) {
      // Ignorer
    }

    // Award XP
    XPService().awardXP(ActionType.payDebt); // On réutilise cette action
  }

  Debt _mapToEntity(DebtsTableData row) {
    return Debt(
      id: row.id,
      userId: row.userId,
      name: row.name,
      amount: row.amount,
      paidAmount: row.paidAmount,
      type: _parseType(row.type),
      dueDate: row.dueDate,
      status: _parseStatus(row.status),
      personName: row.personName,
      notes: row.notes,
      isRecurring: row.isRecurring,
      recurrenceRule: row.recurrenceRule,
      notificationId: row.notificationId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DebtType _parseType(String value) {
    switch (value) {
      case 'debt_in':
      case 'debtIn':
        return DebtType.debtIn;
      case 'debt_out':
      case 'debtOut':
        return DebtType.debtOut;
      case 'bill':
      default:
        return DebtType.bill;
    }
  }

  String _toDbType(DebtType type) {
    switch (type) {
      case DebtType.debtIn:
        return 'debt_in';
      case DebtType.debtOut:
        return 'debt_out';
      case DebtType.bill:
        return 'bill';
    }
  }

  DebtStatus _parseStatus(String value) {
    return DebtStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DebtStatus.pending,
    );
  }
}
