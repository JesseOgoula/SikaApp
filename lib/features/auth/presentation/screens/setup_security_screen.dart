import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/app_lock_service.dart';

/// Écran de configuration de la sécurité (affiché après inscription)
///
/// L'utilisateur DOIT configurer un PIN à 4 chiffres.
/// Utilise un pavé numérique personnalisé (pas le clavier Android).
class SetupSecurityScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SetupSecurityScreen({super.key, required this.onComplete});

  @override
  State<SetupSecurityScreen> createState() => _SetupSecurityScreenState();
}

class _SetupSecurityScreenState extends State<SetupSecurityScreen>
    with SingleTickerProviderStateMixin {
  final _appLock = AppLockService();

  // État
  bool _isLoading = false;
  bool _isConfirming = false; // true = on saisit la confirmation
  String _errorMessage = '';
  String _pin = '';
  String _confirmPin = '';
  String _savedFirstPin = ''; // PIN sauvegardé pour comparaison

  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String key) {
    setState(() => _errorMessage = '');

    if (_isConfirming) {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += key);
        if (_confirmPin.length == 4) {
          _submitPin();
        }
      }
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += key);
        if (_pin.length == 4) {
          // Passer à la confirmation
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _savedFirstPin = _pin;
                _isConfirming = true;
                _pin = '';
              });
            }
          });
        }
      }
    }
  }

  Future<void> _submitPin() async {
    if (_savedFirstPin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Les codes PIN ne correspondent pas';
        _confirmPin = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _appLock.setPin(_savedFirstPin);
      widget.onComplete();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la sauvegarde du PIN';
        _confirmPin = '';
      });
    }
  }

  void _goBackToFirstPin() {
    setState(() {
      _isConfirming = false;
      _pin = '';
      _confirmPin = '';
      _savedFirstPin = '';
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Contenu scrollable en haut
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),

                      // Icône
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.12),
                              AppTheme.primaryColor.withOpacity(0.04),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 36,
                          color: AppTheme.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Titre
                      Text(
                        _isConfirming
                            ? 'Confirmez votre PIN'
                            : 'Protégez votre compte',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        _isConfirming
                            ? 'Saisissez à nouveau votre code PIN'
                            : 'Créez un code PIN à 4 chiffres\npour sécuriser l\'accès à SIKA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Indicateurs PIN (4 cercles)
                      _buildPinDots(currentPin),

                      // Erreur
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Bouton retour si on confirme
                      if (_isConfirming) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _goBackToFirstPin,
                          child: Text(
                            'Modifier le PIN',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Loading indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),

              // Pavé numérique personnalisé (en bas)
              _buildPinPad(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isFilled ? 20 : 16,
          height: isFilled ? 20 : 16,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppTheme.primaryColor : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary.withOpacity(0.3),
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
          color: AppTheme.scaffoldBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            key,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
