import '../../domain/entities/parsed_transaction.dart';

/// Service de parsing des SMS bancaires et Mobile Money
///
/// Patterns basés sur les VRAIS SMS du terrain gabonais.
///
/// Opérateurs supportés:
/// - Airtel Money Gabon
/// - Moov Money Gabon
/// - UBA Gabon (sender: UBAGAB)
class SmsParserService {
  // ==================== IDENTIFIANTS EXPÉDITEURS ====================

  /// Expéditeurs Airtel Money connus
  static final List<String> _airtelSenders = [
    'airtelmoney',
    'airtel',
    'airtel money',
    'am',
    '6100',
    '6200',
    '241',
  ];

  /// Expéditeurs Moov Money connus
  static final List<String> _moovSenders = [
    'moovmoney',
    'moov',
    'moov money',
    'flooz',
    '6300',
    '6400',
  ];

  /// Expéditeurs UBA connus (AJOUT: UBAGAB)
  static final List<String> _ubaSenders = [
    'uba',
    'ubagab', // Format réel UBA Gabon
    'ubagroup',
    'uba gabon',
    '5500',
  ];

  // ==================== PATTERNS AIRTEL MONEY (VRAIS FORMATS) ====================

  /// PAIEMENT EBILLING / MARCHAND
  /// Exemple: "Paiement de 7143 F EBILLING pour ref 5573537922 DigitechPrepai a ete effectue avec succes. Cout: 71.43 FCFA. Solde 380.58F. TID: MP251208..."
  static final RegExp _airtelPaymentEbilling = RegExp(
    r'Paiement\s+de\s*([\d\s]+)\s*[F|FCFA]\s+(.+?)\s+(?:pour\s+ref|a\s+ete\s+effectue)',
    caseSensitive: false,
    unicode: true,
  );

  /// PAIEMENT MARCHAND (format alternatif)
  /// Exemple: "Paiement de 2500 F a PHARMACIE DU CENTRE effectue. TID: PP123456"
  static final RegExp _airtelPaymentMerchant = RegExp(
    r'Paiement\s+de\s*([\d\s]+)\s*[F|FCFA]\s+(?:a\s+)?(.+?)\s+(?:effectue|a\s+ete)',
    caseSensitive: false,
    unicode: true,
  );

  /// RÉCEPTION D'ARGENT (Format Court)
  /// Exemple: "Recu 3000FCFA du A67355. Solde actuel 3380.58FCFA. TID:CI251208..."
  static final RegExp _airtelReceiveShort = RegExp(
    r'Recu\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:du|de)\s*(.+?)\.\s*Solde',
    caseSensitive: false,
    unicode: true,
  );

  /// RÉCEPTION D'ARGENT (Format Long)
  /// Exemple: "Vous avez recu 10000 FCFA de JEAN DUPONT. TID: CI251208..."
  static final RegExp _airtelReceiveLong = RegExp(
    r'(?:Vous\s+avez\s+)?[Rr]ecu\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:du|de)\s*(.+?)(?:\.|Solde|TID)',
    caseSensitive: false,
    unicode: true,
  );

  /// ENVOI D'ARGENT
  /// Exemple: "Transfert de 5000F vers 077123456 effectue. TID: MP251208..."
  /// Exemple: "Envoi de 5000 FCFA a PAUL BIKA effectue. TID: MP251208..."
  static final RegExp _airtelTransfer = RegExp(
    r'(?:Transfert|Envoi)\s+de\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:vers|a)\s*(.+?)\s*(?:effectue|\.)',
    caseSensitive: false,
    unicode: true,
  );

  /// RETRAIT
  /// Exemple: "Retrait de 15000F effectue. Solde: 5000F. TID: RT251208..."
  static final RegExp _airtelWithdraw = RegExp(
    r'Retrait\s+de\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:effectue|\.)',
    caseSensitive: false,
    unicode: true,
  );

  /// DEPOT
  /// Exemple: "Depot de 25000F effectue. Nouveau solde: 30000F. TID: DP251208..."
  static final RegExp _airtelDeposit = RegExp(
    r'[Dd]epot\s+de\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:effectue|\.)',
    caseSensitive: false,
    unicode: true,
  );

  /// EXTRACTION TID (Transaction ID)
  static final RegExp _tidPattern = RegExp(
    r'TID[:\s]*([A-Z0-9]+)',
    caseSensitive: false,
  );

  // ==================== PATTERNS MOOV MONEY (VRAIS FORMATS) ====================

  /// TRANSFERT MOOV (avec ou sans nom)
  /// Exemple: "Transfert reussi de 10 000 F a 06010203 (MAMAN). Ref:TRF123"
  static final RegExp _moovTransfer = RegExp(
    r'Transfert\s+(?:reussi\s+)?de\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:a|vers)\s*(.+?)(?:\.|Ref|$)',
    caseSensitive: false,
    unicode: true,
  );

