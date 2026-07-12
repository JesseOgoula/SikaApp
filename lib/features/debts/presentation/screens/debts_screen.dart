import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/debts/presentation/widgets/add_payment_bottom_sheet.dart';
import '../../data/providers/debt_providers.dart';
import '../../domain/entities/debt.dart';
import 'add_payable_screen.dart';
import 'add_receivable_screen.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';

void showAddDebtOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter un engagement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward, color: AppTheme.primaryColor),
              ),
              title: const Text('À payer', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Facture ou dette à rembourser', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPayableScreen()),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC59B27).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_downward, color: Color(0xFFC59B27)),
              ),
              title: const Text('À percevoir', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Revenu attendu ou prêt à récupérer', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddReceivableScreen()),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        appBar: AppBar(
          title: const Text('Créances & Dettes'),
          backgroundColor: AppTheme.scaffoldBackground,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            tabs: [
              Tab(text: 'À Payer'),
              Tab(text: 'À Percevoir'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DebtsList(typeFilter: [DebtType.bill, DebtType.debtOut]),
            _DebtsList(typeFilter: [DebtType.debtIn]),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showAddDebtOptions(context),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class _DebtsList extends ConsumerStatefulWidget {
  final List<DebtType> typeFilter;

  const _DebtsList({required this.typeFilter});

  @override
  ConsumerState<_DebtsList> createState() => _DebtsListState();
}

enum _DebtFilter { pending, paid, all }

class _DebtsListState extends ConsumerState<_DebtsList> {
  _DebtFilter _currentFilter = _DebtFilter.pending;

  @override
  Widget build(BuildContext context) {
    final allDebtsAsync = ref.watch(allDebtsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

    return allDebtsAsync.when(
      data: (allDebts) {
        final filteredDebts = allDebts.where((d) {
          if (!widget.typeFilter.contains(d.type)) return false;
          
          if (_currentFilter == _DebtFilter.pending) {
            return d.status == DebtStatus.pending || d.status == DebtStatus.overdue;
          } else if (_currentFilter == _DebtFilter.paid) {
            return d.status == DebtStatus.paid;
          }
          return true;
        }).toList();

        return Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: filteredDebts.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      itemCount: filteredDebts.length,
                      itemBuilder: (context, index) {
            final debt = filteredDebts[index];
            final isPaid = debt.status == DebtStatus.paid;
            final isOverdue = debt.status == DebtStatus.overdue;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDebtDetails(context, ref, debt),
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
                                  isPaid ? (debt.type == DebtType.debtIn ? 'Reçu le' : 'Payé le') : 'Échéance :',
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
                            if (!isPaid) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: debt.amount > 0 ? debt.paidAmount / debt.amount : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: debt.type == DebtType.debtIn 
                                    ? AppTheme.primaryColor
                                    : debt.type == DebtType.bill
                                        ? AppTheme.primaryColor
                                        : AppTheme.error,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currencyFormat.format(debt.paidAmount)} / ${currencyFormat.format(debt.amount)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      SizedBox(
                        width: 100,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: debt.type == DebtType.debtIn 
                                        ? const Color(0xFFC59B27).withOpacity(0.8) 
                                        : debt.type == DebtType.bill
                                            ? AppTheme.primaryColor.withOpacity(0.8)
                                            : AppTheme.error.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  debt.type == DebtType.debtIn 
                                      ? 'Revenu attendu'
                                      : debt.type == DebtType.bill
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
        ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      color: AppTheme.scaffoldBackground,
      child: Row(
        children: [
          _buildFilterChip('En cours', _DebtFilter.pending),
          const SizedBox(width: 8),
          _buildFilterChip('Soldées', _DebtFilter.paid),
          const SizedBox(width: 8),
          _buildFilterChip('Toutes', _DebtFilter.all),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _DebtFilter filter) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
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
    final accountsAsync = ref.read(accountsWithBalanceProvider);

    accountsAsync.when(
      data: (accounts) {
        _showPaymentDialogWithAccounts(context, ref, debt, accounts);
      },
      loading: () {
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
    List<AccountWithBalance> accounts,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return AddPaymentBottomSheet(
          debt: debt,
          accounts: accounts,
        );
      },
    );
  }

  FaIconData _getIconForType(DebtType type) {
    switch (type) {
      case DebtType.debtIn:
        return FontAwesomeIcons.arrowDown;
      case DebtType.debtOut:
        return FontAwesomeIcons.arrowUp;
      case DebtType.bill:
        return FontAwesomeIcons.fileInvoice;
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
          const Text(
            'Aucun engagement',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
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
    showAddDebtOptions(context);
  }

  void _showDebtDetails(BuildContext context, WidgetRef ref, Debt debt) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
    final isPaid = debt.status == DebtStatus.paid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                debt.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Montant total : ${currencyFormat.format(debt.amount)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (!isPaid) ...[
                Text(
                  'Déjà ${debt.type == DebtType.debtIn ? "perçu" : "payé"} : ${currencyFormat.format(debt.paidAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reste à ${debt.type == DebtType.debtIn ? "percevoir" : "payer"} : ${currencyFormat.format(debt.amount - debt.paidAmount)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: debt.type == DebtType.debtIn 
                        ? AppTheme.primaryColor 
                        : (debt.type == DebtType.bill ? AppTheme.primaryColor : AppTheme.error),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                'Échéance : ${dateFormat.format(debt.dueDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (!isPaid)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPaymentDialog(context, ref, debt);
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Enregistrer un versement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (debt.type == DebtType.debtIn) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddReceivableScreen(existingDebt: debt),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddPayableScreen(existingDebt: debt),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(context, ref, debt);
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Supprimer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Debt debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'engagement ?'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet engagement ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(debtRepositoryProvider).deleteDebt(debt.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Engagement supprimé avec succès')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
