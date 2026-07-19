import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/blinking_cursor.dart';

class AddPaymentBottomSheet extends ConsumerStatefulWidget {
  final Debt debt;
  final List<AccountWithBalance> accounts;

  const AddPaymentBottomSheet({
    super.key,
    required this.debt,
    required this.accounts,
  });

  @override
  ConsumerState<AddPaymentBottomSheet> createState() =>
      _AddPaymentBottomSheetState();
}

class _AddPaymentBottomSheetState extends ConsumerState<AddPaymentBottomSheet> {
  String _amountText = '';
  String? _selectedAccountId;
  bool _showKeypad = true;

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

  void _toggleKeypad() {
    setState(() {
      _showKeypad = !_showKeypad;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReceivable = widget.debt.type == DebtType.debtIn;
    final themeColor = AppTheme.primaryColor;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Balance spacing
                const Text(
                  'Confirmer le paiement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            widget.debt.name,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildAmountDisplay(themeColor),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      isReceivable ? 'Créditer sur' : 'Débiter depuis',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildAccountSelector(),
                  const SizedBox(height: 16),
                  Text(
                    isReceivable
                        ? 'Un revenu sera créé et le solde du compte sera augmenté.'
                        : 'Une dépense sera créée et le solde du compte sera diminué.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // NumberPad
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showKeypad
                ? AnimatedOpacity(
                    opacity: _showKeypad ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: NumberPad(
                      onKeyPressed: _onKeyPressed,
                      onBackspace: _onBackspace,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Submit Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submitPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Enregistrer le versement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(Color themeColor) {
    final displayAmount = _amountText.isEmpty ? '0' : _amountText;

    return GestureDetector(
      onTap: _toggleKeypad,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: _showKeypad ? themeColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showKeypad ? themeColor : Colors.grey.shade100,
            width: _showKeypad ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'Montant',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (_showKeypad && _amountText.isEmpty)
                  BlinkingCursor(
                    height: 40,
                    width: 3,
                    color: themeColor,
                  )
                else ...[
                  Text(
                    displayAmount,
                    style: TextStyle(
                      color: _amountText.isEmpty
                          ? const Color(0xFFD1D5DB)
                          : themeColor,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_showKeypad)
                    BlinkingCursor(
                      height: 40,
                      width: 3,
                      color: themeColor,
                    ),
                ],
                const SizedBox(width: 8),
                const Text(
                  'FCFA',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelector() {
    if (widget.accounts.isEmpty) {
      return Container(
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
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAccountId,
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
          items: widget.accounts.map((acc) {
            Color accColor;
            try {
              accColor = Color(
                int.parse(acc.color.replaceFirst('#', '0xFF')),
              );
            } catch (_) {
              accColor = Colors.grey;
            }
            final isAsset = acc.iconKey.startsWith('assets/') || acc.iconKey.endsWith('.png');
            IconData fallbackIcon;
            switch (acc.iconKey) {
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

            return DropdownMenuItem<String>(
              value: acc.id,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: isAsset
                        ? Image.asset(
                            acc.iconKey.endsWith('.png') && !acc.iconKey.endsWith('rond.png')
                                ? acc.iconKey.replaceAll('.png', 'rond.png')
                                : acc.iconKey,
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          )
                        : Icon(fallbackIcon, color: accColor, size: 20),
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
            setState(() {
              _selectedAccountId = value;
            });
          },
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    final enteredAmount = double.tryParse(_amountText) ?? 0.0;
    if (enteredAmount <= 0 || _selectedAccountId == null) return;

    await ref.read(debtRepositoryProvider).addPayment(
          debt: widget.debt,
          amount: enteredAmount,
          accountId: _selectedAccountId!,
          categoryId: widget.debt.type == DebtType.debtIn
              ? 'cat-revenus'
              : 'cat-factures',
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
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
                  '${widget.debt.name} : Versement enregistré',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  bool _hasInsufficientFunds() {
    if (widget.debt.type == DebtType.debtIn) return false; // Receipts don't need funds
    if (_selectedAccountId == null) return false;
    final amount = double.tryParse(_amountText) ?? 0;
    if (amount <= 0) return false;
    
    try {
      final selectedAcc = widget.accounts.firstWhere((a) => a.id == _selectedAccountId);
      return amount > selectedAcc.balance;
    } catch (_) {
      return false;
    }
  }

  bool _canSubmit() {
    if (_selectedAccountId == null || widget.accounts.isEmpty || _amountText.isEmpty) {
      return false;
    }
    final amount = double.tryParse(_amountText) ?? 0;
    if (amount <= 0) return false;
    
    // Check if enough funds
    if (_hasInsufficientFunds()) return false;
    
    return true;
  }
}
