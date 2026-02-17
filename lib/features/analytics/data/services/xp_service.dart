import 'package:flutter/foundation.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Service de gestion des points d'expérience (XP)
///
/// Gère l'attribution des XP par action, les streaks de connexion,
/// et les limites quotidiennes pour certaines actions.
class XPService {
  final SettingsService _settings = SettingsService();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await _settings.init();
      _initialized = true;
    }
  }

  /// Attribue des XP pour une action donnée
  /// Retourne le nombre de points effectivement attribués (0 si limite atteinte)
  Future<int> awardXP(ActionType action) async {
    await _ensureInit();
    final points = ActionPoints.getPoints(action);
    if (points <= 0) return 0;

    final currentXP = await _settings.getTotalXP();
    final newXP = (currentXP + points).clamp(0, 10000);
    await _settings.setTotalXP(newXP);

    debugPrint(
      '🎯 [XP] +$points XP (${ActionPoints.getLabel(action)}) → Total: $newXP',
    );
    return points;
  }

  /// Attribue des XP personnalisés (pour le bonus santé financière)
  Future<int> awardCustomXP(int points, String reason) async {
    await _ensureInit();
    if (points <= 0) return 0;

    final currentXP = await _settings.getTotalXP();
    final newXP = (currentXP + points).clamp(0, 10000);
    await _settings.setTotalXP(newXP);

    debugPrint('🎯 [XP] +$points XP ($reason) → Total: $newXP');
    return points;
  }

  /// Vérifie et attribue le bonus de connexion quotidienne + streak
  /// Retourne le total XP gagné (login + streak bonus)
  Future<int> checkDailyLogin() async {
    await _ensureInit();
    final today = DateTime.now();
    final lastLogin = await _settings.getLastLoginDate();
    int totalAwarded = 0;

    // Vérifier si déjà connecté aujourd'hui
    if (lastLogin != null && _isSameDay(lastLogin, today)) {
      return 0; // Déjà connecté aujourd'hui
    }

    // XP de connexion quotidienne
    totalAwarded += await awardXP(ActionType.dailyLogin);

    // Gestion du streak
    int streak = await _settings.getDailyStreak();
    if (lastLogin != null && _isYesterday(lastLogin, today)) {
      streak++;
    } else if (lastLogin == null || !_isSameDay(lastLogin, today)) {
      streak = 1; // Reset si plus d'un jour d'absence
    }

    await _settings.setDailyStreak(streak);
    await _settings.setLastLoginDate(today);

    // Bonus streak
    if (streak == 7) {
      totalAwarded += await awardXP(ActionType.streak7Days);
    } else if (streak == 30) {
      totalAwarded += await awardXP(ActionType.streak30Days);
    }

    debugPrint('🔥 [XP] Streak: $streak jours');
    return totalAwarded;
  }

  /// Récupère le total XP actuel
  Future<int> getTotalXP() async {
    await _ensureInit();
    return _settings.getTotalXP();
  }

  /// Récupère le streak actuel
  Future<int> getStreak() async {
    await _ensureInit();
    return _settings.getDailyStreak();
  }

  /// Récupère le rang actuel basé sur les XP
  Future<RankInfo> getCurrentRank() async {
    final xp = await getTotalXP();
    return RankDefinitions.getRankForXP(xp);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime last, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    return _isSameDay(last, yesterday);
  }
}
