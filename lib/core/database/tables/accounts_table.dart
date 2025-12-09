import 'package:drift/drift.dart';

/// Types de comptes supportés par l'application
///
/// - bank : Compte bancaire traditionnel (UBA, BGFI, etc.)
/// - mobileMoney : Mobile Money (Airtel Money, Moov Money)
/// - cash : Espèces / Portefeuille physique
enum AccountType { bank, mobileMoney, cash }

/// Table des comptes financiers
///
/// Représente les différentes sources d'argent de l'utilisateur.
/// Permet de suivre les soldes par compte et de catégoriser les transactions.
///
/// Champs:
/// - [id] : UUID unique du compte
/// - [name] : Nom personnalisé du compte (ex: "Airtel Money Principal")
/// - [type] : Type de compte (bank/mobileMoney/cash)
/// - [balance] : Solde actuel en FCFA
/// - [currency] : Devise (par défaut XAF)
/// - [phoneNumber] : Numéro associé (pour Mobile Money)
/// - [iconKey] : Clé d'icône pour l'affichage
/// - [color] : Couleur hexadécimale pour l'UI
/// - [isDefault] : Compte par défaut pour les nouvelles transactions
/// - [isActive] : Compte actif (non archivé)
class AccountsTable extends Table {
  /// Nom de la table dans SQLite
  @override
  String get tableName => 'accounts';

  /// UUID unique - Clé primaire TEXT pour PowerSync
  TextColumn get id => text()();

  /// Nom du compte défini par l'utilisateur
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Type de compte: 'bank', 'mobileMoney', 'cash'
  TextColumn get type => text().withLength(min: 1, max: 20)();

  /// Solde actuel en FCFA
  RealColumn get balance => real().withDefault(const Constant(0.0))();

  /// Code devise ISO (XAF pour FCFA)
  TextColumn get currency => text().withDefault(const Constant('XAF'))();

  /// Numéro de téléphone associé (Mobile Money)
  TextColumn get phoneNumber => text().nullable()();

  /// Clé d'icône pour l'affichage dans l'UI
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();

  /// Couleur hexadécimale pour l'UI (ex: "#FF5733")
  TextColumn get color => text().withDefault(const Constant('#4CAF50'))();

  /// Indique si c'est le compte par défaut
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Indique si le compte est actif (non archivé)
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

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
