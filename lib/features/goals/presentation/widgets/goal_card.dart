import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Carte d'affichage d'un objectif d'épargne
///
/// Tap sur la carte pour alimenter l'objectif (si non terminé)
class GoalCard extends StatelessWidget {
  final GoalsTableData goal;
  final VoidCallback? onTap;
  final VoidCallback? onFeedPressed;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onFeedPressed,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    final progress = goal.targetAmount > 0
        ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toInt();
    final remaining = goal.targetAmount - goal.savedAmount;

    return GestureDetector(
      // Tap sur la carte = alimenter l'objectif
      onTap: goal.isCompleted ? onTap : (onFeedPressed ?? onTap),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: goal.isCompleted
                ? AppTheme.success.withOpacity(0.2)
                : AppTheme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icône + Nom + Badge
            Row(
              children: [
                // Icône
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: goal.isCompleted
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(
                      _getGoalIcon(goal.iconKey),
                      color: goal.isCompleted
                          ? AppTheme.success
                          : AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nom + Reste
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goal.isCompleted
                            ? 'Objectif atteint 🎉'
                            : 'Reste ${currencyFormat.format(remaining)}',
                        style: TextStyle(
                          color: goal.isCompleted
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge pourcentage/complet
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: goal.isCompleted
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: goal.isCompleted
                      ? const Text(
                          '✓',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentage%',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppTheme.primaryColor,
                              size: 14,
                            ),
                          ],
                        ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted ? AppTheme.success : AppTheme.primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Montants
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(goal.savedAmount),
                  style: TextStyle(
                    color: goal.isCompleted
                        ? AppTheme.success
                        : AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'sur ${currencyFormat.format(goal.targetAmount)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGoalIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.bullseye;
    switch (iconKey) {
      case 'laptop':
        return FontAwesomeIcons.laptop;
      case 'car':
        return FontAwesomeIcons.car;
      case 'plane':
        return FontAwesomeIcons.plane;
      case 'home':
        return FontAwesomeIcons.house;
      case 'phone':
        return FontAwesomeIcons.mobileScreen;
      case 'gift':
        return FontAwesomeIcons.gift;
      case 'graduation':
        return FontAwesomeIcons.graduationCap;
      case 'heart':
        return FontAwesomeIcons.heart;
      case 'piggyBank':
        return FontAwesomeIcons.piggyBank;
      default:
        return FontAwesomeIcons.bullseye;
    }
  }
}
