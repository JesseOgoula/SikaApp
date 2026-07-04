import 'package:flutter/material.dart';

/// Statut de validation d'une transaction détectée
enum ParsedTransactionStatus {
  pendingReview,
  confirmed,
  rejected,
}

/// Niveau de confiance de la détection
enum ParseConfidence {
  high,
  medium,
  low,
}

/// Source de la transaction détectée
enum ParsedSource {
  notificationPush,
  sms,
}

/// Transaction extraite d'une notification ou d'un SMS
///
/// Ce modèle représente une transaction **avant** validation utilisateur.
/// Une fois confirmée, elle est convertie en `TransactionsTableCompanion`
/// et insérée dans la base de données Drift.
class ParsedTransaction {
  final String id;
  final ParsedSource source;
  final String operatorKey;
  final String operatorLabel;
  final Color operatorColor;
  final String accountType; // 'mobile_money', 'bank', 'microfinance'
  final String patternLabel; // ex: 'Réception', 'Envoi', 'Retrait'

  // Données financières
  final String type; // 'income' ou 'expense'
  final int amount; // FCFA, toujours positif
  final String description;
  final String suggestedCategory;
  final String date; // ISO date (YYYY-MM-DD)
  final String? externalId; // ID externe de transaction (TID)

  // Solde détecté (optionnel)
  final int? detectedBalance;

  // Audit
  final String rawMessage;
  final String parsedAt;
  final String receivedAt;

  // Workflow
  final ParsedTransactionStatus status;
  final ParseConfidence confidence;

  const ParsedTransaction({
    required this.id,
    required this.source,
    required this.operatorKey,
    required this.operatorLabel,
    required this.operatorColor,
    required this.accountType,
    required this.patternLabel,
    required this.type,
    required this.amount,
    required this.description,
    required this.suggestedCategory,
    required this.date,
    this.externalId,
    this.detectedBalance,
    required this.rawMessage,
    required this.parsedAt,
    required this.receivedAt,
    this.status = ParsedTransactionStatus.pendingReview,
    this.confidence = ParseConfidence.high,
  });

  /// Crée une copie avec des champs modifiés
  ParsedTransaction copyWith({
    String? id,
    ParsedSource? source,
    String? operatorKey,
    String? operatorLabel,
    Color? operatorColor,
    String? accountType,
    String? patternLabel,
    String? type,
    int? amount,
    String? description,
    String? suggestedCategory,
    String? date,
    String? externalId,
    int? detectedBalance,
    String? rawMessage,
    String? parsedAt,
    String? receivedAt,
    ParsedTransactionStatus? status,
    ParseConfidence? confidence,
  }) {
    return ParsedTransaction(
      id: id ?? this.id,
      source: source ?? this.source,
      operatorKey: operatorKey ?? this.operatorKey,
      operatorLabel: operatorLabel ?? this.operatorLabel,
      operatorColor: operatorColor ?? this.operatorColor,
      accountType: accountType ?? this.accountType,
      patternLabel: patternLabel ?? this.patternLabel,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      date: date ?? this.date,
      externalId: externalId ?? this.externalId,
      detectedBalance: detectedBalance ?? this.detectedBalance,
      rawMessage: rawMessage ?? this.rawMessage,
      parsedAt: parsedAt ?? this.parsedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
    );
  }

  /// Sérialise en Map pour stockage JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source.name,
      'operatorKey': operatorKey,
      'operatorLabel': operatorLabel,
      'operatorColor': operatorColor.value,
      'accountType': accountType,
      'patternLabel': patternLabel,
      'type': type,
      'amount': amount,
      'description': description,
      'suggestedCategory': suggestedCategory,
      'date': date,
      'externalId': externalId,
      'detectedBalance': detectedBalance,
      'rawMessage': rawMessage,
      'parsedAt': parsedAt,
      'receivedAt': receivedAt,
      'status': status.name,
      'confidence': confidence.name,
    };
  }

  /// Désérialise depuis un Map JSON
  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      id: json['id'] as String,
      source: ParsedSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ParsedSource.notificationPush,
      ),
      operatorKey: json['operatorKey'] as String,
      operatorLabel: json['operatorLabel'] as String,
      operatorColor: Color(json['operatorColor'] as int),
      accountType: json['accountType'] as String,
      patternLabel: json['patternLabel'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      suggestedCategory: json['suggestedCategory'] as String,
      date: json['date'] as String,
      externalId: json['externalId'] as String?,
      detectedBalance: json['detectedBalance'] as int?,
      rawMessage: json['rawMessage'] as String,
      parsedAt: json['parsedAt'] as String,
      receivedAt: json['receivedAt'] as String,
      status: ParsedTransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ParsedTransactionStatus.pendingReview,
      ),
      confidence: ParseConfidence.values.firstWhere(
        (e) => e.name == json['confidence'],
        orElse: () => ParseConfidence.high,
      ),
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isTransfer => type == 'transfer';
}
