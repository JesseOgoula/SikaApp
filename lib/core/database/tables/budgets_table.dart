import 'package:drift/drift.dart';

/// Table des budgets avec fonctionnalités avancées
///
/// Stocke les budgets définis par l'utilisateur avec support des périodes et historique.
class BudgetsTable extends Table {
  @override
  String get tableName => 'budgets';

  /// UUID unique (généré côté app ou serveur)
  TextColumn get id => text()();

  /// ID de la catégorie associée (FK logique vers CategoriesTable)
  /// Pour le budget global: 'global'
  TextColumn get categoryId => text()();

  /// Nom de la catégorie (dénormalisé pour l'historique)
  /// Pour le budget global: 'Budget Mensuel'
  TextColumn get categoryName => text()();

  /// ID du budget parent (null = budget de catégorie ou budget global, non-null = sous-budget)
  TextColumn get parentBudgetId => text().nullable()();

  /// Montant du budget
  RealColumn get amount => real()();

  /// Type de période: 'weekly', 'monthly', 'quarterly', 'yearly', 'custom'
  TextColumn get periodType => text().withDefault(const Constant('monthly'))();

  /// Date de début de la période
  DateTimeColumn get startDate => dateTime()();

  /// Date de fin de la période (nullable si récurrent sans fin définie, mais généralement calculé)
  DateTimeColumn get endDate => dateTime().nullable()();

  /// True si le budget est actif
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Seuil d'alerte en pourcentage (ex: 80.0 pour 80%)
  RealColumn get alertThreshold => real().withDefault(const Constant(80.0))();

  /// Statut de synchronisation: 0=pending, 1=synced, 2=error
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Date de création
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Date de dernière mise à jour
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Clé primaire
  @override
  Set<Column> get primaryKey => {id};
}
