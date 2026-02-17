import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Carte de santé financière enrichie avec le système de rangs XP
///
/// Affiche :
/// - Score de santé (jauge circulaire)
/// - Rang actuel (icône + nom + level)
/// - Barre de progression XP vers le prochain rang
/// - Description contextuelle
class HealthScoreCard extends StatelessWidget {
  final int healthScore;
  final int totalXP;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
    this.totalXP = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rank = RankDefinitions.getRankForXP(totalXP);
    final nextRank = RankDefinitions.getNextRank(rank);
    final progress = rank.progressInRank(totalXP);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Jauge circulaire avec score
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: healthScore / 100,
                      strokeWidth: 8,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                      color: AppTheme.primaryColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$healthScore',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
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
              // Info rang
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge rang
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            rank.icon,
                            color: AppTheme.primaryColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Lv.${rank.level} — ${rank.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                      rank.encouragement,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Barre de progression XP vers le prochain rang
          if (nextRank != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Prochain : ${nextRank.name}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '${_formatXP(totalXP)} / ${_formatXP(nextRank.minXP)} XP',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.08,
                          ),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  nextRank.icon,
                  color: AppTheme.textSecondary.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ],

          // Max rank indicator
          if (nextRank == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.diamond,
                  color: AppTheme.primaryColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Rang maximum atteint !',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatXP(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return '$xp';
  }
}
