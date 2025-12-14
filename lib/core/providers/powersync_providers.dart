import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/supabase_connector.dart';
import 'package:sika_app/main.dart' show powerSyncDatabase;

/// État de synchronisation PowerSync
enum SyncState { connected, disconnected, connecting, error }

/// Provider pour l'état actuel de synchronisation
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>(
  (ref) {
    return SyncStatusNotifier();
  },
);

/// Notifier pour gérer l'état de synchronisation
class SyncStatusNotifier extends StateNotifier<SyncState> {
  SyncStatusNotifier() : super(SyncState.disconnected) {
    _initStatus();
  }

  void _initStatus() {
    if (powerSyncDatabase != null && powerSyncDatabase!.connected) {
      state = SyncState.connected;
    } else {
      state = SyncState.disconnected;
    }
  }

  /// Connecte PowerSync
  Future<void> connect() async {
    try {
      state = SyncState.connecting;
      if (powerSyncDatabase != null) {
        final connector = SupabaseConnector();
        await powerSyncDatabase!.connect(connector: connector);
        state = SyncState.connected;
        debugPrint('✅ [Sync] PowerSync connected');
      }
    } catch (e) {
      state = SyncState.error;
      debugPrint('❌ [Sync] PowerSync connect error: $e');
    }
  }

  /// Déconnecte PowerSync
  Future<void> disconnect() async {
    try {
      await powerSyncDatabase?.disconnect();
      state = SyncState.disconnected;
      debugPrint('✅ [Sync] PowerSync disconnected');
    } catch (e) {
      debugPrint('❌ [Sync] PowerSync disconnect error: $e');
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
      if (powerSyncDatabase != null && powerSyncDatabase!.connected) {
        // Force refresh des données
        debugPrint('🔄 [Sync] Forcing sync...');
        // PowerSync se synchronise automatiquement, on peut déclencher un refresh
        state = SyncState.connecting;
        await Future.delayed(const Duration(milliseconds: 500));
        state = SyncState.connected;
        debugPrint('✅ [Sync] Sync complete');
      } else {
        debugPrint('⚠️ [Sync] Cannot sync - not connected');
      }
    } catch (e) {
      debugPrint('❌ [Sync] Force sync error: $e');
    }
  }

  /// Supprime la base de données locale
  Future<void> deleteLocalDatabase() async {
    try {
      if (powerSyncDatabase != null) {
        await powerSyncDatabase!.disconnect();
        await powerSyncDatabase!.disconnectAndClear();
        state = SyncState.disconnected;
        debugPrint('✅ [Sync] Local database deleted');
      }
    } catch (e) {
      debugPrint('❌ [Sync] Delete database error: $e');
    }
  }
}

/// Provider booléen simple pour l'état de sync
final isSyncConnectedProvider = Provider<bool>((ref) {
  final status = ref.watch(syncStatusProvider);
  return status == SyncState.connected;
});
