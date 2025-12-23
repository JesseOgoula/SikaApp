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
    'Airtel',
    'AirtelMoney',
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
    'UBAGAB',
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
    r'(?:XAF|FCFA|F)\s*([\d\s,\.]+)|([\d\s,\.]+)\s*(?:FCFA|F|XAF)',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT MOOV RÉCEPTION
  /// Exemple: "Ref:CHM35PYK6N. Vous avez recu un montant de 1500,00 FCFA du compte R1010304..."
  static final RegExp _moovReceiveNew = RegExp(
    r'Vous\s+avez\s+recu\s+un\s+montant\s+de\s*([\d\s,\.]+)\s*FCFA\s+du\s+compte\s+(.+?)\s+le',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT MOOV ACHAT EDAN
  /// Exemple: "Votre achat de code EDAN pour le compteur No... Montant Total: 65000,00 FCFA;"
  static final RegExp _moovEdan = RegExp(
    r'Votre\s+achat\s+de\s+code\s+EDAN.*?Montant\s+Total:\s*([\d\s,\.]+)\s*FCFA',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT AIRTEL PAIEMENT SEEG
  /// Exemple: "Vous avez PAYE 5000 FCFA a SEEG... Montant: total : 5000 F CFA"
  static final RegExp _airtelSeeg = RegExp(
    r'Vous\s+avez\s+PAYE\s+([\d\s,\.]+)\s*FCFA\s+a\s+SEEG',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT AIRTEL RÉCEPTION AVEC NOM DÉTAILLÉ
  /// Exemple: "Vous avez recu 5150F du 077380120,FLORENCE NTEMANE EPSE NZE ENDENG."
  static final RegExp _airtelReceiveNameDetail = RegExp(
    r'Vous\s+avez\s+recu\s*([\d\s,\.]+)\s*F\s+du\s+[\d]+,(.+?)(?:\.|\s+Nouveau)',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT AIRTEL TRANSFERT AVEC NOM DÉTAILLÉ
  /// Exemple: "Vous avez envoye 1030F au 077815981 SIMON P MENGWA.Frais 50F."
  static final RegExp _airtelSendNameDetail = RegExp(
    r'Vous\s+avez\s+envoye\s*([\d\s,\.]+)\s*F\s+au\s+[\d\s]+(.+?)(?:\.|\s+Frais)',
    caseSensitive: false,
    unicode: true,
  );

  /// NOUVEAU FORMAT AIRTEL RETRAIT
  /// Exemple: "RETRAIT de 10000 FCFA reussi vers A81344."
  static final RegExp _airtelWithdrawNew = RegExp(
    r'RETRAIT\s+de\s*([\d\s,\.]+)\s*FCFA\s+reussi\s+vers\s+(.+?)(?:\.|\s+Solde)',
    caseSensitive: false,
    unicode: true,
  );

  /// FORMAT UBA TXN CREDIT/DEBIT
  /// Exemple: "Txn: CREDIT Montant: XAF701,874.00 Compte: 8XX..64X Desc: ORGANISATION..."
  static final RegExp _ubaTxn = RegExp(
    r'Txn:\s*(CREDIT|DEBIT).*?Montant:\s*(?:XAF|FCFA|F)\s*([\d\s,\.]+).*?Desc:\s*(.+?)\s*Date:',
    caseSensitive: false,
    dotAll: true,
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

    // Nettoyage agressif des caractères non numériques sauf virgule et point
    // On garde les chiffres et les séparateurs potentiels
    String cleaned = amountStr.trim();
    
    // Si on a XAF701,874.00, on veut extraire juste le chiffre
    final numericMatch = RegExp(r'[\d\s,.]+').firstMatch(cleaned);
    if (numericMatch == null) return null;
    cleaned = numericMatch.group(0)!;

    // Supprime tous les espaces (y compris espaces insécables Moov/Airtel)
    cleaned = cleaned.replaceAll(RegExp(r'[\s\u00A0\u202F]+'), '');

    // Logique de conversion selon le format détecté
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Format mixte (ex: 1.234,56 ou 1,234.56)
      // Si le point est après la virgule, virgule=milliers, point=décimal
      if (cleaned.indexOf('.') > cleaned.indexOf(',')) {
        cleaned = cleaned.replaceAll(',', '');
      } else {
        // Sinon l'inverse
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleaned.contains(',')) {
      // Cas de 1500,00 ou 701,874
      // Si la virgule est suivie de exactement 2 chiffres à la FIN, c'est probablement un décimal
      final parts = cleaned.split(',');
      if (parts.length == 2 && (parts[1].length == 2 || parts[1].length == 1)) {
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Sinon c'est un séparateur de milliers
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      // Cas de 701.874 (milliers) ou 1500.00 (décimal)
      final parts = cleaned.split('.');
      // Si plus d'un point, ou si le dernier segment n'est pas de longueur 2
      if (parts.length > 2 || (parts.length == 2 && parts[1].length > 2)) {
        cleaned = cleaned.replaceAll('.', '');
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

    // 1. PAIEMENT SEEG DÉTAILLÉ (NOUVEAU)
    match = _airtelSeeg.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'SEEG (EDAN/EAU)',
          transactionId: tid,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 2. RÉCEPTION AVEC NOM (NOUVEAU)
    match = _airtelReceiveNameDetail.firstMatch(body);
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

    // 3. TRANSFERT / ENVOI AVEC NOM (NOUVEAU)
    match = _airtelSendNameDetail.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(2) ?? 'Envoi'),
          transactionId: tid,
          date: date,
          type: TransactionType.transfer,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 4. RETRAIT (NOUVEAU FORMAT)
    match = _airtelWithdrawNew.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'Retrait Airtel Money',
          transactionId: _cleanMerchantName(match.group(2) ?? ''),
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.airtelMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 5. PAIEMENT EBILLING
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

    // 1. RÉCEPTION NOUVEAU FORMAT (NOUVEAU)
    match = _moovReceiveNew.firstMatch(body);
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

    // 2. ACHAT EDAN (NOUVEAU)
    match = _moovEdan.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: 'EDAN (Moov)',
          transactionId: ref,
          date: date,
          type: TransactionType.expense,
          operator: MobileOperator.moovMoney,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 3. TRANSFERT
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

    // 1. FORMAT TXN DÉTAILLÉ (NOUVEAU)
    match = _ubaTxn.firstMatch(body);
    if (match != null) {
      final typeStr = match.group(1)?.toUpperCase();
      final amount = _parseAmount(match.group(2) ?? '');
      if (amount != null && amount > 0) {
        return ParsedTransaction(
          amount: amount,
          merchantName: _cleanMerchantName(match.group(3) ?? 'Transaction UBA'),
          transactionId: ref,
          date: date,
          type: typeStr == 'CREDIT'
              ? TransactionType.income
              : TransactionType.expense,
          operator: MobileOperator.uba,
          rawSmsContent: body,
          smsSender: sender,
        );
      }
    }

    // 2. DÉBIT
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
