import 'package:flutter/material.dart';

/// Badge compact pour afficher le score de santé financière
/// Utilisé sur les cartes de solde de la HomeScreen
class HealthScoreBadge extends StatelessWidget {
  final int score;
  final double size;

  const HealthScoreBadge({super.key, required this.score, this.size = 44});

  @override
  Widget build(BuildContext context) {
    // Couleur progressive du rouge (0) au vert (100)
    Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF22C55E); // Vert vif
    } else if (score >= 60) {
      scoreColor = const Color(0xFF84CC16); // Vert-lime
    } else if (score >= 40) {
      scoreColor = const Color(0xFFFBBF24); // Jaune-orange
    } else if (score >= 20) {
      scoreColor = const Color(0xFFF97316); // Orange
    } else {
      scoreColor = const Color(0xFFEF4444); // Rouge
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: scoreColor.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: size - 8,
            height: size - 8,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 3,
              backgroundColor: Colors.white.withOpacity(0.1),
              color: scoreColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Score text
          Text(
            '$score',
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
