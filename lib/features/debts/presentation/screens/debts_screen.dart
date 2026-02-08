import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/database/app_database.dart';
import '../../data/providers/debt_providers.dart';
import '../../domain/entities/debt.dart';
import 'add_debt_screen.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';

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
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: filteredDebts.length,
          itemBuilder: (context, index) {
            final debt = filteredDebts[index];
            final isPaid = debt.status == DebtStatus.paid;
            final isOverdue = debt.status == DebtStatus.overdue;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  print('🔔 Debt tapped: ${debt.name}, isPaid: $isPaid');
                  if (isPaid) return;
                  _showPaymentDialog(context, ref, debt);
                },
                borderRadius: BorderRadius.circular(16),
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
    // Get accounts synchronously before showing dialog
    final accountsAsync = ref.read(activeAccountsProvider);

    accountsAsync.when(
      data: (accounts) {
        // Now show dialog with the data we already have
        _showPaymentDialogWithAccounts(context, ref, debt, accounts);
      },
      loading: () {
        // If loading, show a simple snackbar and retry
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chargement des comptes...'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      },
    );
  }

  void _showPaymentDialogWithAccounts(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    List<AccountsTableData> accounts,
  ) {
    String? selectedAccountId;

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currencyFormat = NumberFormat.currency(
              locale: 'fr_FR',
              symbol: 'FCFA',
              decimalDigits: 0,
            );

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header avec icône simple
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Titre
                    const Text(
                      'Confirmer le paiement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Nom de l'engagement
                    Text(
                      debt.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Montant simple
                    Text(
                      currencyFormat.format(debt.amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sélection du compte
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Débiter depuis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Aucun compte configuré',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedAccountId,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade500,
                            ),
                            hint: Text(
                              'Choisir un compte',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                            items: accounts.map((acc) {
                              Color accColor;
                              try {
                                accColor = Color(
                                  int.parse(
                                    acc.color.replaceFirst('#', '0xFF'),
                                  ),
                                );
                              } catch (_) {
                                accColor = Colors.grey;
                              }
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: accColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      acc.name,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedAccountId = value;
                              });
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Info box simple
                    Text(
                      'Une dépense sera créée et le solde du compte sera mis à jour.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Text(
                              'Annuler',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                selectedAccountId == null || accounts.isEmpty
                                ? null
                                : () async {
                                    await ref
                                        .read(debtRepositoryProvider)
                                        .markAsPaid(
                                          debt,
                                          createTransaction: true,
                                          accountId: selectedAccountId,
                                          categoryId: 'cat-factures',
                                        );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${debt.name} payé • Dépense enregistrée',
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: AppTheme.success,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Payer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun engagement',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Planifiez vos prochaines factures ou dettes',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addDebt(context),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un engagement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addDebt(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDebtScreen()),
    );
  }
}
