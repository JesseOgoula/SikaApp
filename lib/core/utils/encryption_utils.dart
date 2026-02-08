import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class EncryptionUtils {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'sika_db_encryption_key';

  static Future<String> getDatabaseKey() async {
    String? key = await _storage.read(key: _dbKeyName);
    
    if (key == null) {
      // Génère une clé Aléatoire forte de 32 octets (256 bits)
      key = const Uuid().v4().replaceAll('-', '');
      await _storage.write(key: _dbKeyName, value: key);
    }
    
    return key;
  }
}
