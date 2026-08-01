import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sika_app/core/utils/logger.dart';

import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Service de gestion des rangs et du classement
///
/// - Calcule le rang à partir des XP totaux
/// - Synchronise le rang vers Supabase
/// - Fournit un stream temps réel du classement
class RankService {
  final SupabaseClient _supabase;

  RankService() : _supabase = Supabase.instance.client;

  /// Synchronise les XP et rang de l'utilisateur vers Supabase
  Future<void> syncRank({
    required int totalXP,
    required String displayName,
    String? avatarUrl,
    int? healthScore,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      SikaLogger.warn('[RANK_SYNC] No user, skipping', tag: 'RANK_SERVICE');
      return;
    }

    final rank = RankDefinitions.getRankForXP(totalXP);

    try {
      final safeHealthScore = (healthScore ?? 0).clamp(0, 100);
      await _supabase.from('user_ranks').upsert({
        'user_id': user.id,
        'total_xp': totalXP,
        'health_score': safeHealthScore,
        'rank_level': rank.level,
        'rank_name': rank.name,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      SikaLogger.error('[RANK_SYNC] Upsert FAILED: $e', tag: 'RANK_SERVICE');
    }
  }

  /// Récupère le classement (top 50) trié par XP décroissant
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    try {
      final data = await _supabase
          .from('user_ranks')
          .select()
          .order('total_xp', ascending: false)
          .limit(50);

      return (data as List<dynamic>)
          .asMap()
          .entries
          .map(
            (entry) => LeaderboardEntry.fromMap(
              entry.value as Map<String, dynamic>,
              entry.key + 1,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream temps réel du classement via Supabase Realtime
  Stream<List<LeaderboardEntry>> watchLeaderboard() {
    return _supabase
        .from('user_ranks')
        .stream(primaryKey: ['user_id'])
        .order('total_xp', ascending: false)
        .map(
          (data) => data
              .asMap()
              .entries
              .map(
                (entry) => LeaderboardEntry.fromMap(entry.value, entry.key + 1),
              )
              .toList(),
        );
  }

  /// Récupère le rang de l'utilisateur courant depuis Supabase
  Future<LeaderboardEntry?> getCurrentUserRank() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase
          .from('user_ranks')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data == null) return null;

      final allRanks = await getLeaderboard();
      final position = allRanks.indexWhere((e) => e.userId == user.id) + 1;

      return LeaderboardEntry.fromMap(data, position > 0 ? position : 999);
    } catch (e) {
      return null;
    }
  }
}
