import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/app_lock_service.dart';

/// Écran de déverrouillage de l'app (PIN + biométrie)
///
/// Affiché au retour dans l'app quand le verrou est activé.
/// Tente la biométrie automatiquement si activée, sinon affiche la saisie PIN.
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback? onForgotPin;

  const AppLockScreen({super.key, required this.onUnlocked, this.onForgotPin});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final _appLock = AppLockService();
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  String _errorMessage = '';
  int _attempts = 0;
  bool _biometricAvailable = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _initBiometric();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final isEnabled = await _appLock.isBiometricEnabled();
    final isAvailable = await _appLock.isBiometricAvailable();
    _biometricAvailable = isEnabled && isAvailable;

    if (_biometricAvailable) {
      _tryBiometric();
    } else {
      // Focus sur le premier champ PIN
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pinFocusNodes.isNotEmpty) {
          _pinFocusNodes[0].requestFocus();
        }
      });
    }
  }

  Future<void> _tryBiometric() async {
    final success = await _appLock.authenticateWithBiometric();
    if (success && mounted) {
      widget.onUnlocked();
    } else if (mounted) {
      // Fallback : affiche le PIN
      _pinFocusNodes[0].requestFocus();
    }
  }

  String _getPinValue() {
    return _pinControllers.map((c) => c.text).join();
  }

  void _clearPin() {
    for (final c in _pinControllers) {
      c.clear();
    }
    if (_pinFocusNodes.isNotEmpty) {
      _pinFocusNodes[0].requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    final pin = _getPinValue();
    if (pin.length != 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final isValid = await _appLock.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      widget.onUnlocked();
    } else {
      _attempts++;
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();

      setState(() {
        _isLoading = false;
        _errorMessage = _attempts >= 5
            ? 'Trop de tentatives. Réinitialisez votre PIN.'
            : 'Code PIN incorrect ($_attempts/5)';
      });

      _clearPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logowhite.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.lock_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

                const SizedBox(height: 32),

                // Titre
                const Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Saisissez votre code PIN pour continuer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // PIN avec animation de shake
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final dx =
                        _shakeAnimation.value *
                        10 *
                        ((_shakeController.status == AnimationStatus.forward)
                            ? 1
                            : -1);
                    return Transform.translate(
                      offset: Offset(dx * (1 - _shakeAnimation.value), 0),
                      child: child,
                    );
                  },
                  child: _buildPinRow(),
                ),

                // Erreur
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Bouton Déverrouiller
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : const Text(
                            'Déverrouiller',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton biométrie
                if (_biometricAvailable)
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                    label: Text(
                      'Utiliser l\'empreinte digitale',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Mot de passe oublié
                if (widget.onForgotPin != null || _attempts >= 3)
                  TextButton(
                    onPressed: widget.onForgotPin ?? () => _showResetDialog(),
                    child: Text(
                      'PIN oublié ?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 56,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                _pinFocusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _pinFocusNodes[index - 1].requestFocus();
              }
              setState(() => _errorMessage = '');

              // Auto-vérification quand les 4 chiffres sont saisis
              if (index == 3 && value.isNotEmpty) {
                _verifyPin();
              }
            },
          ),
        );
      }),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Réinitialiser le PIN ?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Vous serez déconnecté et devrez vous reconnecter avec Google pour définir un nouveau PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.onForgotPin != null) {
                widget.onForgotPin!();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
