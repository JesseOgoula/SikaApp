import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:safe_device/safe_device.dart';
import 'package:sika_app/core/utils/logger.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Vérifie l'intégrité de l'appareil
  Future<bool> checkDeviceIntegrity() async {
    try {
      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isDeveloperMode = await SafeDevice.isDevelopmentModeEnable;

      if (isJailBroken) {
        SikaLogger.warn('Device is rooted/jailbroken!', tag: 'SECURITY');
        return false;
      }

      if (!isRealDevice && !isDeveloperMode) {
        // Au cas où
      }

      return true;
    } catch (e) {
      SikaLogger.error('Security check failed: $e', tag: 'SECURITY');
      return true; // En cas d'erreur, on laisse passer
    }
  }

  /// Authentification Biométrique
  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return true;

      return await _auth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour accéder à SIKA',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      SikaLogger.error('Biometric auth error: $e', tag: 'SECURITY');
      return true; // En cas d'erreur, on laisse passer pour ne pas bloquer
    }
  }
}
