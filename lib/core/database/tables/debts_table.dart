import 'package:drift/drift.dart';

/// Table pour gérer les dettes et factures
/// Compatible avec la table 'debts' de Supabase
class DebtsTable extends Table {
  // Identifiant unique (UUID)
  TextColumn get id => text()();

  // Clé étrangère vers l'utilisateur (Supabase Auth)
  TextColumn get userId => text()();

  // Nom de la dette/facture
  TextColumn get name => text().withLength(min: 1, max: 100)();

  // Montant
  RealColumn get amount => real()();

  // Type: 'debt_in' (créance), 'debt_out' (dette), 'bill' (facture)
  TextColumn get type => text()();

  // Date d'échéance
  DateTimeColumn get dueDate => dateTime()();

  // Statut: 'pending', 'paid', 'overdue'
  TextColumn get status => text().withDefault(const Constant('pending'))();

  // Nom de la personne/organisme lié
  TextColumn get personName => text().nullable()();

  // Notes optionnelles
  TextColumn get notes => text().nullable()();

  // Récurrence
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurrenceRule => text().nullable()(); // Ex: 'monthly'

  // ID pour la notification locale
  IntColumn get notificationId => integer().nullable()();

  // Champs techniques
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
