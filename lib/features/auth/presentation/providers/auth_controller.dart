import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/features/auth/data/repositories/auth_repository.dart';

/// État de l'authentification
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// État complet de l'authentification
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider pour le contrôleur d'authentification
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final repo = ref.watch(authRepositoryProvider);
    return AuthController(repo);
  },
);

/// Contrôleur d'authentification (StateNotifier)
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthState()) {
    _init();
  }

  /// Initialise l'état en vérifiant si l'utilisateur est déjà connecté
  void _init() {
    final currentUser = _repo.currentUser;
    if (currentUser != null) {
      state = AuthState(status: AuthStatus.authenticated, user: currentUser);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Écoute les changements d'état d'authentification
    _repo.authStateChanges.listen((authState) {
      if (authState.session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: authState.session!.user,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  /// Connexion avec Google
  Future<void> login() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _repo.signInWithGoogle();

      if (response.user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
      } else {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Connexion échouée',
        );
      }
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _repo.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  /// Mode local (sans connexion cloud)
  void skipLogin() {
    state = const AuthState(status: AuthStatus.authenticated);
  }
}
