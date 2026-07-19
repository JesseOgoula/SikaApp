import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/goals/presentation/widgets/goal_celebration_overlay.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';

/// BottomSheet pour alimenter un objectif d'épargne
class FeedGoalBottomSheet extends ConsumerStatefulWidget {
  final GoalsTableData goal;

  const FeedGoalBottomSheet({super.key, required this.goal});

  /// Affiche le BottomSheet et retourne true si une épargne a été ajoutée
  static Future<bool?> show(BuildContext context, GoalsTableData goal) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => FeedGoalBottomSheet(goal: goal),
    );
  }

  @override
  ConsumerState<FeedGoalBottomSheet> createState() =>
      _FeedGoalBottomSheetState();
}

class _FeedGoalBottomSheetState extends ConsumerState<FeedGoalBottomSheet> {
  String _amountText = '';
  bool _isLoading = false;
  String? _selectedAccountId;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  void _onKeyPressed(String key) {
    setState(() {
      if (_amountText.length < 10) {
        if (key == '.' && _amountText.contains('.')) return;
        _amountText += key;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.goal.targetAmount - widget.goal.savedAmount;
    final displayAmount = _amountText.isEmpty ? '0' : _amountText;
    
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    
    bool hasInsufficientFunds = false;
    if (_selectedAccountId != null && _amountText.isNotEmpty) {
      final amount = double.tryParse(_amountText) ?? 0;
      if (amount > 0) {
        try {
          final acc = accounts.firstWhere((a) => a.id == _selectedAccountId);
          if (amount > acc.balance) hasInsufficientFunds = true;
        } catch (_) {}
      }
    }
    
    final canSubmit = _amountText.isNotEmpty && 
                     (double.tryParse(_amountText) ?? 0) > 0 && 
                     _selectedAccountId != null && 
                     !hasInsufficientFunds;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Titre
              Text(
                'Épargner pour',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                widget.goal.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Reste à épargner
              Text(
                'Reste à épargner: ${_currencyFormat.format(remaining)}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Sélecteur de compte
              _buildAccountSelector(),

              const SizedBox(height: 20),

              // Affichage du montant
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayAmount,
                    style: TextStyle(
                      color: _amountText.isEmpty
                          ? const Color(0xFFD1D5DB)
                          : AppTheme.textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FCFA',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              if (hasInsufficientFunds)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Fonds insuffisants pour ce montant.',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Clavier numérique simplifié
              _buildNumberPad(),

              const SizedBox(height: 20),

              // Bouton Valider
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading || !canSubmit ? null : _feedGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Valider le versement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              final isBackspace = key == '⌫';
              return GestureDetector(
                onTap: () {
                  if (isBackspace) {
                    _onBackspace();
                  } else {
                    _onKeyPressed(key);
                  }
                },
                child: Container(
                  width: 70,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: isBackspace
                        ? Icon(
                            Icons.backspace_outlined,
                            color: AppTheme.primaryColor,
                            size: 22,
                          )
                        : Text(
                            key,
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  /// Sélecteur de compte source
  Widget _buildAccountSelector() {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun compte configuré'),
          );
        }

        // Sélectionner le premier compte par défaut
        _selectedAccountId ??= accounts.first.id;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedAccountId,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.primaryColor.withOpacity(0.6),
              ),
              items: accounts.map((acc) {
                final isAsset = acc.account.iconKey.startsWith('assets/') || acc.account.iconKey.endsWith('.png');
                final iconData = _getAccountIcon(acc.account.iconKey);
                final color = Color(
                  int.parse(acc.account.color.replaceFirst('#', '0xFF')),
                );
                return DropdownMenuItem<String>(
                  value: acc.id,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: isAsset
                            ? Image.asset(
                                acc.account.iconKey.endsWith('.png') && !acc.account.iconKey.endsWith('rond.png')
                                    ? acc.account.iconKey.replaceAll('.png', 'rond.png')
                                    : acc.account.iconKey,
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                              )
                            : Icon(iconData, color: color, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          acc.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        _currencyFormat.format(acc.balance),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedAccountId = value),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Text('Erreur chargement comptes'),
    );
  }

  IconData _getAccountIcon(String iconKey) {
    switch (iconKey) {
      case 'phone_android':
        return Icons.phone_android;
      case 'account_balance':
        return Icons.account_balance;
      case 'payments':
        return Icons.payments;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Future<void> _feedGoal() async {
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez entrer un montant valide'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner un compte'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Vérifier le solde du compte sélectionné
    final accountsAsync = ref.read(accountsWithBalanceProvider);
    final selectedAccount = accountsAsync.whenOrNull(
      data: (accounts) =>
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull,
    );
    final availableBalance = selectedAccount?.balance ?? 0.0;

    if (amount > availableBalance) {
      // Fermer le bottom sheet d'abord
      Navigator.pop(context);
      // Puis afficher le message d'erreur (visible sur l'écran parent)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solde insuffisant sur ${selectedAccount?.name ?? "ce compte"}. Disponible : ${_currencyFormat.format(availableBalance)}',
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(goalRepositoryProvider);
      final success = await repo.feedGoal(
        widget.goal.id,
        amount,
        _selectedAccountId!,
      );

      if (success && mounted) {
        // Vérifie si l'objectif est maintenant atteint
        final newSavedAmount = widget.goal.savedAmount + amount;
        final isNowCompleted = newSavedAmount >= widget.goal.targetAmount;
        final goalName = widget.goal.name;

        // Invalider les providers pour refresh
        ref.invalidate(activeGoalsProvider);
        ref.invalidate(transactionWithCategoryListProvider);

        // Fermer le bottom sheet
        Navigator.pop(context, true);

        if (isNowCompleted) {
          // 🎉 Objectif atteint → confettis !
          GoalCelebrationOverlay.show(context, goalName: goalName);
        } else {
          // Message de succès normal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bravo ! ${_currencyFormat.format(amount)} épargnés pour $goalName',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
