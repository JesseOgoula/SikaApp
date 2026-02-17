import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/analytics/data/services/rank_service.dart';
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Provider singleton du RankService
final rankServiceProvider = Provider<RankService>((ref) {
  return RankService();
});

/// Provider singleton du XPService
final xpServiceProvider = Provider<XPService>((ref) {
  return XPService();
});

/// Provider du rang actuel basé sur les XP totaux
final rankForXPProvider = Provider.family<RankInfo, int>((ref, xp) {
  return RankDefinitions.getRankForXP(xp);
});

/// Provider du classement temps réel
final leaderboardStreamProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  final service = ref.watch(rankServiceProvider);
  return service.watchLeaderboard();
});

/// Provider du classement (fetch unique, pas stream)
final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final service = ref.watch(rankServiceProvider);
  return service.getLeaderboard();
});

/// Provider du rang de l'utilisateur courant sur le leaderboard
final currentUserLeaderboardProvider = FutureProvider<LeaderboardEntry?>((
  ref,
) async {
  final service = ref.watch(rankServiceProvider);
  return service.getCurrentUserRank();
});
