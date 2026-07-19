import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sika_app/core/theme/app_theme.dart';

/// Clé de préférence pour savoir si le disclaimer a été accepté
const String kDisclaimerAccepted = 'disclaimer_accepted';

/// Écran de disclaimer affiché une seule fois après la création du compte.
class DisclaimerScreen extends StatefulWidget {
  final VoidCallback onAccepted;

  const DisclaimerScreen({super.key, required this.onAccepted});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;
  final PageController _pageController = PageController();
  bool _isAccepting = false;

  static const int _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _acceptAndContinue() async {
    setState(() => _isAccepting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kDisclaimerAccepted, true);
      widget.onAccepted();
    } catch (_) {
      widget.onAccepted();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
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
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  children: [
                    _buildSecurityPage(),
                    _buildHowItWorksPage(),
                    _buildPrivacyPage(),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _totalPages,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isAccepting
                        ? null
                        : (_currentPage < _totalPages - 1
                            ? _nextPage
                            : _acceptAndContinue),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentPage < _totalPages - 1
                                ? 'Suivant'
                                : 'J\'ai compris, continuer',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 32,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildSecurityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildHeaderIcon(Icons.shield_outlined),
          const SizedBox(height: 28),
          Text(
            'Votre argent est en sécurité',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          _buildSoberItem(
            icon: Icons.money_off_outlined,
            title: 'Aucune transaction initiée',
            description:
                'SIKA ne peut pas effectuer de transferts, paiements '
                'ou retraits. Votre argent reste sous votre contrôle.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            icon: Icons.visibility_off_outlined,
            title: 'Aucun mot de passe stocké',
            description:
                'SIKA ne demande et ne stocke jamais '
                'vos identifiants bancaires ou codes PIN.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            icon: Icons.phone_android_outlined,
            title: 'Stockage local',
            description:
                'Vos données sont stockées sur votre appareil. '
                'Vous seul y avez accès.',
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildHeaderIcon(Icons.notifications_outlined),
          const SizedBox(height: 28),
          Text(
            'Comment ça marche ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          _buildSoberItem(
            number: '1',
            title: 'Réception du message',
            description:
                'Lors d\'une opération, votre opérateur '
                'vous envoie un SMS ou une notification.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            number: '2',
            title: 'Lecture sécurisée',
            description:
                'SIKA lit uniquement les notifications et SMS '
                'provenant de vos opérateurs financiers.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            number: '3',
            title: 'Enregistrement',
            description:
                'Le montant et la date sont extraits. '
                'Vous gardez la possibilité de modifier ou supprimer.',
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildHeaderIcon(Icons.privacy_tip_outlined),
          const SizedBox(height: 28),
          Text(
            'Vos données, vos règles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          _buildSoberItem(
            icon: Icons.notifications_outlined,
            title: 'Accès aux notifications',
            description:
                'Utilisé uniquement pour lire les messages de '
                'vos opérateurs financiers.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            icon: Icons.sms_outlined,
            title: 'Accès aux SMS',
            description:
                'Utilisé pour lire les SMS de confirmation. '
                'Aucun autre SMS n\'est lu.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            icon: Icons.cloud_off_outlined,
            title: 'Pas de partage',
            description:
                'Vos données ne sont jamais partagées à des tiers '
                'ou à des services externes.',
          ),
          _buildStepConnector(),
          _buildSoberItem(
            icon: Icons.delete_outline,
            title: 'Suppression à tout moment',
            description:
                'Vous pouvez supprimer toutes vos données '
                'directement depuis l\'application.',
          ),
          const SizedBox(height: 32),
          Text(
            'En continuant, vous confirmez avoir pris connaissance '
            'de ces informations et vous acceptez nos conditions '
            'd\'utilisation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoberItem({
    IconData? icon,
    String? number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: number != null
                ? Text(
                    number,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(icon, color: AppTheme.primaryColor, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}
