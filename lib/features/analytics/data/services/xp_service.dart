import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';
import 'package:sika_app/features/analytics/data/services/rank_service.dart';

/// Service de gestion des points d'expérience (XP)
///
/// Gère l'attribution des XP par action, les streaks de connexion,
/// et la synchronisation automatique vers Supabase.
class XPService {
  final SettingsService _settings = SettingsService();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (!_initialized) {
      await _settings.init();
      _initialized = true;
    }
  }

  /// Synchronise les XP vers Supabase
  Future<void> _syncToCloud(int totalXP) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await _ensureInit();
      final healthScore = await _settings.getHealthScore();

      final metadata = user.userMetadata ?? {};
      final displayName =
          (metadata['full_name'] ?? metadata['name'] ?? 'Utilisateur')
              as String;
      final avatarUrl = metadata['avatar_url'] as String?;

      await RankService().syncRank(
        totalXP: totalXP,
        displayName: displayName,
        avatarUrl: avatarUrl,
        healthScore: healthScore,
      );
    } catch (e) {
      print('[XP_SYNC] Sync FAILED: $e');
    }
  }

  /// Attribue des XP pour une action donnee
  /// Retourne le nombre de points effectivement attribues
  Future<int> awardXP(ActionType action) async {
    await _ensureInit();
    final points = ActionPoints.getPoints(action);
    if (points <= 0) return 0;

    final currentXP = await _settings.getTotalXP();
    final newXP = (currentXP + points).clamp(0, 10000);
    await _settings.setTotalXP(newXP);

    // Sync vers Supabase (await pour garantir la coherence)
    await _syncToCloud(newXP);

    return points;
  }

  /// Attribue des XP personnalises (pour le bonus sante financiere)
  Future<int> awardCustomXP(int points, String reason) async {
    await _ensureInit();
    if (points <= 0) return 0;

    final currentXP = await _settings.getTotalXP();
    final newXP = (currentXP + points).clamp(0, 10000);
    await _settings.setTotalXP(newXP);

    // Sync vers Supabase (await pour garantir la coherence)
    await _syncToCloud(newXP);

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
