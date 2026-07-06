import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/notification_sync/data/services/notification_sync_service.dart';
import 'package:sika_app/features/notification_sync/data/services/pending_transaction_queue.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// Provider pour le service de synchronisation des notifications
final notificationSyncServiceProvider = Provider<NotificationSyncService>((ref) {
  return NotificationSyncService();
});

/// Provider pour la file d'attente des transactions en attente
final pendingTransactionQueueProvider = Provider<PendingTransactionQueue>((ref) {
  return PendingTransactionQueue();
});

/// StreamProvider pour la liste réactive des transactions en attente
///
/// L'UI se met à jour automatiquement quand une nouvelle transaction
/// est détectée ou quand l'utilisateur en confirme/rejette une.
///
/// Usage:
/// ```dart
/// final pending = ref.watch(pendingTransactionsProvider);
/// pending.when(
///   data: (list) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Erreur: $e'),
/// );
/// ```
final pendingTransactionsProvider =
    StreamProvider<List<ParsedTransaction>>((ref) async* {
  final queue = ref.watch(pendingTransactionQueueProvider);

  // Émet la liste initiale
  yield await queue.getAll();

  // Puis écoute les mises à jour du stream
  await for (final list in queue.stream) {
    yield list;
  }
});

/// FutureProvider pour le nombre de transactions en attente
///
/// Utile pour afficher un badge numérique dans l'AppBar.
final pendingTransactionCountProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(pendingTransactionQueueProvider);
  return queue.count;
});

/// Provider pour savoir si la détection automatique est activée
final notificationSyncEnabledProvider =
    StateProvider<bool>((ref) {
  final service = ref.watch(notificationSyncServiceProvider);
  return service.isEnabled;
});
