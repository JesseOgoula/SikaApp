import 'package:drift/drift.dart';

/// Table des transactions financières
///
/// Stocke toutes les transactions extraites des SMS ou saisies manuellement.
/// Les clés primaires sont des UUIDs (TEXT) pour compatibilité PowerSync.
///
/// Champs:
/// - [id] : UUID unique de la transaction
/// - [amount] : Montant en FCFA
/// - [type] : Type de transaction (income/expense/transfer)
/// - [merchantName] : Nom du marchand/destinataire extrait du SMS
/// - [categoryId] : Référence vers la catégorie (FK vers CategoriesTable)
/// - [accountId] : Référence vers le compte source (FK vers AccountsTable)
/// - [date] : Date/heure de la transaction
/// - [smsSender] : Numéro/ID de l'expéditeur du SMS (Airtel, Moov, etc.)
/// - [smsRawContent] : Contenu brut du SMS (pour ré-entraînement IA)
/// - [externalId] : ID de transaction fourni par l'opérateur (PP123456)
/// - [isAiCategorized] : Indique si la catégorie a été prédite par l'IA
/// - [syncStatus] : Statut de synchronisation (0=pending, 1=synced, 2=error)
/// - [createdAt] : Date de création locale
/// - [updatedAt] : Date de dernière modification
class TransactionsTable extends Table {
  /// Nom de la table dans SQLite
  @override
  String get tableName => 'transactions';

  /// UUID unique - Clé primaire TEXT pour PowerSync
  TextColumn get id => text()();

  /// Montant de la transaction en FCFA
  RealColumn get amount => real()();

  /// Type: 'income', 'expense', 'transfer'
  TextColumn get type => text().withLength(min: 1, max: 20)();

  /// Nom du marchand ou destinataire (peut être null si non extrait)
  TextColumn get merchantName => text().nullable()();

  /// FK vers CategoriesTable (UUID)
  TextColumn get categoryId => text().nullable()();

  /// FK vers AccountsTable (UUID) - Compte source de la transaction
  TextColumn get accountId => text().nullable()();

  /// Date et heure de la transaction
  DateTimeColumn get date => dateTime()();

  /// Expéditeur du SMS (ex: "AirtelMoney", "MOOV", "UBA")
  TextColumn get smsSender => text().nullable()();

  /// Contenu brut du SMS pour ré-entraînement du modèle TFLite
  TextColumn get smsRawContent => text().nullable()();

  /// ID externe de transaction fourni par l'opérateur (ex: PP123456)
  TextColumn get externalId => text().nullable()();

  /// True si la catégorie a été assignée par l'IA (Smart Labeling)
  BoolColumn get isAiCategorized =>
      boolean().withDefault(const Constant(false))();

  /// Statut de synchronisation: 0=pending, 1=synced, 2=error
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  /// Statut de validation utilisateur: 0=PENDING, 1=VALIDATED, 2=REJECTED
  /// Utilisé pour le workflow "Human-in-the-loop" avec notifications actionnables
  IntColumn get validationStatus => integer().withDefault(const Constant(0))();

  /// Date de création locale
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Date de dernière modification
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Définition de la clé primaire (UUID)
  @override
  Set<Column> get primaryKey => {id};

  /// Index pour optimiser les requêtes fréquentes
  @override
  List<Set<Column>> get uniqueKeys => [
    {externalId}, // Évite les doublons de transactions SMS
  ];
}
