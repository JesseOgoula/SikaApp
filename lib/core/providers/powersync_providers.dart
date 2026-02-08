import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:sika_app/main.dart' show autoSyncService;

/// État de synchronisation
enum SyncState { connected, disconnected, connecting, error }

/// Provider pour l'état actuel de synchronisation
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>(
  (ref) {
    return SyncStatusNotifier();
  },
);

/// Notifier pour gérer l'état de synchronisation
///
/// Utilise AutoSyncService au lieu de PowerSync
class SyncStatusNotifier extends StateNotifier<SyncState> {
  SyncStatusNotifier() : super(SyncState.disconnected) {
    _initStatus();
  }

  Future<void> _initStatus() async {
    // Vérifie la connectivité actuelle
    final results = await Connectivity().checkConnectivity();
    final hasInternet = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    if (hasInternet) {
      state = SyncState.connected;
    } else {
      state = SyncState.disconnected;
    }
  }

  /// Active la synchronisation (démarre AutoSyncService)
  Future<void> connect() async {
    try {
      state = SyncState.connecting;
      autoSyncService?.startListening();
      state = SyncState.connected;
      debugPrint('✅ [Sync] AutoSync connected');
    } catch (e) {
      state = SyncState.error;
      debugPrint('❌ [Sync] AutoSync connect error: $e');
    }
  }

  /// Désactive la synchronisation
  Future<void> disconnect() async {
    try {
      autoSyncService?.stopListening();
      state = SyncState.disconnected;
      debugPrint('✅ [Sync] AutoSync disconnected');
    } catch (e) {
      debugPrint('❌ [Sync] AutoSync disconnect error: $e');
    }
  }

  /// Bascule l'état de synchronisation
  Future<void> toggle() async {
    if (state == SyncState.connected) {
      await disconnect();
    } else {
      await connect();
    }
  }

  /// Force une synchronisation
  Future<void> forceSync() async {
    try {
      debugPrint('🔄 [Sync] Forcing sync...');
      state = SyncState.connecting;
      await autoSyncService?.forceSync();
      state = SyncState.connected;
      debugPrint('✅ [Sync] Sync complete');
    } catch (e) {
      debugPrint('❌ [Sync] Force sync error: $e');
    }
  }

  /// Supprime la base de données locale (non supporté sans PowerSync)
  Future<void> deleteLocalDatabase() async {
    debugPrint('⚠️ [Sync] deleteLocalDatabase not supported with AutoSync');
    // Peut être implémenté plus tard si nécessaire
  }
}

/// Provider booléen simple pour l'état de sync
final isSyncConnectedProvider = Provider<bool>((ref) {
  final status = ref.watch(syncStatusProvider);
  return status == SyncState.connected;
});
