import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_app/core/utils/logger.dart';

/// Service de verrouillage local de l'application (PIN + Biométrie)
///
/// Gère le stockage sécurisé du PIN (hash SHA-256),
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

  // Clés SharedPreferences
  static const _keyBiometricEnabled = 'sika_biometric_enabled';
  static const _keySecuritySetupDone = 'sika_security_setup_done';
  static const _keyLockEnabled = 'sika_lock_enabled';

  // ==================== HASH ====================

  /// Hash SHA-256 d'une chaîne
  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }

  // ==================== PIN ====================

  /// Définir un code PIN à 4 chiffres
  Future<void> setPin(String pin) async {
    assert(pin.length == 4, 'Le PIN doit contenir exactement 4 chiffres');
    final hash = _hashValue(pin);
    await _storage.write(key: _keyPinHash, value: hash);
    await setLockEnabled(true);
    await _setSecuritySetupDone(true);
    SikaLogger.info('PIN défini avec succès', tag: 'APP_LOCK');
  }

  /// Vérifie un code PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _keyPinHash);
    if (storedHash == null) return false;
    return _hashValue(pin) == storedHash;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keySecuritySetupDone);
    await prefs.remove(_keyLockEnabled);
    SikaLogger.info('Sécurité réinitialisée', tag: 'APP_LOCK');
  }
}