  /// PAIEMENT MOOV
  /// Exemple: "Paiement de 3500 F a SUPERMARCHE MBOLO effectue. Ref:PAY789"
  static final RegExp _moovPayment = RegExp(
    r'Paiement\s+de\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:a|vers)\s*(.+?)\s*(?:effectue|\.)',
    caseSensitive: false,
    unicode: true,
  );

  /// RECEPTION MOOV
  /// Exemple: "Vous avez recu 8000 F de 06987654. Ref:RCV123"
  static final RegExp _moovReceive = RegExp(
    r'(?:Vous\s+avez\s+)?[Rr]ecu\s*([\d\s]+)\s*(?:FCFA|F)\s*(?:de|du)\s*(.+?)(?:\.|Ref|$)',
    caseSensitive: false,
    unicode: true,
  );

  // ==================== PATTERNS UBA (UBAGAB) ====================

  /// DÉBIT UBA
  /// Exemple: "Carte 1234... Debit de 50000 FCFA. Ref: UBA123456"
  static final RegExp _ubaDebit = RegExp(
    r'[Dd]ebit\s+de\s*([\d\s,\.]+)\s*(?:FCFA|F)',
    caseSensitive: false,
    unicode: true,
  );

  /// CRÉDIT UBA
  /// Exemple: "Carte 1234... Credit de 150000 FCFA. Ref: UBA789012"
  static final RegExp _ubaCredit = RegExp(
    r'[Cc]redit\s+de\s*([\d\s,\.]+)\s*(?:FCFA|F)',
    caseSensitive: false,
    unicode: true,
  );

  /// TRANSACTION UBA GÉNÉRIQUE (avec montant)
  /// Capture tout SMS avec un montant et "FCFA"
  static final RegExp _ubaGeneric = RegExp(
    r'([\d\s,\.]+)\s*(?:FCFA|F|XAF)',
    caseSensitive: false,
    unicode: true,
  );

  // ==================== DÉTECTION OPÉRATEUR ====================

  /// Détecte l'opérateur à partir de l'expéditeur du SMS
  MobileOperator _detectOperator(String sender) {
    final normalizedSender = sender.toLowerCase().trim();

    if (_airtelSenders.any((s) => normalizedSender.contains(s))) {
      return MobileOperator.airtelMoney;
    }
    if (_moovSenders.any((s) => normalizedSender.contains(s))) {
      return MobileOperator.moovMoney;
    }
    if (_ubaSenders.any((s) => normalizedSender.contains(s))) {
      return MobileOperator.uba;
    }

    return MobileOperator.unknown;
  }

  // ==================== UTILITAIRES ====================

