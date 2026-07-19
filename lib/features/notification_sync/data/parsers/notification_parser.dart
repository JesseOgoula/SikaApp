import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:sika_app/features/notification_sync/data/parsers/operator_config.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// Parseur de notifications et SMS financiers gabonais
///
/// Détecte et extrait automatiquement les transactions à partir
/// du contenu textuel des notifications push et SMS des opérateurs
/// Airtel Money, Moov Money, UBA, Ecobank et Bamboo.
class NotificationParser {
  /// Pattern pour extraire le TID (Transaction ID)
  static final RegExp _tidPattern = RegExp(
    r'(?:TID|Trans\s*ID)\s*:?\s*([A-Z0-9.]+)',
    caseSensitive: false,
  );

  /// Patterns pour détecter le solde dans un message
  static final List<RegExp> _balancePatterns = [
    RegExp(
      r'(?:nouveau\s+)?solde\s*(?:disponible)?\s*:?\s*(\d[\d\s.,]*\d)\s*(?:FCFA|XAF|F\b)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:balance|disponible)\s*:?\s*(\d[\d\s.,]*\d)\s*(?:FCFA|XAF|F\b)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:reste|restant)\s*:?\s*(\d[\d\s.,]*\d)\s*(?:FCFA|XAF|F\b)',
      caseSensitive: false,
    ),
  ];

  /// Parse un message (notification ou SMS) et retourne une transaction
  /// pré-remplie, ou `null` si le message n'est pas reconnu comme financier.
  ///
  /// [sender] : Expéditeur (packageName pour notifications, numéro pour SMS)
  /// [title] : Titre de la notification (peut être vide pour les SMS)
  /// [body] : Corps du message
  /// [receivedAt] : Date/heure de réception (ISO string)
  /// [source] : Source du message (notification push ou SMS)
  static ParsedTransaction? parseMessage({
    required String sender,
    String title = '',
    required String body,
    String? receivedAt,
    ParsedSource source = ParsedSource.notificationPush,
  }) {
    final now = DateTime.now().toIso8601String();
    final fullText = '$sender $title $body';

    for (final operator in gabonOperators) {
      // 1. Identifier l'opérateur
      if (!operator.detect(sender, fullText)) continue;

      // 2. Essayer chaque pattern de transaction
      for (final pattern in operator.transactionPatterns) {
        final match = pattern.regex.firstMatch(body);
        if (match == null) continue;

        final extracted = pattern.extract(match);
        if (extracted.amount <= 0) continue;

        // 3. Détecter le solde dans le même message
        final detectedBalance = _extractBalance(body);

        // 4. Détecter le TID (Transaction ID / externalId)
        final externalId = _extractTid(body);

        // 5. Générer un ID déterministe pour la déduplication
        final idSource =
            '${operator.key}-${extracted.amount}-${pattern.type}-${receivedAt ?? now}';
        final id = sha256.convert(utf8.encode(idSource)).toString().substring(0, 16);

        return ParsedTransaction(
          id: id,
          source: source,
          operatorKey: operator.key,
          operatorLabel: operator.label,
          operatorColor: operator.color,
          accountType: operator.accountType,
          patternLabel: pattern.label,
          type: pattern.type,
          amount: extracted.amount,
          description: extracted.description,
          suggestedCategory: pattern.suggestedCategory,
          date: (receivedAt ?? now).split('T')[0],
          detectedBalance: detectedBalance,
          rawMessage: body,
          parsedAt: now,
          receivedAt: receivedAt ?? now,
          externalId: externalId,
        );
      }
    }

    return null; // Message non reconnu comme financier
  }

  /// Extrait le TID d'un message textuel
  static String? _extractTid(String body) {
    final match = _tidPattern.firstMatch(body);
    final rawTid = match?.group(1)?.trim();
    if (rawTid != null && rawTid.endsWith('.')) {
      return rawTid.substring(0, rawTid.length - 1);
    }
    return rawTid;
  }

  /// Extrait le solde d'un message textuel
  static int? _extractBalance(String body) {
    for (final pattern in _balancePatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return parseAmount(match.group(1)!);
      }
    }
    return null;
  }

  /// Vérifie si un expéditeur correspond à un opérateur connu
  ///
  /// Utile pour filtrer rapidement les SMS/notifications sans parser
  /// le contenu complet.
  static bool isKnownFinancialSender(String sender) {
    return gabonOperators.any(
      (op) => op.senderPatterns.any((p) => p.hasMatch(sender)),
    );
  }

  /// Retourne la configuration d'un opérateur par sa clé
  static OperatorConfig? getOperatorByKey(String key) {
    try {
      return gabonOperators.firstWhere((op) => op.key == key);
    } catch (_) {
      return null;
    }
  }
}
