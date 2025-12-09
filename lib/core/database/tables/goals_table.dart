import 'package:drift/drift.dart';

/// Table des objectifs d'épargne
///
/// Stocke les goals de l'utilisateur avec leur progression.
class GoalsTable extends Table {
  /// UUID unique de l'objectif
  TextColumn get id => text()();

  /// Nom de l'objectif (ex: "PC Portable", "Vacances")
  TextColumn get name => text()();

  /// Montant cible à atteindre (en FCFA)
  RealColumn get targetAmount => real()();

  /// Montant déjà épargné (en FCFA)
  RealColumn get savedAmount => real().withDefault(const Constant(0))();

  /// Icône de l'objectif (codePoint ou nom)
  TextColumn get iconKey => text().nullable()();

  /// Date limite souhaitée (optionnelle)
  DateTimeColumn get deadline => dateTime().nullable()();

  /// Objectif atteint ou non
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Date de création
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
