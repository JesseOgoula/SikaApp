import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Constantes PowerSync
class PowerSyncConfig {
  /// URL de l'instance PowerSync (depuis le dashboard PowerSync)
  static const String powersyncUrl =
      'https://6939410a48645822f3667b20.powersync.journeyapps.com';
}

/// Connector PowerSync <-> Supabase
///
/// Gère l'authentification et la synchronisation entre PowerSync et Supabase.
/// Utilise le JWT de Supabase pour s'authentifier auprès de PowerSync.
class SupabaseConnector extends PowerSyncBackendConnector {
  final SupabaseClient _supabase;

  SupabaseConnector() : _supabase = Supabase.instance.client;

  /// Récupère les credentials pour PowerSync
  ///
  /// Utilise le token JWT de la session Supabase active.
  /// Retourne null si l'utilisateur n'est pas connecté (PowerSync se met en pause).
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session == null) {
        debugPrint('⚠️ [PowerSync] No active session - sync paused');
        return null;
      }

      final accessToken = session.accessToken;

      // Vérifie si le token est expiré
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
          expiresAt * 1000,
        );
        if (expiryDate.isBefore(DateTime.now())) {
          debugPrint('⚠️ [PowerSync] Token expired - refreshing...');
          // Tente de rafraîchir la session
          await _supabase.auth.refreshSession();
          final newSession = _supabase.auth.currentSession;
          if (newSession == null) {
            return null;
          }
          return PowerSyncCredentials(
            endpoint: PowerSyncConfig.powersyncUrl,
            token: newSession.accessToken,
          );
        }
      }

      debugPrint(
        '✅ [PowerSync] Credentials fetched for user: ${session.user.email}',
      );

      return PowerSyncCredentials(
        endpoint: PowerSyncConfig.powersyncUrl,
        token: accessToken,
      );
    } catch (e) {
      debugPrint('❌ [PowerSync] Error fetching credentials: $e');
      return null;
    }
  }

  /// Upload des modifications locales vers Supabase
  ///
  /// PowerSync appelle cette méthode quand des changements locaux
  /// doivent être synchronisés avec le backend.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    debugPrint('📤 [PowerSync] Uploading local changes...');

    // Récupère toutes les transactions en attente d'upload
    final batch = await database.getCrudBatch();

    if (batch == null || batch.crud.isEmpty) {
      debugPrint('📤 [PowerSync] No changes to upload');
      return;
    }

    debugPrint('📤 [PowerSync] Uploading ${batch.crud.length} operations...');

    for (final op in batch.crud) {
      try {
        final table = op.table;
        final data = op.opData;

        // Skip if no data for upsert/update
        if (data == null && op.op != UpdateType.delete) {
          debugPrint('⚠️ [PowerSync] Skipping ${op.op} on $table: no data');
          continue;
        }

        switch (op.op) {
          case UpdateType.put:
            // INSERT ou UPDATE
            if (data != null) {
              await _supabase.from(table).upsert(data);
              debugPrint('📤 [PowerSync] Upserted into $table: ${op.id}');
            }
            break;

          case UpdateType.patch:
            // UPDATE partiel
            if (data != null) {
              await _supabase.from(table).update(data).eq('id', op.id);
              debugPrint('📤 [PowerSync] Updated $table: ${op.id}');
            }
            break;

          case UpdateType.delete:
            // DELETE
            await _supabase.from(table).delete().eq('id', op.id);
            debugPrint('📤 [PowerSync] Deleted from $table: ${op.id}');
            break;
        }
      } catch (e) {
        debugPrint('❌ [PowerSync] Error uploading ${op.op} on ${op.table}: $e');
        rethrow;
      }
    }

    // Marque le batch comme complété
    await batch.complete();
    debugPrint('✅ [PowerSync] Upload complete');
  }
}
