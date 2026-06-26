import 'package:flutter/material.dart';

/// Configuration d'un opérateur financier gabonais
///
/// Contient les métadonnées et les patterns regex pour détecter
/// et parser les notifications/SMS de chaque opérateur.
class OperatorConfig {
  final String key;
  final String label;
  final Color color;
  final String accountType; // 'mobile_money', 'bank', 'microfinance'
  final List<RegExp> senderPatterns;
  final List<TransactionPattern> transactionPatterns;

  const OperatorConfig({
    required this.key,
    required this.label,
    required this.color,
    required this.accountType,
    required this.senderPatterns,
    required this.transactionPatterns,
  });

  /// Détecte si un message provient de cet opérateur
  bool detect(String sender, String body) {
    final fullText = '$sender $body';
    return senderPatterns.any((p) => p.hasMatch(fullText));
  }
}

/// Pattern regex pour un type de transaction spécifique
class TransactionPattern {
  final String type; // 'income' ou 'expense'
  final String label; // ex: 'Réception', 'Envoi', 'Retrait'
  final RegExp regex;
  final TransactionExtractor extract;
  final String suggestedCategory;

  const TransactionPattern({
    required this.type,
    required this.label,
    required this.regex,
    required this.extract,
    required this.suggestedCategory,
  });
}

/// Résultat d'extraction d'un pattern
class ExtractedData {
  final int amount;
  final String description;

  const ExtractedData({
    required this.amount,
    required this.description,
  });
}

/// Fonction d'extraction à partir d'un match regex
typedef TransactionExtractor = ExtractedData Function(RegExpMatch match);

/// Parse un montant FCFA depuis une chaîne
///
/// Gère les formats: "1 500 000", "1.500.000", "1,500,000", "1500000"
int parseAmount(String str) {
  if (str.isEmpty) return 0;
  final clean = str
      .trim()
      .replaceAll(RegExp(r'\s'), '')
      .replaceAllMapped(RegExp(r'[.,](\d{3})'), (m) => m[1]!)
      .replaceAll(',', '.');
  final num = double.tryParse(clean);
  return num == null ? 0 : num.round();
}

// ─────────────────────────────────────────────
// REGISTRE DES OPÉRATEURS GABONAIS
// ─────────────────────────────────────────────

/// Liste de tous les opérateurs financiers supportés au Gabon
final List<OperatorConfig> gabonOperators = [
  _airtelMoney,
  _moovMoney,
  _ubaGabon,
  _ecobankGabon,
  _bambouEmf,
];

// ─── AIRTEL MONEY ───────────────────────────

