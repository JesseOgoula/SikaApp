import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/main.dart' show autoSyncService, databaseProvider;
import 'package:sika_app/core/services/analytics_service.dart';

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
      // 1. Déclenche le flow Google Sign-In
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Connexion Google annulée par l\'utilisateur');
      }

      // 2. Récupère les tokens d'authentification
      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception(
          'Impossible de récupérer le token Google. Vérifiez la configuration.',
        );
      }

      // 3. Authentifie avec Supabase en utilisant les tokens Google
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // 4. Démarre la synchronisation après connexion
      try {
        autoSyncService?.startListening();
      } catch (e) {
        /* ignore */
      }

      // 5. Tracking PostHog : auth_completed + identify
      await AnalyticsService.logEvent('auth_completed');
      if (response.user != null) {
        await AnalyticsService.identifyUser(
          response.user!.id,
          email: response.user!.email,
        );
      }

      return response;
    } on AuthException catch (e) {
      throw Exception('Erreur Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      // 1. Arrête AutoSync
      try {
        autoSyncService?.stopListening();
      } catch (e) {
        /* ignore */
      }

      // 2. Déconnecte Google
      await _googleSignIn.signOut();

      // 3. Déconnecte Supabase
      await _supabase.auth.signOut();

      // 4. Reset analytics
      await AnalyticsService.reset();
    } catch (e) {
      throw Exception('Erreur de déconnexion: $e');
    }
  }

  /// Efface toutes les données locales (PowerSync database)
  Future<void> clearLocalData() async {
    try {
      autoSyncService?.stopListening();
    } catch (e) {
      throw Exception('Erreur lors de l\'effacement des données: $e');
    }
  }

  // ==================== HELPERS PRIVÉS ====================

  /// Efface toutes les tables locales Drift (SQLite)
  Future<void> _clearLocalDatabase({bool keepSystemCategories = true}) async {
    try {
      final txDeleted = await (_db.delete(_db.transactionsTable)).go();
      final goalsDeleted = await (_db.delete(_db.goalsTable)).go();
      final debtsDeleted = await (_db.delete(_db.debtsTable)).go();
      final accDeleted = await (_db.delete(_db.accountsTable)).go();
      if (keepSystemCategories) {
        // Effacer les budgets sur les catégories système (reset budgetLimit)
        await _db.customStatement('UPDATE categories SET budget_limit = NULL');
        // Supprimer les catégories non-système
        final catDeleted = await (_db.delete(
          _db.categoriesTable,
        )..where((c) => c.isSystem.equals(false))).go();
      } else {
        final catDeleted = await (_db.delete(_db.categoriesTable)).go();
      }
    } catch (e) {
      /* ignore */
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
      } else {
        // Tout effacer
        await settings.resetAll();
      }
    } catch (e) {
      /* ignore */
    }
  }

  /// Annule toutes les notifications programmées
  Future<void> _cancelAllNotifications() async {
    try {
      final notifService = NotificationService();
      await notifService.cancelAll();
    } catch (e) {
      /* ignore */
    }
  }

  /// Supprime les données cloud Supabase (toutes les tables)
  Future<void> _deleteCloudData(String userId) async {
    // Transactions
    try {
      await _supabase.from('transactions').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
    }

    // Goals
    try {
      await _supabase.from('goals').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
    }

    // Categories
    try {
      await _supabase.from('categories').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
    }

    // Accounts
    try {
      await _supabase.from('accounts').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
    }

    // Debts & Bills
    try {
      await _supabase.from('debts').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
    }

    // User Ranks (XP / Leaderboard)
    try {
      await _supabase.from('user_ranks').delete().eq('user_id', userId);
    } catch (e) {
      /* ignore */
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

      // 1. Arrête AutoSync avant toute modification
      try {
        autoSyncService?.stopListening();
      } catch (e) {
        /* ignore */
      }

      // 2. Supprime les données CLOUD en premier (si réseau échoue, on ne perd rien localement)
      await _deleteCloudData(userId);

      // 3. Efface la base locale Drift (garde les catégories système)
      await _clearLocalDatabase(keepSystemCategories: true);

      // 4. Réinitialise XP, streak, rang (SharedPreferences)
      // Garde les préférences utilisateur (auto-save, notifications, SMS)
      await _resetSettings(keepPreferences: true);

      // 5. Annule toutes les notifications programmées
      await _cancelAllNotifications();

      // 6. Redémarre AutoSync
      try {
        autoSyncService?.startListening();
      } catch (e) {
        /* ignore */
      }
    } catch (e) {
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

      // 1. Arrête AutoSync
      try {
        autoSyncService?.stopListening();
      } catch (e) {
        /* ignore */
      }

      // 2. Supprime les données cloud AVANT le local
      await _deleteCloudData(userId);

      // 3. Tente de supprimer l'utilisateur Supabase via RPC
      try {
        final response = await _supabase.rpc('delete_user_account');
      } catch (e) {
        // Pas grave si RPC échoue — les données cloud sont déjà supprimées
      }

      // 4. Efface TOUTE la base locale (y compris catégories système)
      await _clearLocalDatabase(keepSystemCategories: false);

      // 5. Efface TOUS les SharedPreferences (XP, préférences, tout)
      await _resetSettings(keepPreferences: false);

      // 6. Annule toutes les notifications
      await _cancelAllNotifications();

      // 7. Déconnecte Google
      await _googleSignIn.signOut();
      // 8. Déconnecte Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la suppression du compte: $e');
    }
  }
}
