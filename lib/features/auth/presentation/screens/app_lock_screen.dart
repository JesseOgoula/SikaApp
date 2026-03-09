import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/app_lock_service.dart';

/// Écran de déverrouillage de l'app (PIN uniquement)
///
/// Affiché au retour dans l'app (fermeture, mise en veille, verrouillage du téléphone).
/// Utilise un pavé numérique personnalisé.
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

  String _pin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  int _attempts = 0;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String key) {
    if (_pin.length >= 4 || _isLoading) return;

    setState(() {
      _errorMessage = '';
      _pin += key;
    });

    // Auto-vérification quand les 4 chiffres sont saisis
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final isValid = await _appLock.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      widget.onUnlocked();
    } else {
      _attempts++;
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();

      setState(() {
        _isLoading = false;
        _pin = '';
        _errorMessage = _attempts >= 5
            ? 'Trop de tentatives. Réinitialisez votre PIN.'
            : 'Code PIN incorrect ($_attempts/5)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Column(
          children: [
            // Contenu en haut
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/logowhite.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.lock_rounded,
                          size: 72,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Titre
                      const Text(
                        'Bienvenue !',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Saisissez votre code PIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // PIN dots avec animation de shake
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          final dx =
                              _shakeAnimation.value *
                              10 *
                              ((_shakeController.status ==
                                      AnimationStatus.forward)
                                  ? 1
                                  : -1);
                          return Transform.translate(
                            offset: Offset(dx * (1 - _shakeAnimation.value), 0),
                            child: child,
                          );
                        },
                        child: _buildPinDots(),
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

                      // Mot de passe oublié
                      if (widget.onForgotPin != null || _attempts >= 3) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed:
                              widget.onForgotPin ?? () => _showResetDialog(),
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
                    ],
                  ),
                ),
              ),
            ),

            // Pavé numérique personnalisé (en bas)
            _buildPinPad(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isFilled ? 20 : 16,
          height: isFilled ? 20 : 16,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.transparent,
            border: Border.all(
              color: isFilled ? Colors.white : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPinPad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Column(
        children: [
          _buildPadRow(['1', '2', '3']),
          const SizedBox(height: 10),
          _buildPadRow(['4', '5', '6']),
          const SizedBox(height: 10),
          _buildPadRow(['7', '8', '9']),
          const SizedBox(height: 10),
          _buildPadRow(['', '0', '']),
        ],
      ),
    );
  }

  Widget _buildPadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildPadKey(key)).toList(),
    );
  }

  Widget _buildPadKey(String key) {
    if (key.isEmpty) {
      return const SizedBox(width: 72, height: 56);
    }

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              _onKeyPressed(key);
            },
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
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
