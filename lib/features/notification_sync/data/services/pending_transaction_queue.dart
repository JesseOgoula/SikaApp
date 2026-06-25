import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// File d'attente sécurisée pour les transactions détectées en attente de validation
///
/// Stocke les transactions dans le stockage sécurisé du téléphone (Keystore Android).
/// Fournit des mécanismes de déduplication et un stream pour l'UI réactive.
class PendingTransactionQueue {
  static final PendingTransactionQueue _instance =
      PendingTransactionQueue._internal();

  factory PendingTransactionQueue() => _instance;

  PendingTransactionQueue._internal();

  static const String _storageKey = 'sika_pending_transactions';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Référence vers la base de données locale pour la déduplication
  AppDatabase? database;

  /// StreamController pour notifier l'UI des changements
  final _controller = StreamController<List<ParsedTransaction>>.broadcast();

  /// Stream réactif de la liste des transactions en attente
  Stream<List<ParsedTransaction>> get stream => _controller.stream;

  /// Récupère toutes les transactions en attente
  Future<List<ParsedTransaction>> getAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(raw);
      return jsonList
          .map((e) => ParsedTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ajoute une transaction détectée à la file d'attente
  ///
  /// Retourne la transaction ajoutée, ou `null` si c'est un doublon.
  /// Déduplication : même opérateur + même montant + même type + intervalle < 60s
  Future<ParsedTransaction?> push(ParsedTransaction tx) async {
    // 1. Vérification en base de données si un TID (externalId) est présent
    if (tx.externalId != null && database != null) {
      final exists = await database!.transactionExists(tx.externalId!);
      if (exists) {
        return null;
      }
    }

    final queue = await getAll();

    // 2. Vérification de doublon dans la file d'attente temporaire
    final isDuplicate = queue.any((existing) =>
        existing.operatorKey == tx.operatorKey &&
        existing.amount == tx.amount &&
        existing.type == tx.type &&
        _isWithinSeconds(existing.parsedAt, tx.parsedAt, 60));

    if (isDuplicate) return null;

    final updatedQueue = [...queue, tx];
    await _save(updatedQueue);
    _controller.add(updatedQueue);
    return tx;
  }

  /// Confirme une transaction (la retire de la file)
  ///
  /// Retourne la transaction confirmée pour pouvoir l'enregistrer
  /// dans la base de données principale.
  Future<ParsedTransaction?> confirm(String txId) async {
    final queue = await getAll();
    final tx = queue.where((t) => t.id == txId).firstOrNull;

    if (tx == null) return null;

    final updatedQueue = queue.where((t) => t.id != txId).toList();
    await _save(updatedQueue);
    _controller.add(updatedQueue);

    return tx.copyWith(status: ParsedTransactionStatus.confirmed);
  }

  /// Rejette une transaction (la retire de la file)
  Future<void> reject(String txId) async {
    final queue = await getAll();
    final updatedQueue = queue.where((t) => t.id != txId).toList();
    await _save(updatedQueue);
    _controller.add(updatedQueue);
  }

  /// Supprime toutes les transactions en attente
  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
    _controller.add([]);
  }

  /// Nombre de transactions en attente
  Future<int> get count async => (await getAll()).length;

  /// Sauvegarde la file d'attente
  Future<void> _save(List<ParsedTransaction> queue) async {
    final jsonList = queue.map((tx) => tx.toJson()).toList();
    await _storage.write(key: _storageKey, value: jsonEncode(jsonList));
  }

  /// Vérifie si deux timestamps sont dans un intervalle de N secondes
  bool _isWithinSeconds(String timestamp1, String timestamp2, int seconds) {
    try {
      final t1 = DateTime.parse(timestamp1);
      final t2 = DateTime.parse(timestamp2);
      return (t1.difference(t2).inSeconds).abs() < seconds;
    } catch (_) {
      return false;
    }
  }

  /// Libère les ressources
  void dispose() {
    _controller.close();
  }
}
