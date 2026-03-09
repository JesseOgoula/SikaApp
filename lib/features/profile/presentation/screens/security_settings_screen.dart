import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/app_lock_service.dart';

/// Écran des paramètres de sécurité
///
/// Permet de :
/// - Changer le code PIN
/// - Activer/désactiver l'empreinte digitale
class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _appLock = AppLockService();

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final bioAvailable = await _appLock.isBiometricAvailable();
    final bioEnabled = await _appLock.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _biometricAvailable = bioAvailable;
        _biometricEnabled = bioEnabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Tester la biométrie avant d'activer
      final success = await _appLock.authenticateWithBiometric();
      if (success) {
        await _appLock.enableBiometric();
        setState(() => _biometricEnabled = true);
        _showSnackBar('Empreinte digitale activée', isSuccess: true);
      } else {
        _showSnackBar('Authentification échouée', isSuccess: false);
      }
    } else {
      await _appLock.disableBiometric();
      setState(() => _biometricEnabled = false);
      _showSnackBar('Empreinte digitale désactivée', isSuccess: true);
    }
  }

  void _showChangePinDialog() {
    final oldPinControllers = List.generate(4, (_) => TextEditingController());
    final newPinControllers = List.generate(4, (_) => TextEditingController());
    final confirmPinControllers = List.generate(
      4,
      (_) => TextEditingController(),
    );
    final oldFocusNodes = List.generate(4, (_) => FocusNode());
    final newFocusNodes = List.generate(4, (_) => FocusNode());
    final confirmFocusNodes = List.generate(4, (_) => FocusNode());
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Changer le PIN',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIN actuel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildDialogPinRow(
                  oldPinControllers,
                  oldFocusNodes,
                  nextFocusNodes: newFocusNodes,
                ),

                const SizedBox(height: 20),
                const Text(
                  'Nouveau PIN',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildDialogPinRow(
                  newPinControllers,
                  newFocusNodes,
                  nextFocusNodes: confirmFocusNodes,
                ),

                const SizedBox(height: 20),
                const Text(
                  'Confirmer le nouveau PIN',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildDialogPinRow(confirmPinControllers, confirmFocusNodes),

                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMsg!,
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                for (final c in [
                  ...oldPinControllers,
                  ...newPinControllers,
                  ...confirmPinControllers,
                ]) {
                  c.dispose();
                }
                for (final f in [
                  ...oldFocusNodes,
                  ...newFocusNodes,
                  ...confirmFocusNodes,
                ]) {
                  f.dispose();
                }
              },
              child: Text(
                'Annuler',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final oldPin = oldPinControllers.map((c) => c.text).join();
                final newPin = newPinControllers.map((c) => c.text).join();
                final confirmPin = confirmPinControllers
                    .map((c) => c.text)
                    .join();

                if (oldPin.length != 4) {
                  setDialogState(() => errorMsg = 'Saisissez votre PIN actuel');
                  return;
                }
                if (newPin.length != 4) {
                  setDialogState(
                    () => errorMsg = 'Saisissez un nouveau PIN à 4 chiffres',
                  );
                  return;
                }
                if (newPin != confirmPin) {
                  setDialogState(
                    () => errorMsg = 'Les PIN ne correspondent pas',
                  );
                  return;
                }

                final success = await _appLock.changePin(oldPin, newPin);
                if (success) {
                  Navigator.pop(ctx);
                  _showSnackBar(
                    'Code PIN modifié avec succès',
                    isSuccess: true,
                  );
                } else {
                  setDialogState(() => errorMsg = 'PIN actuel incorrect');
                }

                for (final c in [
                  ...oldPinControllers,
                  ...newPinControllers,
                  ...confirmPinControllers,
                ]) {
                  c.dispose();
                }
                for (final f in [
                  ...oldFocusNodes,
                  ...newFocusNodes,
                  ...confirmFocusNodes,
                ]) {
                  f.dispose();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogPinRow(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes, {
    List<FocusNode>? nextFocusNodes,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 48,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppTheme.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                focusNodes[index + 1].requestFocus();
              } else if (value.isNotEmpty &&
                  index == 3 &&
                  nextFocusNodes != null) {
                nextFocusNodes[0].requestFocus();
              } else if (value.isEmpty && index > 0) {
                focusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sécurité',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Section PIN
                _buildSectionCard(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Code PIN',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'PIN à 4 chiffres configuré',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _showChangePinDialog,
                        child: Text(
                          'Modifier',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section Biométrie
                if (_biometricAvailable)
                  _buildSectionCard(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                (_biometricEnabled
                                        ? AppTheme.success
                                        : AppTheme.textSecondary)
                                    .withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.fingerprint_rounded,
                            color: _biometricEnabled
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                            size: 22,
                          ),
                        ),
                        title: const Text(
                          'Empreinte digitale',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          _biometricEnabled
                              ? 'Activée — déverrouillage rapide'
                              : 'Désactivée',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        value: _biometricEnabled,
                        onChanged: _toggleBiometric,
                        activeColor: AppTheme.success,
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: AppTheme.primaryColor.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Votre code PIN est stocké de manière chiffrée sur votre appareil. Personne ne peut y accéder.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
