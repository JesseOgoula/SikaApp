import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/notification_sync/data/providers/pending_transaction_providers.dart';

/// Un badge réactif qui affiche le nombre de transactions en attente.
///
/// Si [child] est fourni, le badge s'affiche par-dessus (ex: sur une icône).
/// Sinon, il s'affiche comme un élément autonome (ex: dans un bouton).
class NotificationSyncBadge extends ConsumerWidget {
  final Widget? child;
  final VoidCallback? onTap;

  const NotificationSyncBadge({
    super.key,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écoute le stream pour mettre à jour le compteur en temps réel
    final pendingAsync = ref.watch(pendingTransactionsProvider);

    return pendingAsync.when(
      data: (transactions) {
        final count = transactions.length;

        // Ne rien afficher s'il n'y a pas de transactions en attente
        // sauf si un enfant est fourni (on affiche l'enfant sans le badge)
        if (count == 0) {
          return child != null
              ? (onTap != null
                  ? GestureDetector(onTap: onTap, child: child)
                  : child!)
              : const SizedBox.shrink();
        }

        final badge = Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFFDC2626), // Rouge alerte
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(
            minWidth: 16,
            minHeight: 16,
          ),
          child: Text(
            count > 9 ? '9+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );

        Widget content;

        if (child != null) {
          content = Stack(
            clipBehavior: Clip.none,
            children: [
              child!,
              Positioned(
                right: -4,
                top: -4,
                child: badge,
              ),
            ],
          );
        } else {
          content = badge;
        }

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            child: content,
          );
        }

        return content;
      },
      loading: () => child ?? const SizedBox.shrink(),
      error: (_, __) => child ?? const SizedBox.shrink(),
    );
  }
}
