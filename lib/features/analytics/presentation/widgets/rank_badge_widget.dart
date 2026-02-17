import 'package:flutter/material.dart';

import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Badge compact affichant le rang de l'utilisateur
///
/// Remplace le HealthScoreBadge sur les cartes de solde
/// Affiche l'icône du rang, le level et les XP — design sobre
class RankBadgeWidget extends StatelessWidget {
  final int xp;
  final double size;

  const RankBadgeWidget({super.key, required this.xp, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final rank = RankDefinitions.getRankForXP(xp);

    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rank.icon,
            color: Colors.white.withOpacity(0.9),
            size: size * 0.38,
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lv.${rank.level}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                '${_formatXP(xp)} XP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ),
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
