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
      height: size * 0.6, // Hauteur réduite pour la pastille
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: rank.color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        'Lv.${rank.level} - ${rank.name}',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w700,
        ),
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
