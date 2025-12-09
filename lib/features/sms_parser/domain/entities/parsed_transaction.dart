/// Types de transactions financières
enum TransactionType {
  /// Dépense (paiement marchand, achat, etc.)
  expense,

  /// Revenu (réception d'argent, salaire, etc.)
  income,

  /// Transfert entre comptes ou personnes
  transfer,
}

/// Opérateurs de Mobile Money et banques supportés au Gabon
enum MobileOperator {
  /// Airtel Money Gabon
  airtelMoney,

  /// Moov Money Gabon
  moovMoney,

  /// United Bank for Africa
  uba,

  /// Opérateur non reconnu
  unknown,
}

/// Transaction parsée à partir d'un SMS
///
/// Cette classe représente les données extraites d'un SMS bancaire/Mobile Money.
/// Elle est utilisée comme DTO (Data Transfer Object) avant conversion en entité DB.
///
/// Exemple d'utilisation:
/// ```dart
/// final parsed = smsParser.parseSms(sender, body);
/// if (parsed != null) {
///   // Créer une TransactionsTableData à partir de parsed
/// }
/// ```
class ParsedTransaction {
  /// Montant de la transaction en FCFA
  final double amount;

  /// Nom du marchand ou destinataire
  final String merchantName;

  /// ID de transaction fourni par l'opérateur (ex: PP123456)
  final String transactionId;

  /// Date et heure de la transaction (ou du SMS si non disponible)
  final DateTime date;

  /// Type de transaction (expense, income, transfer)
  final TransactionType type;

  /// Opérateur Mobile Money ou banque source
  final MobileOperator operator;

  /// Contenu brut du SMS (pour ré-entraînement IA)
  final String rawSmsContent;

  /// Expéditeur du SMS
  final String smsSender;

  const ParsedTransaction({
    required this.amount,
    required this.merchantName,
    required this.transactionId,
    required this.date,
    required this.type,
    required this.operator,
    required this.rawSmsContent,
    required this.smsSender,
  });

  /// Crée une copie avec des valeurs modifiées
  ParsedTransaction copyWith({
    double? amount,
    String? merchantName,
    String? transactionId,
    DateTime? date,
    TransactionType? type,
    MobileOperator? operator,
    String? rawSmsContent,
    String? smsSender,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      transactionId: transactionId ?? this.transactionId,
      date: date ?? this.date,
      type: type ?? this.type,
      operator: operator ?? this.operator,
      rawSmsContent: rawSmsContent ?? this.rawSmsContent,
      smsSender: smsSender ?? this.smsSender,
    );
  }

  @override
  String toString() {
    return 'ParsedTransaction('
        'amount: $amount FCFA, '
        'merchant: $merchantName, '
        'id: $transactionId, '
        'type: ${type.name}, '
        'operator: ${operator.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedTransaction &&
        other.amount == amount &&
        other.merchantName == merchantName &&
        other.transactionId == transactionId &&
        other.type == type &&
        other.operator == operator;
  }

  @override
  int get hashCode {
    return Object.hash(amount, merchantName, transactionId, type, operator);
  }
}
