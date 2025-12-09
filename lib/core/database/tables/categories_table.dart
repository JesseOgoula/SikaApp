import 'package:drift/drift.dart';

/// Table des catégories de transactions
///
/// Utilisée pour classifier les transactions (Alimentation, Transport, etc.)
/// Le champ [keywordsJson] est crucial pour le Smart Labeling (IA locale TFLite).
///
/// Exemple de keywordsJson:
/// ```json
/// {
///   "keywords": ["pharmacie", "hopital", "clinique", "docteur"],
///   "patterns": [".*PHARMA.*", ".*SANTE.*"],
///   "confidence_boost": 0.2
/// }
/// ```
///
/// Champs:
/// - [id] : UUID unique de la catégorie
/// - [name] : Nom de la catégorie (ex: "Alimentation")
/// - [iconKey] : Clé d'icône Material (ex: "restaurant")
/// - [color] : Couleur hexadécimale pour l'UI
/// - [keywordsJson] : JSON contenant les mots-clés pour l'IA
/// - [parentId] : UUID de la catégorie parente (sous-catégories)
/// - [isSystem] : True si catégorie par défaut (non supprimable)
/// - [budgetLimit] : Limite de budget mensuel optionnelle
class CategoriesTable extends Table {
  /// Nom de la table dans SQLite
  @override
  String get tableName => 'categories';

  /// UUID unique - Clé primaire TEXT pour PowerSync
  TextColumn get id => text()();

  /// Nom de la catégorie
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// Clé d'icône Material Design (ex: "restaurant", "local_taxi")
  TextColumn get iconKey => text().withDefault(const Constant('category'))();

  /// Couleur hexadécimale pour l'UI (ex: "#E91E63")
  TextColumn get color => text().withDefault(const Constant('#9E9E9E'))();

  /// JSON contenant les mots-clés et patterns pour le Smart Labeling
  /// Structure: { "keywords": [...], "patterns": [...], "confidence_boost": 0.0 }
  TextColumn get keywordsJson => text().withDefault(const Constant('{}'))();

  /// UUID de la catégorie parente (pour les sous-catégories)
  TextColumn get parentId => text().nullable()();

  /// True si c'est une catégorie système (non supprimable par l'utilisateur)
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Limite de budget mensuel en FCFA (optionnel)
  RealColumn get budgetLimit => real().nullable()();

  /// Ordre d'affichage dans la liste
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Statut de synchronisation: 0=pending, 1=synced, 2=error
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Date de création locale
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Date de dernière modification
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Définition de la clé primaire (UUID)
  @override
  Set<Column> get primaryKey => {id};
}
