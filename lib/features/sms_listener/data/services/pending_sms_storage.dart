import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour stocker les SMS en attente de traitement
///
/// Utilisé pour la communication cross-isolate :
/// - L'isolat du background service écrit les SMS reçus
/// - L'app principale lit et traite ces SMS au démarrage
class PendingSmsStorage {
  static const String _keyPendingSms = 'pending_sms_list';

  /// Ajoute un SMS à la liste d'attente (safe pour isolat)
  static Future<void> addPendingSms({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_keyPendingSms) ?? [];

      final smsData = jsonEncode({
        'sender': sender,
        'body': body,
        'receivedAt': receivedAt.toIso8601String(),
      });

      pending.add(smsData);
      await prefs.setStringList(_keyPendingSms, pending);
      print('📥 [PendingSmsStorage] SMS ajouté en attente: $sender');
    } catch (e) {
      print('❌ [PendingSmsStorage] Erreur ajout SMS: $e');
    }
  }

  /// Récupère tous les SMS en attente
  static Future<List<Map<String, dynamic>>> getPendingSms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_keyPendingSms) ?? [];

      return pending.map((smsJson) {
        final Map<String, dynamic> data = jsonDecode(smsJson);
        return {
          'sender': data['sender'] as String,
          'body': data['body'] as String,
          'receivedAt': DateTime.parse(data['receivedAt'] as String),
        };
      }).toList();
    } catch (e) {
      print('❌ [PendingSmsStorage] Erreur lecture SMS: $e');
      return [];
    }
  }

  /// Efface tous les SMS en attente
  static Future<void> clearPendingSms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPendingSms);
      print('🗑️ [PendingSmsStorage] SMS en attente effacés');
    } catch (e) {
      print('❌ [PendingSmsStorage] Erreur effacement SMS: $e');
    }
  }

  /// Compte le nombre de SMS en attente
  static Future<int> pendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> pending = prefs.getStringList(_keyPendingSms) ?? [];
      return pending.length;
    } catch (e) {
      print('❌ [PendingSmsStorage] Erreur comptage SMS: $e');
      return 0;
    }
  }
}
