import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/database/supabase_connector.dart';
import 'package:sika_app/main.dart' show powerSyncDatabase, databaseProvider;

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

      // 4. Démarre la synchronisation PowerSync après connexion
      try {
        if (powerSyncDatabase != null) {
          final connector = SupabaseConnector();
          await powerSyncDatabase!.connect(connector: connector);
          debugPrint('✅ [Auth] PowerSync connected');
        }
      } catch (e) {
        debugPrint('⚠️ [Auth] PowerSync connect error (non-blocking): $e');
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
      // 1. Déconnecte PowerSync (arrête la synchronisation)
      try {
        await powerSyncDatabase?.disconnect();
        debugPrint('✅ [Auth] PowerSync disconnected');
      } catch (e) {
        debugPrint('⚠️ [Auth] PowerSync disconnect error: $e');
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
      if (powerSyncDatabase != null) {
        // Déconnecte et efface la base locale
        await powerSyncDatabase!.disconnect();
        await powerSyncDatabase!.disconnectAndClear();
        debugPrint('✅ [Auth] Local data cleared');
      }
    } catch (e) {
      debugPrint('❌ [Auth] Clear local data error: $e');
      throw Exception('Erreur lors de l\'effacement des données: $e');
    }
  }

  /// Supprime toutes les données utilisateur (local + cloud)
  /// Le compte reste actif, seules les données sont effacées
  Future<void> deleteAllUserData() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      debugPrint('🗑️ [Auth] Deleting all user data for: $userId');

      // 1. Efface les données locales Drift (SQLite)
      try {
        // Supprimer les transactions locales
        final txDeleted = await (_db.delete(_db.transactionsTable)).go();
        debugPrint('✅ [Auth] Local transactions deleted: $txDeleted rows');

        // Supprimer les objectifs locaux
        final goalsDeleted = await (_db.delete(_db.goalsTable)).go();
        debugPrint('✅ [Auth] Local goals deleted: $goalsDeleted rows');

        // Supprimer les catégories locales (sauf système)
        final catDeleted = await (_db.delete(
          _db.categoriesTable,
        )..where((c) => c.isSystem.equals(false))).go();
        debugPrint('✅ [Auth] Local categories deleted: $catDeleted rows');

        // Supprimer les dettes et factures locales
        final debtsDeleted = await (_db.delete(_db.debtsTable)).go();
        debugPrint('✅ [Auth] Local debts deleted: $debtsDeleted rows');

        // Supprimer les comptes locaux
        final accDeleted = await (_db.delete(_db.accountsTable)).go();
        debugPrint('✅ [Auth] Local accounts deleted: $accDeleted rows');
      } catch (e) {
        debugPrint('⚠️ [Auth] Local Drift deletion error: $e');
      }

      // 2. Efface le cache PowerSync
      try {
        if (powerSyncDatabase != null) {
          await powerSyncDatabase!.disconnect();
          await powerSyncDatabase!.disconnectAndClear();
          debugPrint('✅ [Auth] PowerSync cache cleared');
        }
      } catch (e) {
        debugPrint('⚠️ [Auth] PowerSync clear error: $e');
      }

      // 3. Supprime les données cloud Supabase
      debugPrint('🔄 [Auth] Deleting cloud data...');

      // Transactions
      try {
        final txResult = await _supabase
            .from('transactions')
            .delete()
            .eq('user_id', userId)
            .select();
        debugPrint('✅ [Auth] Transactions deleted: ${txResult.length} rows');
      } catch (e) {
        debugPrint('❌ [Auth] Transactions delete error: $e');
      }

      // Goals
      try {
        final goalsResult = await _supabase
            .from('goals')
            .delete()
            .eq('user_id', userId)
            .select();
        debugPrint('✅ [Auth] Goals deleted: ${goalsResult.length} rows');
      } catch (e) {
        debugPrint('❌ [Auth] Goals delete error: $e');
      }

      // Categories
      try {
        final catResult = await _supabase
            .from('categories')
            .delete()
            .eq('user_id', userId)
            .select();
        debugPrint('✅ [Auth] Categories deleted: ${catResult.length} rows');
      } catch (e) {
        debugPrint('❌ [Auth] Categories delete error: $e');
      }

      // Accounts
      try {
        final accResult = await _supabase
            .from('accounts')
            .delete()
            .eq('user_id', userId)
            .select();
        debugPrint('✅ [Auth] Accounts deleted: ${accResult.length} rows');
      } catch (e) {
        debugPrint('⚠️ [Auth] Accounts may not exist: $e');
      }

      // Debts & Bills
      try {
        final debtsResult = await _supabase
            .from('debts')
            .delete()
            .eq('user_id', userId)
            .select();
        debugPrint('✅ [Auth] Debts deleted: ${debtsResult.length} rows');
      } catch (e) {
        debugPrint('❌ [Auth] Debts delete error: $e');
      }

      // 3. Reconnecte PowerSync pour récupérer les données vides
      try {
        if (powerSyncDatabase != null) {
          final connector = SupabaseConnector();
          await powerSyncDatabase!.connect(connector: connector);
          debugPrint('✅ [Auth] PowerSync reconnected');
        }
      } catch (e) {
        debugPrint('⚠️ [Auth] PowerSync reconnect error: $e');
      }

      debugPrint('✅ [Auth] All user data deleted successfully');
    } catch (e) {
      debugPrint('❌ [Auth] Delete all data error: $e');
      throw Exception('Erreur lors de la suppression des données: $e');
    }
  }

  /// Supprime le compte utilisateur DÉFINITIVEMENT
  ///
  /// ATTENTION: Cette action est irréversible !
  /// 1. Efface toutes les données locales (Drift)
  /// 2. Efface toutes les données cloud (Supabase)
  /// 3. Déconnecte de Supabase et Google
  Future<void> deleteAccount() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      debugPrint('🗑️ [Auth] Starting ACCOUNT deletion for: $userId');

      // 1. Efface les données locales Drift (SQLite)
      try {
        // Supprimer les transactions locales
        final txDeleted = await (_db.delete(_db.transactionsTable)).go();
        debugPrint('✅ [Auth] Local transactions deleted: $txDeleted rows');

        // Supprimer les objectifs locaux
        final goalsDeleted = await (_db.delete(_db.goalsTable)).go();
        debugPrint('✅ [Auth] Local goals deleted: $goalsDeleted rows');

        // Supprimer TOUTES les catégories locales
        final catDeleted = await (_db.delete(_db.categoriesTable)).go();
        debugPrint('✅ [Auth] Local categories deleted: $catDeleted rows');

        // Supprimer les comptes locaux
        final accDeleted = await (_db.delete(_db.accountsTable)).go();
        debugPrint('✅ [Auth] Local accounts deleted: $accDeleted rows');

        // Supprimer les dettes locales
        final debtsDeleted = await (_db.delete(_db.debtsTable)).go();
        debugPrint('✅ [Auth] Local debts deleted: $debtsDeleted rows');
      } catch (e) {
        debugPrint('⚠️ [Auth] Local Drift deletion error: $e');
      }

      // 2. Efface le cache PowerSync
      try {
        if (powerSyncDatabase != null) {
          await powerSyncDatabase!.disconnect();
          await powerSyncDatabase!.disconnectAndClear();
        }
        debugPrint('✅ [Auth] PowerSync cleared');
      } catch (e) {
        debugPrint('⚠️ [Auth] PowerSync error: $e');
      }

      // 3. Appelle la fonction RPC pour supprimer l'utilisateur Supabase (données + auth)
      debugPrint('🔄 [Auth] Calling delete_user_account RPC...');
      try {
        final response = await _supabase.rpc('delete_user_account');
        debugPrint('✅ [Auth] RPC response: $response');

        if (response != null && response['success'] == true) {
          debugPrint('✅ [Auth] Supabase user + data deleted via RPC');
        } else {
          debugPrint('⚠️ [Auth] RPC returned: $response');
          // Fallback - suppression manuelle des données cloud
          await _deleteCloudDataManually(userId);
        }
      } catch (e) {
        debugPrint('⚠️ [Auth] RPC call error: $e');
        // Fallback - Si la fonction RPC n'existe pas, suppression manuelle
        await _deleteCloudDataManually(userId);
      }

      // 4. Déconnecte Google
      await _googleSignIn.signOut();
      debugPrint('✅ [Auth] Google signed out');

      // 5. Déconnecte Supabase
      await _supabase.auth.signOut();
      debugPrint('✅ [Auth] Supabase signed out');

      debugPrint('✅ [Auth] Account deletion complete');
    } catch (e) {
      debugPrint('❌ [Auth] Delete account error: $e');
      throw Exception('Erreur lors de la suppression du compte: $e');
    }
  }

  /// Helper: Supprime les données cloud manuellement (fallback si RPC échoue)
  Future<void> _deleteCloudDataManually(String userId) async {
    try {
      await _supabase.from('transactions').delete().eq('user_id', userId);
      await _supabase.from('goals').delete().eq('user_id', userId);
      await _supabase.from('categories').delete().eq('user_id', userId);
      try {
        await _supabase.from('accounts').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _supabase.from('debts').delete().eq('user_id', userId);
      } catch (_) {}
      debugPrint('✅ [Auth] Cloud data deleted manually (fallback)');
    } catch (e) {
      debugPrint('⚠️ [Auth] Manual cloud deletion error: $e');
    }
  }
}
