import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

import 'package:sika_app/core/services/notification_service.dart';

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
            type: debt.type.name, // Enum to String
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

    // Schedule notification
    if (debt.status == DebtStatus.pending) {
      await NotificationService().scheduleDebtReminder(
        id: notifId,
        title: _getNotificationTitle(debt),
        body: _getNotificationBody(debt),
        dueDate: debt.dueDate,
      );
    }
  }

  String _getNotificationTitle(Debt debt) {
    switch (debt.type) {
      case DebtType.bill:
        return 'Facture à payer demain';
      case DebtType.debtOut:
        return 'Dette à rembourser demain';
    }
  }

  String _getNotificationBody(Debt debt) {
    return '${debt.name} - ${debt.amount.toStringAsFixed(0)} FCFA';
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    await (_db.update(
      _db.debtsTable,
    )..where((t) => t.id.equals(debt.id))).write(
      DebtsTableCompanion(
        name: Value(debt.name),
        amount: Value(debt.amount),
        type: Value(debt.type.name),
        dueDate: Value(debt.dueDate),
        status: Value(debt.status.name),
        personName: Value(debt.personName),
        notes: Value(debt.notes),
        isRecurring: Value(debt.isRecurring),
        recurrenceRule: Value(debt.recurrenceRule),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteDebt(String id) async {
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
    // 1. Mettre à jour le statut
    final updatedDebt = debt.copyWith(
      status: DebtStatus.paid,
      updatedAt: DateTime.now(),
    );
    await updateDebt(updatedDebt);

    // 2. Créer une transaction si demandé
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
              date: DateTime.now(),
              syncStatus: const Value(0),
              validationStatus: const Value(
                1,
              ), // 1 = validated, apparaît dans les transactions
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
        ),
      );
    }
  }

  @override
  Future<double> getTotalPendingDebt() async {
    final query = _db.select(_db.debtsTable)
      ..where((t) => t.status.isIn(['pending', 'overdue']));

    final results = await query.get();
    return results.fold<double>(0.0, (sum, row) => sum + row.amount);
  }

  Debt _mapToEntity(DebtsTableData row) {
    return Debt(
      id: row.id,
      userId: row.userId,
      name: row.name,
      amount: row.amount,
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
    return DebtType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DebtType.bill,
    );
  }

  DebtStatus _parseStatus(String value) {
    return DebtStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DebtStatus.pending,
    );
  }
}
