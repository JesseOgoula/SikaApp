import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:sika_app/core/services/analytics_service.dart';

/// Écran de connexion — Design Onboarding Premium
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Données des slides d'onboarding
  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Tous vos comptes réunis',
      description:
          'Ajoutez vos comptes Airtel Money, Moov Money, bancaires '
          'et en espèces. Suivez vos revenus et dépenses '
          'en un coup d\'œil.',
      color: Color(0xFF1A237E),
    ),
    _OnboardingSlide(
      icon: Icons.savings_rounded,
      title: 'Objectifs & Budgets',
      description:
          'Fixez des objectifs d\'épargne et créez des budgets par catégorie. '
          'SIKA vous aide à atteindre vos rêves financiers, '
          'un petit pas à la fois.',
      color: Color(0xFF0D47A1),
    ),
    _OnboardingSlide(
      icon: Icons.receipt_long_rounded,
      title: 'Dettes & Échéances',
      description:
          'Gardez le contrôle sur vos dettes et factures. '
          'Recevez des rappels avant chaque échéance '
          'et ne manquez plus aucun paiement.',
      color: Color(0xFF311B92),
    ),
    _OnboardingSlide(
      icon: Icons.emoji_events_rounded,
      title: 'Gagnez en jouant',
      description:
          'Chaque action rapporte des XP : transactions, budgets respectés, '
          'épargne… Grimpez les rangs et devenez un Sika Boss !',
      color: Color(0xFF1B5E20),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Écoute les erreurs
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // ─── En-tête logo ───
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/LOGOLOGIN.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 8),

              // ─── Carousel Onboarding ───
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) => _buildSlide(_slides[index]),
                ),
              ),

              // ─── Indicateurs de page ───
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Boutons de connexion ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    // Google Sign-In
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                await AnalyticsService.logEvent('auth_started');
                                ref
                                    .read(authControllerProvider.notifier)
                                    .login();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildGoogleIcon(),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continuer avec Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Disclaimer
                    Text(
                      'En continuant, vous acceptez nos conditions d\'utilisation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withOpacity(0.6),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit un slide d'onboarding
  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône dans un cercle dégradé
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  slide.color.withOpacity(0.12),
                  slide.color.withOpacity(0.04),
                ],
              ),
            ),
            child: Icon(slide.icon, size: 40, color: slide.color),
          ),

          const SizedBox(height: 28),

          // Titre
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 14),

          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// Icône Google (SVG transparent)
  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: 22,
      height: 22,
    );
  }
}

/// Modèle pour un slide d'onboarding
class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
