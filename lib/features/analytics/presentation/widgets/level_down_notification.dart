import 'package:flutter/material.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Notification bienveillante quand l'utilisateur perd un rang
///
/// Pas d'animation punitive — juste un message encourageant
/// avec un ton positif et des conseils pour remonter.
/// Design sobre avec la palette Bleu Nuit.
class LevelDownNotification {
  /// Affiche une notification de baisse de rang sous forme de BottomSheet
  static void show(BuildContext context, RankTransition transition) {
    final newRank = transition.newRank;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icône du rang actuel
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.06),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 2,
                ),
              ),
              child: Icon(newRank.icon, color: AppTheme.primaryColor, size: 32),
            ),
            const SizedBox(height: 16),

            // Titre
            const Text(
              'Changement de rang',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Message bienveillant
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Tu es maintenant '),
                  TextSpan(
                    text: newRank.name,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '.\nContinue à utiliser SIKA\net tu remonteras vite !',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),



            // Bouton OK
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Compris, je vais remonter !',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
