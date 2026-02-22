import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:intl/intl.dart';

class DeleteGoalDialog extends ConsumerStatefulWidget {
  final GoalsTableData goal;

  const DeleteGoalDialog({super.key, required this.goal});

  @override
  ConsumerState<DeleteGoalDialog> createState() => _DeleteGoalDialogState();
}

class _DeleteGoalDialogState extends ConsumerState<DeleteGoalDialog> {
  // Option sélectionnée par l'utilisateur
  // true = Rembourser sur un compte
  // false = Considérer comme perdu/dépensé
  bool _refundMoney = true;
  AccountsTableData? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final hasSavings = widget.goal.savedAmount > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        hasSavings ? 'Supprimer et récupérer' : 'Supprimer l\'objectif',
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Es-tu sûr de vouloir supprimer "${widget.goal.name}" ?',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (hasSavings) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cet objectif contient :',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(
                        locale: 'fr_FR',
                        symbol: 'FCFA',
                        decimalDigits: 0,
                      ).format(widget.goal.savedAmount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Que faire de cet argent ?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Option 1 : Récupérer l'argent
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Récupérer sur un compte'),
                leading: Radio<bool>(
                  value: true,
                  groupValue: _refundMoney,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() => _refundMoney = value!);
                  },
                ),
              ),

              // Dropdown pour sélectionner le compte
              if (_refundMoney)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 40,
                    right: 16,
                    bottom: 8,
                  ),
                  child: accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text(
                          'Aucun compte disponible',
                          style: TextStyle(color: AppTheme.error),
                        );
                      }

                      // Sélection par défaut
                      _selectedAccount ??= accounts.first;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AccountsTableData>(
                            isExpanded: true,
                            value: _selectedAccount,
                            items: accounts.map((account) {
                              return DropdownMenuItem(
                                value: account,
                                child: Text(account.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedAccount = value);
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const Text('Erreur chargement comptes'),
                  ),
                ),

              // Option 2 : Considérer comme dépensé
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Considérer comme dépensé'),
                leading: Radio<bool>(
                  value: false,
                  groupValue: _refundMoney,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() => _refundMoney = value!);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text(
            'Annuler',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Si on récupère l'argent, on s'assure qu'un compte est sélectionné
            if (hasSavings && _refundMoney && _selectedAccount == null) {
              return; // Empêche de valider sans compte
            }

            // Ferme le dialogue et renvoie le compte sélectionné (ou null)
            final result = (hasSavings && _refundMoney)
                ? _selectedAccount
                : null;
            Navigator.pop(context, {'confirmed': true, 'account': result});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'Supprimer',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
