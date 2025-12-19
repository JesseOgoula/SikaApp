import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import '../../data/providers/debt_providers.dart';
import '../../domain/entities/debt.dart';
import 'add_debt_screen.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Engagements'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
      ),
      body: const _DebtsList(typeFilter: [DebtType.bill, DebtType.debtOut]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDebtScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _DebtsList extends ConsumerWidget {
  final List<DebtType> typeFilter;

  const _DebtsList({required this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDebtsAsync = ref.watch(allDebtsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

    return allDebtsAsync.when(
      data: (allDebts) {
        final filteredDebts = allDebts
            .where((d) => typeFilter.contains(d.type))
            .toList();

        if (filteredDebts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 64,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun engagement',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: filteredDebts.length,
          itemBuilder: (context, index) {
            final debt = filteredDebts[index];
            final isPaid = debt.status == DebtStatus.paid;
            final isOverdue = debt.status == DebtStatus.overdue;

            return GestureDetector(
              onTap: () {
                if (isPaid) return;
                _showPaymentDialog(context, ref, debt);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icône - Style unifié avec Transactions
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          _getIconForType(debt.type),
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Infos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isPaid ? 'Payé le' : 'Échéance :',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                dateFormat.format(debt.dueDate),
                                style: TextStyle(
                                  color: isOverdue && !isPaid
                                      ? AppTheme.error
                                      : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isOverdue && !isPaid
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Montant & Type
                    SizedBox(
                      width: 100, // Largeur fixe pour éviter les décalages
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(debt.amount),
                            style: TextStyle(
                              color: isPaid
                                  ? AppTheme.success
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              decoration: isPaid
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Indicateur de Type (Facture vs Dette)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: debt.type == DebtType.bill
                                      ? Colors.orange.withOpacity(0.6)
                                      : Colors.redAccent.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                debt.type == DebtType.bill
                                    ? 'Facture'
                                    : 'Dette',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Badge de statut (Seulement si pertinent)
                          if (isPaid || isOverdue)
                            Text(
                              _getStatusLabel(debt.status),
                              style: TextStyle(
                                fontSize: 9,
                                color: isPaid
                                    ? AppTheme.success
                                    : AppTheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }

  String _getStatusLabel(DebtStatus status) {
    switch (status) {
      case DebtStatus.pending:
        return 'En attente';
      case DebtStatus.paid:
        return 'Payé';
      case DebtStatus.overdue:
        return 'En retard';
    }
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, Debt debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer paiement ?'),
        content: Text(
          'Voulez-vous marquer "${debt.name}" comme payé ?\nCeci créera une transaction de dépense.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(debtRepositoryProvider).markAsPaid(debt);
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(DebtType type) {
    switch (type) {
      case DebtType.bill:
        return FontAwesomeIcons.fileInvoiceDollar;
      case DebtType.debtOut:
        return FontAwesomeIcons.handHoldingDollar;
    }
  }
}