  /// Nettoie et parse un montant en double
  /// Gère: "7143", "10 000", "3000", "50,000.00"
  double? _parseAmount(String amountStr) {
    if (amountStr.isEmpty) return null;

    // Supprime tous les espaces et caractères non numériques sauf virgule et point
    String cleaned = amountStr
        .replaceAll(RegExp(r'[\s\u00A0\u202F]+'), '') // Tous types d'espaces
        .replaceAll('FCFA', '')
        .replaceAll('F', '')
        .replaceAll('XAF', '')
        .trim();

    // Gère le format européen (10.000,50 → 10000.50)
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Format: 10.000,50
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains(',')) {
      // Vérifie si la virgule est un séparateur décimal ou de milliers
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Format décimal: 1000,50
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Format milliers: 10,000
        cleaned = cleaned.replaceAll(',', '');
      }
    }

    return double.tryParse(cleaned);
  }

  /// Nettoie le nom du marchand/destinataire
  String _cleanMerchantName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.\s]+$'), '')
        .replaceAll(RegExp(r'^\s*[Aa]\s+'), '') // Enlève "a " au début
        .trim();
  }

  /// Extrait le TID (Transaction ID) du SMS
  String _extractTid(String body) {
    final match = _tidPattern.firstMatch(body);
    return match?.group(1) ?? '';
  }

  // ==================== MÉTHODE PRINCIPALE ====================

  /// Parse un SMS et extrait les informations de transaction
  ///
  /// Retourne `null` si le SMS ne correspond à aucun pattern connu.
  ParsedTransaction? parseSms(
    String sender,
    String body, {
    DateTime? receivedAt,
  }) {
    final operator = _detectOperator(sender);
    final date = receivedAt ?? DateTime.now();

    ParsedTransaction? result;

    switch (operator) {
      case MobileOperator.airtelMoney:
        result = _parseAirtelSms(body, sender, date);
        break;
      case MobileOperator.moovMoney:
        result = _parseMoovSms(body, sender, date);
        break;
      case MobileOperator.uba:
        result = _parseUbaSms(body, sender, date);
        break;
      case MobileOperator.unknown:
        // Essaie tous les parsers si opérateur inconnu
        result =
            _parseAirtelSms(body, sender, date) ??
            _parseMoovSms(body, sender, date) ??
            _parseUbaSms(body, sender, date);
        break;
    }

    return result;
  }

  /// Parse les SMS Airtel Money (vrais formats gabonais)
  ParsedTransaction? _parseAirtelSms(
    String body,
    String sender,
    DateTime date,
  ) {
    final tid = _extractTid(body);
    RegExpMatch? match;

    // 1. PAIEMENT EBILLING
    match = _airtelPaymentEbilling.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Paiement'),
          transactionId: tid,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 2. PAIEMENT MARCHAND
    match = _airtelPaymentMerchant.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Paiement'),
          transactionId: tid,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 3. RÉCEPTION (Format Court)
    match = _airtelReceiveShort.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Reçu'),
          transactionId: tid,
          date: date,
          type: TransactionType.income,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 4. RÉCEPTION (Format Long)
    match = _airtelReceiveLong.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Reçu'),
          transactionId: tid,
          date: date,
          type: TransactionType.income,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 5. TRANSFERT / ENVOI
    match = _airtelTransfer.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Transfert'),
          transactionId: tid,
          date: date,
          type: TransactionType.transfer,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 6. RETRAIT
    match = _airtelWithdraw.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'Retrait Airtel Money',
          transactionId: tid,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 7. DÉPOT
    match = _airtelDeposit.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'Dépôt Airtel Money',
          transactionId: tid,
          date: date,
          type: TransactionType.income,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    return null;
  }

  /// Parse les SMS Moov Money
  ParsedTransaction? _parseMoovSms(String body, String sender, DateTime date) {
    RegExpMatch? match;

    // Extrait la référence
    final refMatch = RegExp(
      r'Ref[:\s]*(\w+)',
      caseSensitive: false,
    ).firstMatch(body);
    final ref = refMatch?.group(1) ?? '';

    // 1. TRANSFERT
    match = _moovTransfer.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        String merchant = match.group(2) ?? 'Transfert';
        // Extrait le nom entre parenthèses si présent
        final nameMatch = RegExp(r'\(([^)]+)\)').firstMatch(merchant);
        if (nameMatch != null) {
          merchant = nameMatch.group(1) ?? merchant;
        }
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(merchant),
          transactionId: ref,
          date: date,
          type: TransactionType.transfer,
          operator: MobileOperator.moovMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 2. PAIEMENT
    match = _moovPayment.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Paiement'),
          transactionId: ref,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.moovMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 3. RÉCEPTION
    match = _moovReceive.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Reçu'),
          transactionId: ref,
          date: date,
          type: TransactionType.income,
          operator: MobileOperator.moovMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    return null;
  }

  /// Parse les SMS UBA (UBAGAB)
  ParsedTransaction? _parseUbaSms(String body, String sender, DateTime date) {
    // Extrait la référence UBA
    final refMatch = RegExp(
      r'Ref[:\s]*(\w+)',
      caseSensitive: false,
    ).firstMatch(body);
    final ref =
        refMatch?.group(1) ?? 'UBA${DateTime.now().millisecondsSinceEpoch}';

    RegExpMatch? match;

    // 1. DÉBIT
    match = _ubaDebit.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'Débit UBA',
          transactionId: ref,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.uba,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 2. CRÉDIT
    match = _ubaCredit.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'Crédit UBA',
          transactionId: ref,
          date: date,
          type: TransactionType.income,
          operator: MobileOperator.uba,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 3. GÉNÉRIQUE - Détection basée sur mots-clés
    final bodyLower = body.toLowerCase();
    if (bodyLower.contains('debit') ||
        bodyLower.contains('retrait') ||
        bodyLower.contains('achat')) {
      match = _ubaGeneric.firstMatch(body);
      if (match != null) {
        final amount = _parseAmount(match.group(1) ?? '');
        if (amount != null && amount > 0) {
          return ParsedTransaction(
            amount: amount,
            merchantName: 'Transaction UBA',
            transactionId: ref,
            date: date,
            type: TransactionType.expense,
            operator: MobileOperator.uba,
            rawSmsContent: body,
            smsSender: sender,
          );
        }
      }
    } else if (bodyLower.contains('credit') ||
        bodyLower.contains('depot') ||
        bodyLower.contains('virement')) {
      match = _ubaGeneric.firstMatch(body);
      if (match != null) {
        final amount = _parseAmount(match.group(1) ?? '');
        if (amount != null && amount > 0) {
          return ParsedTransaction(
            amount: amount,
            merchantName: 'Crédit UBA',
            transactionId: ref,
            date: date,
            type: TransactionType.income,
            operator: MobileOperator.uba,
            rawSmsContent: body,
            smsSender: sender,
          );
        }
      }
    }

    return null;
  }

  /// Vérifie si un SMS ressemble à une notification financière
  bool isFinancialSms(String sender, String body) {
    // Vérifie d'abord l'expéditeur
    final operator = _detectOperator(sender);
    if (operator != MobileOperator.unknown) return true;

    // Sinon vérifie les mots-clés
    final lowerBody = body.toLowerCase();
    final keywords = [
      'fcfa',
      'paiement',
      'transfert',
      'recu',
      'envoi',
      'depot',
      'retrait',
      'solde',
      'debit',
      'credit',
      'tid:',
      'ref:',
      'montant',
      'effectue',
    ];

    return keywords.any((kw) => lowerBody.contains(kw));
  }
}
