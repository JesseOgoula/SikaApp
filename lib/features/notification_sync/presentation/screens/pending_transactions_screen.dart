import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/notification_sync/data/providers/pending_transaction_providers.dart';
import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';
import 'package:sika_app/features/notification_sync/presentation/widgets/pending_transaction_card.dart';
import 'package:sika_app/features/notification_sync/presentation/screens/notification_sync_onboarding_screen.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:sika_app/features/notification_sync/presentation/widgets/edit_pending_transaction_bottom_sheet.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';

/// Écran listant les transactions détectées en attente de validation
class PendingTransactionsScreen extends ConsumerStatefulWidget {
  final String? autoOpenTxId;

  const PendingTransactionsScreen({super.key, this.autoOpenTxId});

  @override
  ConsumerState<PendingTransactionsScreen> createState() => _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends ConsumerState<PendingTransactionsScreen> {
  bool _hasAutoOpened = false;

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'Détections Automatiques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSyncOnboardingScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const _EmptyState();
          }

          if (widget.autoOpenTxId != null && !_hasAutoOpened) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final targetTx = transactions.where((t) => t.id == widget.autoOpenTxId).firstOrNull;
                if (targetTx != null) {
                  _hasAutoOpened = true;
                  _handleEdit(context, ref, targetTx);
                }
              }
            });
          }

          return Column(
            children: [
              _buildHeader(context, ref, transactions.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return PendingTransactionCard(
                      tx: tx,
                      onConfirm: () => _handleConfirm(context, ref, tx),
                      onEdit: () => _handleEdit(context, ref, tx),
                      onReject: () => _handleReject(context, ref, tx),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erreur: $err', style: TextStyle(color: AppTheme.error)),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count transaction${count > 1 ? 's' : ''} en attente',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          TextButton(
            onPressed: () => _handleRejectAll(context, ref),
            child: Text(
              'Tout ignorer',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm(
    BuildContext context,
    WidgetRef ref,
    ParsedTransaction tx,
  ) async {
    final queue = ref.read(pendingTransactionQueueProvider);
    final repo = ref.read(transactionRepositoryProvider);

    try {
      // 1. Marquer comme confirmé dans la file d'attente
      await queue.confirm(tx.id);

      // Essayer de trouver les comptes (source et destination)
      String? sourceAccountId;
      String? destinationAccountId;
      
      try {
        final accounts = await ref.read(activeAccountsProvider.future);
        
        // Auto-match source account based on operator
        final sourceMatch = accounts.where((a) => a.name.toLowerCase().contains(tx.operatorLabel.toLowerCase()));
        if (sourceMatch.isNotEmpty) {
          sourceAccountId = sourceMatch.first.id;
        } else if (accounts.isNotEmpty) {
          sourceAccountId = accounts.first.id;
        }

        // Si c'est un transfert, auto-match destination account (Cash)
        if (tx.isTransfer) {
          final destMatch = accounts.where((a) => a.type == 'cash' || a.name.toLowerCase() == 'cash');
          if (destMatch.isNotEmpty) {
            destinationAccountId = destMatch.first.id;
          }
        }
      } catch (_) {
        // Ignorer si les comptes ne sont pas encore chargés
      }

      final companion = TransactionsTableCompanion(
        amount: drift.Value(tx.amount.toDouble()),
        type: drift.Value(tx.type),
        accountId: sourceAccountId != null ? drift.Value(sourceAccountId) : const drift.Value.absent(),
        toAccountId: destinationAccountId != null ? drift.Value(destinationAccountId) : const drift.Value.absent(),
        merchantName: drift.Value(tx.description),
        categoryId: drift.Value(tx.suggestedCategory),
        date: drift.Value(DateTime.parse(tx.receivedAt)),
        externalId: drift.Value(tx.externalId ?? 'auto_${tx.id}'),
        isAiCategorized: const drift.Value(true), // Considéré comme auto-catégorisé
      );

      await repo.addManualTransaction(companion);

      // Award XP specific to auto detection
      XPService().awardXP(ActionType.validateAutoDetection);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction enregistrée avec succès'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _handleEdit(BuildContext context, WidgetRef ref, ParsedTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => EditPendingTransactionBottomSheet(
        transaction: tx,
        onSave: (updatedTx, linkedDebt, accountId, toAccountId) async {
          Navigator.pop(context);

          final queue = ref.read(pendingTransactionQueueProvider);
          final txRepo = ref.read(transactionRepositoryProvider);
          final debtRepo = ref.read(debtRepositoryProvider);

          try {
            await queue.confirm(updatedTx.id);

            if (linkedDebt != null && accountId != null) {
              await debtRepo.addPayment(
                debt: linkedDebt,
                amount: updatedTx.amount.toDouble(),
                accountId: accountId,
                categoryId: updatedTx.suggestedCategory,
              );
            } else {
              final companion = TransactionsTableCompanion(
                amount: drift.Value(updatedTx.amount.toDouble()),
                type: drift.Value(updatedTx.type),
                merchantName: drift.Value(updatedTx.description),
                categoryId: drift.Value(updatedTx.suggestedCategory),
                accountId: accountId != null ? drift.Value(accountId) : const drift.Value.absent(),
                toAccountId: toAccountId != null ? drift.Value(toAccountId) : const drift.Value.absent(),
                date: drift.Value(DateTime.parse(updatedTx.receivedAt)),
                externalId: drift.Value(updatedTx.externalId ?? 'auto_${updatedTx.id}'),
                isAiCategorized: const drift.Value(true),
              );

              await txRepo.addManualTransaction(companion);
            }

            // Award XP specific to auto detection
            XPService().awardXP(ActionType.validateAutoDetection);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction modifiée et enregistrée avec succès'),
                  backgroundColor: AppTheme.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur lors de l\'enregistrement : $e'),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    ParsedTransaction tx,
  ) async {
    final queue = ref.read(pendingTransactionQueueProvider);
    await queue.reject(tx.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction ignorée'),
        ),
      );
    }
  }

  Future<void> _handleRejectAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout ignorer ?'),
        content: const Text(
          'Voulez-vous vraiment ignorer toutes les transactions détectées en attente ? '
          'Elles ne seront pas enregistrées dans votre historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Oui, tout ignorer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final queue = ref.read(pendingTransactionQueueProvider);
      await queue.clear();
      if (context.mounted) {
        Navigator.pop(context); // Retour à l'accueil si la liste est vide
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tout est à jour !',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous n\'avez aucune transaction\nen attente de validation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
