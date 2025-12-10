import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/supabase_connector.dart';
import 'package:sika_app/main.dart' show powerSyncDatabase;

/// Provider pour le AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Repository pour gérer l'authentification Google + Supabase
class AuthRepository {
  final _supabase = Supabase.instance.client;

  // Web Client ID from Google Cloud Console (configuré dans Supabase)
  static const String _webClientId =
      '545730155818-ho496bi3nj7gnedjeejvt57ee3m66iq4.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId, // Important pour obtenir idToken sur Android
  );

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
}
