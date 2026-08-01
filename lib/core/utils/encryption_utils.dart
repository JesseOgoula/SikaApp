import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service utilitaire pour la gestion de la clé de chiffrement SQLCipher
class EncryptionUtils {
  static const _storage = FlutterSecureStorage();
  static const _keyAlias = 'sika_db_master_key';

  /// Récupère la clé maître de chiffrement.
  /// Si elle n'existe pas, elle est générée et stockée de manière sécurisée.
  static Future<String> getEncryptionKey() async {
    final existingKey = await _storage.read(key: _keyAlias);
    
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Génération d'une nouvelle clé forte (32 octets / 256 bits) en Base64
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = base64UrlEncode(keyBytes);

    await _storage.write(key: _keyAlias, value: newKey);
    return newKey;
  }
}
