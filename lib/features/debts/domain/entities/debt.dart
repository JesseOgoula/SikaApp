import 'package:equatable/equatable.dart';

enum DebtType {
  debtIn, // On me doit de l'argent (Créance)
  debtOut, // Je dois de l'argent (Dette)
  bill, // Facture à payer
}

enum DebtStatus {
  pending, // En attente
  paid, // Payé
  overdue, // En retard
}

class Debt extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final DebtType type;
  final DateTime dueDate;
  final DebtStatus status;
  final String? personName;
  final String? notes;
  final bool isRecurring;
  final String? recurrenceRule;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.type,
    required this.dueDate,
    this.status = DebtStatus.pending,
    this.personName,
    this.notes,
    this.isRecurring = false,
    this.recurrenceRule,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    amount,
    type,
    dueDate,
    status,
    personName,
    notes,
    isRecurring,
    recurrenceRule,
    notificationId,
    createdAt,
    updatedAt,
  ];

  Debt copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    DebtType? type,
    DateTime? dueDate,
    DebtStatus? status,
    String? personName,
    String? notes,
    bool? isRecurring,
    String? recurrenceRule,
    int? notificationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      personName: personName ?? this.personName,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
