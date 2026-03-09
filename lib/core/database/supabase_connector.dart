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

      return PowerSyncCredentials(
        endpoint: PowerSyncConfig.powersyncUrl,
        token: accessToken,
      );
    } catch (e) {
      return null;
    }
  }

  /// Upload des modifications locales vers Supabase
  ///
  /// PowerSync appelle cette méthode quand des changements locaux
  /// doivent être synchronisés avec le backend.
  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // Récupère toutes les transactions en attente d'upload
    final batch = await database.getCrudBatch();

    if (batch == null || batch.crud.isEmpty) {
      return;
    }

    for (final op in batch.crud) {
      try {
        final table = op.table;
        final data = op.opData;

        // Skip if no data for upsert/update
        if (data == null && op.op != UpdateType.delete) {
          continue;
        }

        switch (op.op) {
          case UpdateType.put:
            // INSERT ou UPDATE
            if (data != null) {
              // Add id to data for upsert
              var dataWithId = {...data, 'id': op.id};

              // Remove foreign keys for transactions to avoid constraint errors
              // (accounts/categories may not be synced yet)
              if (table == 'transactions') {
                dataWithId.remove('account_id');
                dataWithId.remove('category_id');
              }

              await _supabase.from(table).upsert(dataWithId);
            }
            break;

          case UpdateType.patch:
            // UPDATE partiel
            if (data != null) {
              var cleanData = {...data};
              if (table == 'transactions') {
                cleanData.remove('account_id');
                cleanData.remove('category_id');
              }
              await _supabase.from(table).update(cleanData).eq('id', op.id);
            }
            break;

          case UpdateType.delete:
            // DELETE
            await _supabase.from(table).delete().eq('id', op.id);
            break;
        }
      } catch (e) {
        // Continue with next operation instead of failing completely
        continue;
      }
    }

    // Marque le batch comme complété
    await batch.complete();
  }
}
