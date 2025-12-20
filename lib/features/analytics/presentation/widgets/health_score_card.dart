import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';

class HealthScoreCard extends StatelessWidget {
  final int healthScore;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    String label;
    String description;

    if (healthScore >= 80) {
      scoreColor = AppTheme.success;
      label = 'Excellent';
      description = 'Votre santé financière est au top ! Continuez ainsi.';
    } else if (healthScore >= 60) {
      scoreColor = AppTheme.primaryColor;
      label = 'Bonne';
      description =
          'Vous gérez bien, mais quelques ajustements sont possibles.';
    } else if (healthScore >= 40) {
      scoreColor = Colors.orange;
      label = 'Moyenne';
      description = 'Attention à vos dépenses. Essayez d\'épargner plus.';
    } else {
      scoreColor = AppTheme.error;
      label = 'Critique';
      description = 'Action requise ! Revoyez votre budget et vos dettes.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withOpacity(0.15),
            scoreColor.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scoreColor.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: healthScore / 100,
                  strokeWidth: 8,
                  backgroundColor: scoreColor.withOpacity(0.1),
                  color: scoreColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    '$healthScore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Score de santé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
