import 'package:flutter/material.dart';

/// Splash screen personnalisé avec logos de taille contrôlée
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Attendre 2.5 secondes puis continuer
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303F9F),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Column(
          children: [
            // Logo centré
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/logowhite.png',
                  width: 120, // Taille contrôlée
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Branding en bas
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Image.asset(
                'assets/images/logo2.png',
                width: 150, // Taille contrôlée
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
