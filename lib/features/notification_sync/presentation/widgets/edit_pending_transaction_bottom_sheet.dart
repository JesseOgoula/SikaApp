import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/core/theme/app_theme.dart';

class EditPendingTransactionBottomSheet extends ConsumerStatefulWidget {
  final ParsedTransaction transaction;
  final Function(
    ParsedTransaction updatedTx,
    Debt? linkedDebt,
    String? accountId,
    String? toAccountId,
  ) onSave;

  const EditPendingTransactionBottomSheet({
    super.key,
    required this.transaction,
    required this.onSave,
  });

  @override
  ConsumerState<EditPendingTransactionBottomSheet> createState() =>
      _EditPendingTransactionBottomSheetState();
}

class _EditPendingTransactionBottomSheetState
    extends ConsumerState<EditPendingTransactionBottomSheet> {
  late TextEditingController _amountController;
  late String _type;
  String? _selectedCategoryId;
  Debt? _selectedDebt;
  bool _linkToDebt = false;
  String? _selectedAccountId;
  String? _selectedToAccountId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toString(),
    );
    _type = widget.transaction.type;
    _selectedCategoryId = widget.transaction.suggestedCategory;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountsAsync = ref.watch(activeAccountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final allDebtsAsync = ref.watch(allDebtsProvider);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Modifier la transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Segmented Control
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'expense';
                        _selectedDebt = null; // Réinitialise la dette si on change de type
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'expense'
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _type == 'expense'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Dépense',
                          style: TextStyle(
                            color: _type == 'expense'
                                ? AppTheme.error
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'income';
                        _selectedDebt = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'income'
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _type == 'income'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Revenu',
                          style: TextStyle(
                            color: _type == 'income'
                                ? AppTheme.success
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _type = 'transfer';
                        _selectedDebt = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _type == 'transfer'
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _type == 'transfer'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Transfert',
                          style: TextStyle(
                            color: _type == 'transfer'
                                ? const Color(0xFF8B5CF6)
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Montant
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sélection du compte
            activeAccountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) return const SizedBox.shrink();

                // Pré-sélection du compte basé sur le nom de l'opérateur si possible
                if (_selectedAccountId == null) {
                  final match = accounts.where((a) => a.name.toLowerCase().contains(widget.transaction.operatorLabel.toLowerCase()));
                  if (match.isNotEmpty) {
                    _selectedAccountId = match.first.id;
                  } else {
                    _selectedAccountId = accounts.first.id;
                  }
                }

                final accountItems = accounts.map((a) {
                  final isAsset = a.iconKey.startsWith('assets/') || a.iconKey.endsWith('.png');
                    Color accColor = Colors.grey;
                    try {
                      accColor = Color(int.parse(a.color.replaceFirst('#', '0xFF')));
                    } catch (_) {}

                    IconData fallbackIcon;
                    switch (a.iconKey) {
                      case 'phone_android':
                        fallbackIcon = Icons.phone_android;
                        break;
                      case 'account_balance':
                        fallbackIcon = Icons.account_balance;
                        break;
                      case 'payments':
                        fallbackIcon = Icons.payments;
                        break;
                      default:
                        fallbackIcon = Icons.account_balance_wallet;
                    }

                    return DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isAsset ? Colors.white : accColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: isAsset ? Border.all(color: Colors.grey.shade200) : null,
                            ),
                            child: isAsset
                                ? Image.asset(
                                    a.iconKey,
                                    width: 16,
                                    height: 16,
                                    fit: BoxFit.contain,
                                  )
                                : Icon(fallbackIcon, color: accColor, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Text(a.name),
                        ],
                      ),
                    );
                  }).toList();

                  // Set default destination account if transfer
                  if (_type == 'transfer' && _selectedToAccountId == null) {
                    final destMatch = accounts.where((a) => a.type == 'cash' || a.name.toLowerCase() == 'cash');
                    if (destMatch.isNotEmpty) {
                      _selectedToAccountId = destMatch.first.id;
                    }
                  }

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        decoration: InputDecoration(
                          labelText: _type == 'transfer' ? 'Compte source' : 'Compte',
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: accountItems,
                        onChanged: (val) {
                          setState(() => _selectedAccountId = val);
                        },
                      ),
                      if (_type == 'transfer') ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedToAccountId,
                          decoration: InputDecoration(
                            labelText: 'Compte destination',
                            prefixIcon: const Icon(Icons.account_balance_wallet),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: accountItems,
                          onChanged: (val) {
                            setState(() => _selectedToAccountId = val);
                          },
                        ),
                      ],
                    ],
                  );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Lien avec une créance/dette
            allDebtsAsync.when(
              data: (debts) {
                // Filtrer les dettes actives
                final activeDebts = debts.where((d) => d.status != DebtStatus.paid).toList();
                
                // Si type = revenu, on peut rembourser une "Créance à percevoir" (debtIn)
                // Si type = dépense, on peut rembourser une "Dette à payer" ou "Facture" (debtOut, bill)
                final relevantDebts = activeDebts.where((d) {
                  if (_type == 'income') return d.type == DebtType.debtIn;
                  return d.type == DebtType.debtOut || d.type == DebtType.bill;
                }).toList();

                if (relevantDebts.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          _type == 'income'
                              ? 'Remboursement d\'une créance ?'
                              : 'Paiement d\'une facture/dette ?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _linkToDebt,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) {
                          setState(() {
                            _linkToDebt = val;
                            if (!val) {
                              _selectedDebt = null;
                            }
                          });
                        },
                      ),
                    ),
                    if (_linkToDebt) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Debt?>(
                        value: _selectedDebt,
                        decoration: InputDecoration(
                          labelText: _type == 'income' 
                            ? 'Sélectionner la créance' 
                            : 'Sélectionner la dette/facture',
                          prefixIcon: const Icon(Icons.link),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<Debt?>(
                            value: null,
                            child: Text('Aucune', style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                          ...relevantDebts.map((d) {
                            final formatAmount = NumberFormat('#,###', 'fr_FR').format(d.amount - d.paidAmount);
                            return DropdownMenuItem<Debt?>(
                              value: d,
                              child: Text('${d.name} ($formatAmount F restants)'),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedDebt = val);
                        },
                      ),
                    ],
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Catégorie (Affiché uniquement si non lié à une dette et pas un transfert)
            if (!_linkToDebt && _type != 'transfer')
              categoriesAsync.when(
                data: (categories) {
                  final relevantCategories = categories.toList();

                  // Assurer que la catégorie sélectionnée est du bon type
                  if (_selectedCategoryId != null &&
                      !relevantCategories.any((c) => c.id == _selectedCategoryId)) {
                    _selectedCategoryId = relevantCategories.isNotEmpty
                        ? relevantCategories.first.id
                        : null;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: relevantCategories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline, size: 16),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategoryId = val);
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? widget.transaction.amount.toDouble();
                  final updatedTx = widget.transaction.copyWith(
                    amount: amount.toInt(),
                    type: _type,
                    suggestedCategory: _selectedCategoryId,
                  );

                  widget.onSave(updatedTx, _selectedDebt, _selectedAccountId, _type == 'transfer' ? _selectedToAccountId : null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
