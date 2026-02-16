import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Overlay plein écran avec animation de confettis pour célébrer un objectif atteint.
class GoalCelebrationOverlay {
  static void show(BuildContext context, {required String goalName}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CelebrationWidget(
        goalName: goalName,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _CelebrationWidget extends StatefulWidget {
  final String goalName;
  final VoidCallback onDismiss;

  const _CelebrationWidget({required this.goalName, required this.onDismiss});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _contentController;
  late Animation<double> _contentScale;
  late Animation<double> _contentOpacity;
  late List<_ConfettiParticle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _contentScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.elasticOut),
    );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _particles = List.generate(80, (_) => _ConfettiParticle(_random));

    _confettiController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });

    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _contentController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Fond flou + teinte
            AnimatedBuilder(
              animation: _contentController,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 8.0 * _contentOpacity.value,
                  sigmaY: 8.0 * _contentOpacity.value,
                ),
                child: Container(
                  color: AppTheme.primaryColor.withValues(
                    alpha: 0.5 * _contentOpacity.value,
                  ),
                ),
              ),
            ),

            // Confettis
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),

            // Contenu central
            Center(
              child: AnimatedBuilder(
                animation: _contentController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _contentOpacity.value,
                    child: Transform.scale(
                      scale: _contentScale.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icone sobre
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Titre
                      const Text(
                        'Objectif Atteint',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nom de l'objectif
                      Text(
                        widget.goalName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      Text(
                        'Félicitations, tu as atteint ton objectif d\'épargne avec succès.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Bouton
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _dismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Continuer',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CONFETTI ====================

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double wobble;
  final double wobbleSpeed;
  final Color color;
  final int shape;

  _ConfettiParticle(Random random)
    : x = random.nextDouble(),
      speed = 0.5 + random.nextDouble() * 0.8,
      size = 6 + random.nextDouble() * 8,
      rotation = random.nextDouble() * pi * 2,
      rotationSpeed = (random.nextDouble() - 0.5) * 6,
      wobble = random.nextDouble() * 30,
      wobbleSpeed = 2 + random.nextDouble() * 4,
      shape = random.nextInt(3),
      color = _confettiColors[random.nextInt(_confettiColors.length)];

  static const _confettiColors = [
    Color(0xFF1A237E), // Bleu Nuit
    Color(0xFF311B92), // Violet profond
    Color(0xFF5C6BC0), // Indigo clair
    Color(0xFF7C4DFF), // Violet
    Color(0xFF448AFF), // Bleu
    Color(0xFFB0BEC5), // Gris argente
    Colors.white,
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = -50 + (size.height + 100) * progress * p.speed;
      final x =
          p.x * size.width + sin(progress * p.wobbleSpeed * pi * 2) * p.wobble;

      final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * p.rotationSpeed);

      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
          break;
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case 2:
          final path = Path()
            ..moveTo(0, -p.size * 0.4)
            ..lineTo(p.size * 0.4, p.size * 0.4)
            ..lineTo(-p.size * 0.4, p.size * 0.4)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
