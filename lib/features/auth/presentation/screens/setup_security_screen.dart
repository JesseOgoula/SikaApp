import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/app_lock_service.dart';

/// Écran de configuration de la sécurité (affiché après inscription)
///
/// L'utilisateur DOIT configurer un PIN à 4 chiffres.
/// Ensuite, on lui propose d'activer l'empreinte digitale.
class SetupSecurityScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SetupSecurityScreen({super.key, required this.onComplete});

  @override
  State<SetupSecurityScreen> createState() => _SetupSecurityScreenState();
}

class _SetupSecurityScreenState extends State<SetupSecurityScreen>
    with SingleTickerProviderStateMixin {
  final _appLock = AppLockService();
  final PageController _pageController = PageController();

  // État
  int _currentStep = 0; // 0 = PIN, 1 = Biométrie
  bool _isLoading = false;
  String _errorMessage = '';

  // PIN
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _confirmPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _confirmPinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );

  // Biométrie
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

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
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final c in _confirmPinControllers) {
      c.dispose();
    }
    for (final f in _pinFocusNodes) {
      f.dispose();
    }
    for (final f in _confirmPinFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _appLock.isBiometricAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  String _getPinValue(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text).join();
  }

  void _clearPinFields(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    for (final c in controllers) {
      c.clear();
    }
    if (focusNodes.isNotEmpty) {
      focusNodes[0].requestFocus();
    }
  }

  Future<void> _submitPin() async {
    final pin = _getPinValue(_pinControllers);
    final confirmPin = _getPinValue(_confirmPinControllers);

    if (pin.length != 4) {
      setState(() => _errorMessage = 'Veuillez saisir un PIN à 4 chiffres');
      return;
    }

    if (confirmPin.length != 4) {
      setState(() => _errorMessage = 'Veuillez confirmer votre PIN');
      return;
    }

    if (pin != confirmPin) {
      setState(() => _errorMessage = 'Les codes PIN ne correspondent pas');
      _clearPinFields(_confirmPinControllers, _confirmPinFocusNodes);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _appLock.setPin(pin);

      if (_biometricAvailable) {
        // Passe à l'étape biométrie
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        // Biométrie non dispo → terminé
        widget.onComplete();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors de la sauvegarde du PIN';
      });
    }
  }

  Future<void> _enableBiometric() async {
    setState(() => _isLoading = true);

    try {
      // Tester la biométrie
      final success = await _appLock.authenticateWithBiometric();
      if (success) {
        await _appLock.enableBiometric();
        setState(() => _biometricEnabled = true);

        // Petite pause pour l'animation de succès
        await Future.delayed(const Duration(milliseconds: 800));
        widget.onComplete();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentification biométrique échouée';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur empreinte digitale';
      });
    }
  }

  void _skipBiometric() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    // Indicateur d'étape
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Étape ${_currentStep + 1}/${_biometricAvailable ? 2 : 1}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenu
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPinSetupPage(),
                    if (_biometricAvailable) _buildBiometricPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Page PIN ====================

  Widget _buildPinSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Icône bouclier
          Container(
            width: 88,
            height: 88,
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
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 28),

          // Titre
          Text(
            'Protégez votre compte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Créez un code PIN à 4 chiffres pour\nsécuriser l\'accès à SIKA',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 40),

          // Champs PIN
          Text(
            'Code PIN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPinRow(_pinControllers, _pinFocusNodes),

          const SizedBox(height: 24),

          // Confirmation
          Text(
            'Confirmez votre PIN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPinRow(_confirmPinControllers, _confirmPinFocusNodes),

          // Erreur
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
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

          const SizedBox(height: 32),

          // Bouton Confirmer
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmer le PIN',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Ligne de 4 champs PIN individuels
  Widget _buildPinRow(
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 56,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 6),
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
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: AppTheme.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                focusNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                focusNodes[index - 1].requestFocus();
              }
              setState(() => _errorMessage = '');
            },
          ),
        );
      }),
    );
  }

  // ==================== Page Biométrie ====================

  Widget _buildBiometricPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône empreinte
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _biometricEnabled
                    ? [
                        AppTheme.success.withOpacity(0.15),
                        AppTheme.success.withOpacity(0.05),
                      ]
                    : [
                        AppTheme.primaryColor.withOpacity(0.12),
                        AppTheme.primaryColor.withOpacity(0.04),
                      ],
              ),
            ),
            child: Icon(
              _biometricEnabled
                  ? Icons.check_circle_rounded
                  : Icons.fingerprint_rounded,
              size: 56,
              color: _biometricEnabled
                  ? AppTheme.success
                  : AppTheme.primaryColor,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            _biometricEnabled
                ? 'Empreinte activée !'
                : 'Accès rapide par empreinte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            _biometricEnabled
                ? 'Votre empreinte digitale est configurée.\nAccédez à SIKA en un instant.'
                : 'Déverrouillez SIKA avec votre empreinte\ndigitale pour un accès plus rapide et sécurisé.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 40),

          if (!_biometricEnabled) ...[
            // Bouton activer empreinte
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _enableBiometric,
                icon: const Icon(Icons.fingerprint_rounded, size: 22),
                label: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Activer l\'empreinte digitale',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton Passer
            SizedBox(
              width: double.infinity,
              height: 54,
              child: TextButton(
                onPressed: _skipBiometric,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Peut-être plus tard',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
