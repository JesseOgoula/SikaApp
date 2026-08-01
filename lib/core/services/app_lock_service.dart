import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_app/core/utils/logger.dart';

/// Service de verrouillage local de l'application (PIN + Biométrie)
///
/// Gère le stockage sécurisé du PIN (hash HMAC-SHA-256 avec sel),
/// les préférences biométriques et le flux de setup.
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Clés Secure Storage
  static const _keyPinHash = 'sika_pin_hash';
  static const _keyPinSalt = 'sika_pin_salt';

  // Clés SharedPreferences
  static const _keyBiometricEnabled = 'sika_biometric_enabled';
  static const _keySecuritySetupDone = 'sika_security_setup_done';
  static const _keyLockEnabled = 'sika_lock_enabled';

  // ==================== HASH ====================

  /// Génère un sel cryptographique aléatoire (32 caractères hex)
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash HMAC-SHA-256 avec sel (résistant aux rainbow tables)
  String _hashWithSalt(String value, String salt) {
    final key = utf8.encode(salt);
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(value)).toString();
  }


  // ==================== PIN ====================

  /// Définir un code PIN à 4 chiffres
  Future<void> setPin(String pin) async {
    assert(pin.length == 4, 'Le PIN doit contenir exactement 4 chiffres');
    final salt = _generateSalt();
    final hash = _hashWithSalt(pin, salt);
    await _storage.write(key: _keyPinSalt, value: salt);
    await _storage.write(key: _keyPinHash, value: hash);
    await setLockEnabled(true);
    await _setSecuritySetupDone(true);
    SikaLogger.info('PIN défini avec succès (HMAC-SHA256 + sel)', tag: 'APP_LOCK');
  }

  /// Vérifie un code PIN
  ///
  /// Supporte la migration automatique depuis l'ancien format (SHA-256 sans sel) :
  /// si aucun sel n'est trouvé, tente la vérification legacy puis re-hash avec sel.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _keyPinHash);
    if (storedHash == null) return false;

    final storedSalt = await _storage.read(key: _keyPinSalt);

    if (storedSalt != null) {
      // Nouveau format : HMAC-SHA256 avec sel
      return _hashWithSalt(pin, storedSalt) == storedHash;
    } else {
      // Migration depuis l'ancien format (SHA-256 sans sel)
      final legacyHash = sha256.convert(utf8.encode(pin)).toString();
      if (legacyHash == storedHash) {
        // Migration automatique vers le nouveau format
        SikaLogger.info('Migration PIN vers HMAC-SHA256 + sel', tag: 'APP_LOCK');
        await setPin(pin);
        return true;
      }
      return false;
    }
  }

  /// Change le PIN (vérifie l'ancien d'abord)
  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) return false;
    await setPin(newPin);
    return true;
  }

  /// Vérifie si un PIN est configuré
  Future<bool> hasPinConfigured() async {
    final hash = await _storage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  // ==================== BIOMÉTRIE ====================

  /// Vérifie si le hardware supporte la biométrie
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      SikaLogger.error('Erreur vérif biométrie: $e', tag: 'APP_LOCK');
      return false;
    }
  }

  /// Liste les types biométriques disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Active la biométrie
  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, true);
    SikaLogger.info('Biométrie activée', tag: 'APP_LOCK');
  }

  /// Désactive la biométrie
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, false);
    SikaLogger.info('Biométrie désactivée', tag: 'APP_LOCK');
  }

  /// Vérifie si la biométrie est activée par l'utilisateur
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Authentification biométrique
  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      final isEnabled = await isBiometricEnabled();
      if (!isAvailable || !isEnabled) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Déverrouillez SIKA avec votre empreinte digitale',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      SikaLogger.error('Erreur biométrie: $e', tag: 'APP_LOCK');
      return false;
    }
  }

  // ==================== SETUP & ÉTAT ====================

  /// Vérifie si la configuration de sécurité a été complétée
  Future<bool> isSecuritySetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySecuritySetupDone) ?? false;
  }

  /// Marque la configuration comme faite
  Future<void> _setSecuritySetupDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecuritySetupDone, done);
  }

  /// Vérifie si le verrou est activé
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLockEnabled) ?? false;
  }

  /// Active/désactive le verrou
  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, enabled);
  }

  /// Réinitialise toute la sécurité locale
  Future<void> clearSecurity() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyPinSalt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keySecuritySetupDone);
    await prefs.remove(_keyLockEnabled);
    SikaLogger.info('Sécurité réinitialisée', tag: 'APP_LOCK');
  }
}
