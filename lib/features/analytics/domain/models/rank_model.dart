import 'package:flutter/material.dart';

/// Types d'actions qui rapportent des XP
enum ActionType {
  addTransaction, // +5 XP
  dailyLogin, // +3 XP
  streak7Days, // +20 XP bonus
  streak30Days, // +100 XP bonus
  createGoal, // +10 XP
  feedGoal, // +15 XP
  reachGoal, // +50 XP
  createBudget, // +10 XP
  respectBudget, // +25 XP
  addDebt, // +5 XP
  payDebt, // +20 XP
  addAccount, // +15 XP
  healthScoreBonus, // score/10 XP (max 10)
  validateAutoDetection, // +15 XP
  makeTransfer, // +10 XP
}

/// Points attribués par action
class ActionPoints {
  static const Map<ActionType, int> values = {
    ActionType.addTransaction: 5,
    ActionType.dailyLogin: 3,
    ActionType.streak7Days: 20,
    ActionType.streak30Days: 100,
    ActionType.createGoal: 10,
    ActionType.feedGoal: 15,
    ActionType.reachGoal: 50,
    ActionType.createBudget: 10,
    ActionType.respectBudget: 25,
    ActionType.addDebt: 5,
    ActionType.payDebt: 20,
    ActionType.addAccount: 15,
    ActionType.healthScoreBonus: 10, // max per day
    ActionType.validateAutoDetection: 15,
    ActionType.makeTransfer: 10,
  };

  static int getPoints(ActionType action) => values[action] ?? 0;

  /// Label lisible pour chaque action
  static String getLabel(ActionType action) {
    switch (action) {
      case ActionType.addTransaction:
        return 'Transaction ajoutée';
      case ActionType.dailyLogin:
        return 'Connexion quotidienne';
      case ActionType.streak7Days:
        return 'Streak 7 jours !';
      case ActionType.streak30Days:
        return 'Streak 30 jours !';
      case ActionType.createGoal:
        return 'Objectif créé';
      case ActionType.feedGoal:
        return 'Objectif alimenté';
      case ActionType.reachGoal:
        return 'Objectif atteint !';
      case ActionType.createBudget:
        return 'Budget créé';
      case ActionType.respectBudget:
        return 'Budget respecté';
      case ActionType.addDebt:
        return 'Engagement ajouté';
      case ActionType.payDebt:
        return 'Engagement réglé';
      case ActionType.addAccount:
        return 'Compte ajouté';
      case ActionType.healthScoreBonus:
        return 'Bonus santé financière';
      case ActionType.validateAutoDetection:
        return 'Détection auto. validée';
      case ActionType.makeTransfer:
        return 'Transfert effectué';
    }
  }
}

/// Définition d'un rang basé sur les XP accumulés
class RankInfo {
  final int level;
  final String name;
  final int minXP;
  final int maxXP;
  final IconData icon;
  final String cardLabel;
  final List<Color> cardGradient;
  const RankInfo({
    required this.level,
    required this.name,
    required this.minXP,
    required this.maxXP,
    required this.icon,
    required this.cardLabel,
    required this.cardGradient,
  });

  /// Couleur du rang (toujours sobre, basée sur le thème)
  Color get color {
    switch (level) {
      case 1:
        return const Color(0xFF6B7280); // Gris
      case 2:
        return const Color(0xFF94A3B8); // Silver
      case 3:
        return const Color(0xFF1A237E); // Bleu Nuit
      case 4:
        return const Color(0xFF311B92); // Violet profond
      case 5:
        return const Color(0xFF0D0D15); // Noir premium
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Progression dans le rang actuel (0.0 → 1.0)
  double progressInRank(int xp) {
    final range = maxXP - minXP;
    if (range <= 0) return 1.0;
    return ((xp - minXP) / range).clamp(0.0, 1.0);
  }

  /// XP restants pour le prochain rang
  int xpToNextRank(int xp) {
    if (level >= 5) return 0;
    return maxXP - xp + 1;
  }
}

/// Type de transition de rang
enum RankTransitionType { levelUp, levelDown }

/// Résultat d'une détection de changement de rang
class RankTransition {
  final RankTransitionType type;
  final RankInfo oldRank;
  final RankInfo newRank;

  const RankTransition({
    required this.type,
    required this.oldRank,
    required this.newRank,
  });
}

/// Entrée du classement (leaderboard)
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int totalXP;
  final int rankLevel;
  final String rankName;
  final int position;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.totalXP,
    required this.rankLevel,
    required this.rankName,
    required this.position,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, int position) {
    return LeaderboardEntry(
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String? ?? 'Utilisateur',
      avatarUrl: map['avatar_url'] as String?,
      totalXP: (map['total_xp'] as num?)?.toInt() ?? 0,
      rankLevel: (map['rank_level'] as num?)?.toInt() ?? 1,
      rankName: map['rank_name'] as String? ?? 'Novice',
      position: position,
    );
  }
}

/// Définitions statiques de tous les rangs (seuils 0/2500/5000/7500/10000)
class RankDefinitions {
  static const List<RankInfo> all = [
    RankInfo(
      level: 1,
      name: 'Novice',
      minXP: 0,
      maxXP: 2499,
      icon: Icons.shield_outlined,
      cardLabel: 'STANDARD',
      cardGradient: [Color(0xFF6B7280), Color(0xFF374151)],
    ),
    RankInfo(
      level: 2,
      name: 'Apprenti Économe',
      minXP: 2500,
      maxXP: 4999,
      icon: Icons.trending_up,
      cardLabel: 'SILVER',
      cardGradient: [Color(0xFF94A3B8), Color(0xFF64748B)],
    ),
    RankInfo(
      level: 3,
      name: 'Gestionnaire',
      minXP: 5000,
      maxXP: 7499,
      icon: Icons.stars,
      cardLabel: 'GOLD',
      cardGradient: [Color(0xFF1A237E), Color(0xFF311B92)],
    ),
    RankInfo(
      level: 4,
      name: 'Stratège',
      minXP: 7500,
      maxXP: 9999,
      icon: Icons.military_tech,
      cardLabel: 'PLATINUM',
      cardGradient: [Color(0xFF311B92), Color(0xFF1A1A2E)],
    ),
    RankInfo(
      level: 5,
      name: 'Sika Boss',
      minXP: 10000,
      maxXP: 999999,
      icon: Icons.diamond,
      cardLabel: 'BLACK',
      cardGradient: [Color(0xFF1A1A2E), Color(0xFF0D0D15)],
    ),
  ];

  /// Retourne le rang correspondant à un total XP
  static RankInfo getRankForXP(int xp) {
    for (final rank in all.reversed) {
      if (xp >= rank.minXP) return rank;
    }
    return all.first;
  }

  /// Retourne le rang suivant (null si déjà au max)
  static RankInfo? getNextRank(RankInfo current) {
    if (current.level >= 5) return null;
    return all[current.level];
  }

  /// Détecte une transition de rang entre deux totaux XP
  static RankTransition? detectTransition(int oldXP, int newXP) {
    final oldRank = getRankForXP(oldXP);
    final newRank = getRankForXP(newXP);
    if (oldRank.level == newRank.level) return null;
    return RankTransition(
      type: newRank.level > oldRank.level
          ? RankTransitionType.levelUp
          : RankTransitionType.levelDown,
      oldRank: oldRank,
      newRank: newRank,
    );
  }
}
