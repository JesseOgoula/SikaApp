import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/data/providers/rank_providers.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Écran de classement en temps réel
///
/// Affiche le top 50 des utilisateurs SIKA triés par XP.
/// Utilise Supabase Realtime pour les mises à jour instantanées.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardStreamProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: leaderboardAsync.when(
                data: (entries) => entries.isEmpty
                    ? _buildEmptyState()
                    : _buildLeaderboard(entries, currentUserId),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.cloud_off,
                        color: AppTheme.textSecondary,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Impossible de charger le classement',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Classement',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: AppTheme.success, size: 8),
                const SizedBox(width: 6),
                const Text(
                  'Temps réel',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            color: AppTheme.textSecondary,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun classement pour le moment',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Sois le premier Sika Boss !',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(
    List<LeaderboardEntry> entries,
    String? currentUserId,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (entries.length >= 3)
          _buildPodium(entries.take(3).toList(), currentUserId),
        if (entries.length >= 3) const SizedBox(height: 20),
        ...entries
            .skip(entries.length >= 3 ? 3 : 0)
            .map((entry) => _buildRankTile(entry, currentUserId)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3, String? currentUserId) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const Text(
            '🏆 Top 3',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (top3.length > 1) _buildPodiumSlot(top3[1], currentUserId, 2),
              _buildPodiumSlot(top3[0], currentUserId, 1),
              if (top3.length > 2) _buildPodiumSlot(top3[2], currentUserId, 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSlot(
    LeaderboardEntry entry,
    String? currentUserId,
    int position,
  ) {
    final isMe = entry.userId == currentUserId;
    final rank = RankDefinitions.getRankForXP(entry.totalXP);

    final medalColors = {
      1: const Color(0xFFD4A017),
      2: const Color(0xFF94A3B8),
      3: const Color(0xFF8B6914),
    };
    final medalColor = medalColors[position] ?? AppTheme.textSecondary;
    final podiumHeight = position == 1 ? 70.0 : (position == 2 ? 50.0 : 40.0);
    final avatarSize = position == 1 ? 56.0 : 44.0;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe ? AppTheme.primaryColor : medalColor,
                  width: isMe ? 3 : 2,
                ),
                color: AppTheme.primaryColor.withOpacity(0.05),
              ),
              child: entry.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        entry.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          rank.icon,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(rank.icon, color: AppTheme.primaryColor, size: 24),
            ),
            Positioned(
              bottom: -4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$position',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _shortenName(entry.displayName),
          style: TextStyle(
            color: isMe ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${_formatXP(entry.totalXP)} XP',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: podiumHeight,
          decoration: BoxDecoration(
            color: medalColor.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              rank.name,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankTile(LeaderboardEntry entry, String? currentUserId) {
    final isMe = entry.userId == currentUserId;
    final rank = RankDefinitions.getRankForXP(entry.totalXP);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primaryColor.withOpacity(0.05)
            : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: AppTheme.primaryColor.withOpacity(0.15))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.position}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.06),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.15),
              ),
            ),
            child: entry.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      entry.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        rank.icon,
                        color: AppTheme.primaryColor,
                        size: 16,
                      ),
                    ),
                  )
                : Icon(rank.icon, color: AppTheme.primaryColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${entry.displayName} (Toi)' : entry.displayName,
                  style: TextStyle(
                    color: isMe ? AppTheme.primaryColor : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  'Lv.${rank.level} — ${rank.name}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_formatXP(entry.totalXP)} XP',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortenName(String name) {
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts.first} ${parts.last[0]}.';
    }
    return name;
  }

  String _formatXP(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return '$xp';
  }
}
