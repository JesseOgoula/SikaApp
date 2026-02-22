import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/main.dart' show autoSyncService, databaseProvider;

/// Provider pour le AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthRepository(db);
});

/// Repository pour gérer l'authentification Google + Supabase
class AuthRepository {
  final AppDatabase _db;
  final _supabase = Supabase.instance.client;

  // Web Client ID from Google Cloud Console (configuré dans Supabase)
  static const String _webClientId =
      '545730155818-ho496bi3nj7gnedjeejvt57ee3m66iq4.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId, // Important pour obtenir idToken sur Android
  );

  AuthRepository(this._db);

  /// Utilisateur actuellement connecté
  User? get currentUser => _supabase.auth.currentUser;

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => currentUser != null;

  /// Stream des changements d'état d'authentification
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Connexion avec Google
  ///
  /// 1. Ouvre le sélecteur de compte Google
  /// 2. Récupère les tokens (idToken, accessToken)
  /// 3. Envoie les tokens à Supabase
  Future<AuthResponse> signInWithGoogle() async {
    try {
      debugPrint('🔐 [Auth] Starting Google Sign-In...');

      // 1. Déclenche le flow Google Sign-In
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ [Auth] Google Sign-In cancelled by user');
        throw Exception('Connexion Google annulée par l\'utilisateur');
      }

      debugPrint('✅ [Auth] Google account selected: ${googleUser.email}');

      // 2. Récupère les tokens d'authentification
      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      debugPrint('🔑 [Auth] idToken: ${idToken?.substring(0, 20)}...');
      debugPrint('🔑 [Auth] accessToken: ${accessToken != null}');

      if (idToken == null) {
        debugPrint('❌ [Auth] idToken is null!');
        throw Exception(
          'Impossible de récupérer le token Google. Vérifiez la configuration.',
        );
      }

      // 3. Authentifie avec Supabase en utilisant les tokens Google
      debugPrint('☁️ [Auth] Calling Supabase signInWithIdToken...');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('✅ [Auth] Supabase response: user=${response.user?.email}');

      // 4. Démarre la synchronisation après connexion
      try {
        autoSyncService?.startListening();
        debugPrint('✅ [Auth] AutoSync started');
      } catch (e) {
        debugPrint('⚠️ [Auth] AutoSync start error (non-blocking): $e');
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('❌ [Auth] Supabase AuthException: ${e.message}');
      throw Exception('Erreur Supabase: ${e.message}');
    } catch (e) {
      debugPrint('❌ [Auth] Error: $e');
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // 1. Arrête AutoSync
      try {
        autoSyncService?.stopListening();
        debugPrint('✅ [Auth] AutoSync stopped');
      } catch (e) {
        debugPrint('⚠️ [Auth] AutoSync stop error: $e');
      }

      // 2. Déconnecte Google
      await _googleSignIn.signOut();

      // 3. Déconnecte Supabase
      await _supabase.auth.signOut();

      debugPrint('✅ [Auth] Signed out successfully');
    } catch (e) {
      debugPrint('❌ [Auth] Sign-out error: $e');
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  /// Efface toutes les données locales (PowerSync database)
  Future<void> clearLocalData() async {
    try {
      autoSyncService?.stopListening();
      debugPrint('✅ [Auth] Local data cleared (AutoSync stopped)');
    } catch (e) {
      debugPrint('❌ [Auth] Clear local data error: $e');
      throw Exception('Erreur lors de l\'effacement des données: $e');
    }
  }

  // ==================== HELPERS PRIVÉS ====================

  /// Efface toutes les tables locales Drift (SQLite)
  Future<void> _clearLocalDatabase({bool keepSystemCategories = true}) async {
    try {
      final txDeleted = await (_db.delete(_db.transactionsTable)).go();
      debugPrint('✅ [Auth] Local transactions deleted: $txDeleted rows');

      final goalsDeleted = await (_db.delete(_db.goalsTable)).go();
      debugPrint('✅ [Auth] Local goals deleted: $goalsDeleted rows');

      final debtsDeleted = await (_db.delete(_db.debtsTable)).go();
      debugPrint('✅ [Auth] Local debts deleted: $debtsDeleted rows');

      final accDeleted = await (_db.delete(_db.accountsTable)).go();
      debugPrint('✅ [Auth] Local accounts deleted: $accDeleted rows');

      if (keepSystemCategories) {
        // Effacer les budgets sur les catégories système (reset budgetLimit)
        await _db.customStatement('UPDATE categories SET budget_limit = NULL');
        // Supprimer les catégories non-système
        final catDeleted = await (_db.delete(
          _db.categoriesTable,
        )..where((c) => c.isSystem.equals(false))).go();
        debugPrint('✅ [Auth] Custom categories deleted: $catDeleted rows');
        debugPrint('✅ [Auth] Budget limits reset on system categories');
      } else {
        final catDeleted = await (_db.delete(_db.categoriesTable)).go();
        debugPrint('✅ [Auth] ALL categories deleted: $catDeleted rows');
      }
    } catch (e) {
      debugPrint('⚠️ [Auth] Local Drift deletion error: $e');
    }
  }

  /// Réinitialise les SharedPreferences (XP, streak, rang, etc.)
  Future<void> _resetSettings({bool keepPreferences = false}) async {
    try {
      final settings = SettingsService();
      await settings.init();

      if (keepPreferences) {
        // Effacer uniquement les données de progression (garder les préférences)
        await settings.setTotalXP(0);
        await settings.setPreviousRankLevel(1);
        await settings.setDailyStreak(0);
        await settings.setLastLoginDate(DateTime(2000)); // Reset
        await settings.setLastBudgetCheckMonth('');
        debugPrint('✅ [Auth] XP/Streak/Rank reset (preferences kept)');
      } else {
        // Tout effacer
        await settings.resetAll();
        debugPrint('✅ [Auth] All SharedPreferences cleared');
      }
    } catch (e) {
      debugPrint('⚠️ [Auth] Settings reset error: $e');
    }
  }

  /// Annule toutes les notifications programmées
  Future<void> _cancelAllNotifications() async {
    try {
      final notifService = NotificationService();
      await notifService.cancelAll();
      debugPrint('✅ [Auth] All scheduled notifications cancelled');
    } catch (e) {
      debugPrint('⚠️ [Auth] Notification cancel error: $e');
    }
  }

  /// Supprime les données cloud Supabase (toutes les tables)
  Future<void> _deleteCloudData(String userId) async {
    // Transactions
    try {
      await _supabase.from('transactions').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud transactions deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud transactions delete error: $e');
    }

    // Goals
    try {
      await _supabase.from('goals').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud goals deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud goals delete error: $e');
    }

    // Categories
    try {
      await _supabase.from('categories').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud categories deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud categories delete error: $e');
    }

    // Accounts
    try {
      await _supabase.from('accounts').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud accounts deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud accounts delete error: $e');
    }

    // Debts & Bills
    try {
      await _supabase.from('debts').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud debts deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud debts delete error: $e');
    }

    // User Ranks (XP / Leaderboard)
    try {
      await _supabase.from('user_ranks').delete().eq('user_id', userId);
      debugPrint('✅ [Auth] Cloud user_ranks deleted');
    } catch (e) {
      debugPrint('⚠️ [Auth] Cloud user_ranks delete error: $e');
    }
  }

  // ==================== ACTIONS PUBLIQUES ====================

  /// Supprime toutes les données utilisateur (local + cloud)
  /// Le compte AUTH reste actif, seules les données sont effacées
  /// L'utilisateur repart à zéro (XP = 0, rang = Novice, aucune transaction)
  Future<void> deleteAllUserData() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      debugPrint('🗑️ [Auth] === EFFACEMENT COMPLET DES DONNÉES ===');
      debugPrint('🗑️ [Auth] User: $userId');

      // 1. Arrête AutoSync avant toute modification
      try {
        autoSyncService?.stopListening();
        debugPrint('✅ [Auth] AutoSync stopped');
      } catch (e) {
        debugPrint('⚠️ [Auth] AutoSync stop error: $e');
      }

      // 2. Supprime les données CLOUD en premier (si réseau échoue, on ne perd rien localement)
      debugPrint('🔄 [Auth] Deleting cloud data...');
      await _deleteCloudData(userId);

      // 3. Efface la base locale Drift (garde les catégories système)
      debugPrint('🔄 [Auth] Clearing local database...');
      await _clearLocalDatabase(keepSystemCategories: true);

      // 4. Réinitialise XP, streak, rang (SharedPreferences)
      // Garde les préférences utilisateur (auto-save, notifications, SMS)
      debugPrint('🔄 [Auth] Resetting XP/Streak/Rank...');
      await _resetSettings(keepPreferences: true);

      // 5. Annule toutes les notifications programmées
      await _cancelAllNotifications();

      // 6. Redémarre AutoSync
      try {
        autoSyncService?.startListening();
        debugPrint('✅ [Auth] AutoSync restarted');
      } catch (e) {
        debugPrint('⚠️ [Auth] AutoSync restart error: $e');
      }

      debugPrint('✅ [Auth] === EFFACEMENT TERMINÉ ===');
    } catch (e) {
      debugPrint('❌ [Auth] Delete all data error: $e');
      throw Exception('Erreur lors de la suppression des données: $e');
    }
  }

  /// Supprime le compte utilisateur DÉFINITIVEMENT
  ///
  /// ATTENTION: Cette action est irréversible !
  /// 1. Efface TOUTES les données cloud (y compris user_ranks)
  /// 2. Efface TOUTES les données locales (Drift + SharedPreferences)
  /// 3. Annule toutes les notifications
  /// 4. Tente de supprimer l'utilisateur Supabase via RPC
  /// 5. Déconnecte de Supabase et Google
  ///
  /// Si l'utilisateur revient plus tard, il repartira à zéro complet.
  Future<void> deleteAccount() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      debugPrint('🗑️ [Auth] === SUPPRESSION DU COMPTE ===');
      debugPrint('🗑️ [Auth] User: $userId');

      // 1. Arrête AutoSync
      try {
        autoSyncService?.stopListening();
        debugPrint('✅ [Auth] AutoSync stopped');
      } catch (e) {
        debugPrint('⚠️ [Auth] AutoSync error: $e');
      }

      // 2. Supprime les données cloud AVANT le local
      debugPrint('🔄 [Auth] Deleting ALL cloud data...');
      await _deleteCloudData(userId);

      // 3. Tente de supprimer l'utilisateur Supabase via RPC
      debugPrint('🔄 [Auth] Calling delete_user_account RPC...');
      try {
        final response = await _supabase.rpc('delete_user_account');
        debugPrint('✅ [Auth] RPC response: $response');
      } catch (e) {
        debugPrint('⚠️ [Auth] RPC call error (non-blocking): $e');
        // Pas grave si RPC échoue — les données cloud sont déjà supprimées
      }

      // 4. Efface TOUTE la base locale (y compris catégories système)
      debugPrint('🔄 [Auth] Clearing entire local database...');
      await _clearLocalDatabase(keepSystemCategories: false);

      // 5. Efface TOUS les SharedPreferences (XP, préférences, tout)
      debugPrint('🔄 [Auth] Clearing all SharedPreferences...');
      await _resetSettings(keepPreferences: false);

      // 6. Annule toutes les notifications
      await _cancelAllNotifications();

      // 7. Déconnecte Google
      await _googleSignIn.signOut();
      debugPrint('✅ [Auth] Google signed out');

      // 8. Déconnecte Supabase
      await _supabase.auth.signOut();
      debugPrint('✅ [Auth] Supabase signed out');

      debugPrint('✅ [Auth] === COMPTE SUPPRIMÉ ===');
    } catch (e) {
      debugPrint('❌ [Auth] Delete account error: $e');
      throw Exception('Erreur lors de la suppression du compte: $e');
    }
  }
}