final _airtelMoney = OperatorConfig(
  key: 'AIRTEL_MONEY',
  label: 'Airtel Money',
  color: const Color(0xFFE3001B),
  accountType: 'mobile_money',
  senderPatterns: [
    RegExp(r'airtel', caseSensitive: false),
    RegExp(r'airtelga', caseSensitive: false),
  ],
  transactionPatterns: [
    // Réception d'argent (Standard)
    TransactionPattern(
      type: 'income',
      label: 'Réception',
      regex: RegExp(
        r'vous avez re[çc]u\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:de|du)\s+(.+?)(?:\s+le\s+|\s*Nouveau|\s*\.\s*|Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Reçu de ${m.group(2)?.trim() ?? "inconnu"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Réception d'argent (Alternative / courte)
    TransactionPattern(
      type: 'income',
      label: 'Réception',
      regex: RegExp(
        r'(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+re[çc]u\s+(?:du|de)\s+(.+?)(?:\.|\s+Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Reçu de ${m.group(2)?.trim() ?? "inconnu"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Envoi d'argent
    TransactionPattern(
      type: 'expense',
      label: 'Envoi',
      regex: RegExp(
        r'vous avez envoy[eé]\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:[àa]|au)\s+(.+?)(?:\s+le\s+|\s*frais|\s*\.\s*|Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Envoi à ${m.group(2)?.trim() ?? "inconnu"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Paiement marchand classique
    TransactionPattern(
      type: 'expense',
      label: 'Paiement',
      regex: RegExp(
        r'paiement\s+de\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(.+?)\s+pour\s+ref\s+(.+?)(?:\s+(?:a\s+ete|effectue)|le\s+|\s*\.\s*|Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Paiement ${m.group(2)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-autres',
    ),
    // Paiement marchand alternatif ("Vous avez PAYE")
    TransactionPattern(
      type: 'expense',
      label: 'Paiement',
      regex: RegExp(
        r'vous\s+avez\s+pay[eé]\s+(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:[àa]|au)\s+(.+?)(?:\s+en\s+reference|\s+le\s+|\s*\.\s*|Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Paiement ${m.group(2)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-autres',
    ),
    // Retrait (agent / DAB)
    TransactionPattern(
      type: 'expense',
      label: 'Retrait',
      regex: RegExp(
        r'retrait\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)(?:\s+reussi)?(?:\s+vers\s+(.+?))?(?:\.|\s+Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: m.group(2) != null ? 'Retrait vers ${m.group(2)!.trim()}' : 'Retrait Airtel Money',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Dépôt (recharge / agent)
    TransactionPattern(
      type: 'income',
      label: 'Dépôt',
      regex: RegExp(
        r'd[eé]p[oô]t\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Dépôt Airtel Money',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Achat crédit téléphonique
    TransactionPattern(
      type: 'expense',
      label: 'Crédit tél.',
      regex: RegExp(
        r'achat\s+(?:de\s+)?cr[eé]dit\s+(?:de\s+communication\s+)?(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Achat crédit téléphonique',
      ),
      suggestedCategory: 'cat-factures',
    ),
  ],
);

// ─── MOOV MONEY ─────────────────────────────

final _moovMoney = OperatorConfig(
  key: 'MOOV_MONEY',
  label: 'Moov Money',
  color: const Color(0xFFFF6B00),
  accountType: 'mobile_money',
  senderPatterns: [
    RegExp(r'moov', caseSensitive: false),
    RegExp(r'moovga', caseSensitive: false),
    RegExp(r'flooz', caseSensitive: false),
  ],
  transactionPatterns: [
    // Crédit (réception)
    TransactionPattern(
      type: 'income',
      label: 'Réception',
      regex: RegExp(
        r'cr[eé]dit\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:re[çc]u\s+)?(?:de|par)\s+(.+?)(?:\.|\s+Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Reçu de ${m.group(2)?.trim() ?? "Moov Money"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Débit (envoi / paiement)
    TransactionPattern(
      type: 'expense',
      label: 'Envoi',
      regex: RegExp(
        r'd[eé]bit\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+(?:effectu[eé]\s+)?(?:pour|vers|[àa])\s+(.+?)(?:\.|\s+Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Débit vers ${m.group(2)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Transfert explicite
    TransactionPattern(
      type: 'expense',
      label: 'Transfert',
      regex: RegExp(
        r'transfert\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)\s+vers\s+(.+?)(?:\.|\s+Solde|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Transfert vers ${m.group(2)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Retrait
    TransactionPattern(
      type: 'expense',
      label: 'Retrait',
      regex: RegExp(
        r'retrait\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Retrait Moov Money',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Paiement facture (eau, électricité, etc.)
    TransactionPattern(
      type: 'expense',
      label: 'Facture',
      regex: RegExp(
        r'paiement\s+(?:facture|abonnement)\s+(.+?)\s+(?:de\s+)?(\d[\d\s]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(2)!),
        description: 'Facture ${m.group(1)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-factures',
    ),
  ],
);

// ─── UBA GABON ──────────────────────────────

final _ubaGabon = OperatorConfig(
  key: 'UBA_GABON',
  label: 'UBA',
  color: const Color(0xFFC1001F),
  accountType: 'bank',
  senderPatterns: [
    RegExp(r'\bUBA\b', caseSensitive: false),
    RegExp(r'ubagroup', caseSensitive: false),
    RegExp(r'uba\s*gabon', caseSensitive: false),
    RegExp(r'uba\s*alert', caseSensitive: false),
  ],
  transactionPatterns: [
    // Crédit / virement entrant
    TransactionPattern(
      type: 'income',
      label: 'Crédit',
      regex: RegExp(
        r'cr[eé]dit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:par|de|depuis)\s+(.+?)(?:\.|\s*Solde|\s*Ref|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Crédit ${m.group(2)?.trim() ?? "UBA"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Débit / virement sortant
    TransactionPattern(
      type: 'expense',
      label: 'Débit',
      regex: RegExp(
        r'd[eé]bit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:pour|vers|[àa])\s+(.+?)(?:\.|\s*Solde|\s*Ref|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Débit ${m.group(2)?.trim() ?? "UBA"}',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Retrait DAB
    TransactionPattern(
      type: 'expense',
      label: 'DAB',
      regex: RegExp(
        r'retrait\s+(?:dab|guichet|atm)?\s*(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Retrait DAB UBA',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Paiement TPE / carte
    TransactionPattern(
      type: 'expense',
      label: 'Paiement carte',
      regex: RegExp(
        r'(?:paiement|achat)\s+(?:carte|tpe)\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F)\s+(?:chez\s+)?(.+?)(?:\.|\s*Ref|$)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Paiement carte ${m.group(2)?.trim() ?? ""}',
      ),
      suggestedCategory: 'cat-autres',
    ),
  ],
);

// ─── ECOBANK GABON ──────────────────────────

final _ecobankGabon = OperatorConfig(
  key: 'ECOBANK_GABON',
  label: 'Ecobank',
  color: const Color(0xFF00509F),
  accountType: 'bank',
  senderPatterns: [
    RegExp(r'ecobank', caseSensitive: false),
    RegExp(r'eco-bank', caseSensitive: false),
  ],
  transactionPatterns: [
    // Crédit (FR + EN)
    TransactionPattern(
      type: 'income',
      label: 'Crédit',
      regex: RegExp(
        r'(?:credit|cr[eé]dit|received|re[çc]u)\s+(?:of\s+|de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F|XOF)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Crédit Ecobank',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Débit (FR + EN)
    TransactionPattern(
      type: 'expense',
      label: 'Débit',
      regex: RegExp(
        r'(?:debit|d[eé]bit|payment|sent|envoy[eé])\s+(?:of\s+|de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA|F|XOF)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Débit Ecobank',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Xpress Cash
    TransactionPattern(
      type: 'expense',
      label: 'Xpress Cash',
      regex: RegExp(
        r'ecobank\s+xpress\s+(?:cash\s+)?(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|CFA)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Ecobank Xpress Cash',
      ),
      suggestedCategory: 'cat-transferts',
    ),
  ],
);

// ─── BAMBOU EMF ─────────────────────────────

final _bambouEmf = OperatorConfig(
  key: 'BAMBOU_EMF',
  label: 'Bambou EMF',
  color: const Color(0xFF2E7D32),
  accountType: 'microfinance',
  senderPatterns: [
    RegExp(r'bambou', caseSensitive: false),
    RegExp(r'bambou\s*emf', caseSensitive: false),
  ],
  transactionPatterns: [
    // Crédit
    TransactionPattern(
      type: 'income',
      label: 'Crédit',
      regex: RegExp(
        r'cr[eé]dit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Crédit Bambou EMF',
      ),
      suggestedCategory: 'cat-transferts',
    ),
    // Débit
    TransactionPattern(
      type: 'expense',
      label: 'Débit',
      regex: RegExp(
        r'd[eé]bit[ée]?\s+(?:de\s+)?(\d[\d\s.,]*)\s*(?:FCFA|XAF|F)',
        caseSensitive: false,
      ),
      extract: (m) => ExtractedData(
        amount: parseAmount(m.group(1)!),
        description: 'Débit Bambou EMF',
      ),
      suggestedCategory: 'cat-transferts',
    ),
  ],
);
