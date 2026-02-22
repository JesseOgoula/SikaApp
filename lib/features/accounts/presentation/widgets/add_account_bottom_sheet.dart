import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';

class AddAccountBottomSheet extends ConsumerStatefulWidget {
  const AddAccountBottomSheet({super.key});

  @override
  ConsumerState<AddAccountBottomSheet> createState() =>
      _AddAccountBottomSheetState();
}

class _AddAccountBottomSheetState extends ConsumerState<AddAccountBottomSheet> {
  List<AccountTypeConfig> _availableTypes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  AccountTypeConfig? _selectedType;
  final TextEditingController _balanceController = TextEditingController();
  bool _isNumpadVisible = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableTypes();
  }

  Future<void> _loadAvailableTypes() async {
    final repo = ref.read(accountRepositoryProvider);
    final types = await repo.getAvailableAccountTypes();
    if (mounted) {
      setState(() {
        _availableTypes = types;
        if (types.isNotEmpty) {
          _selectedType = types.first;
        }
        _isLoading = false;
      });
    }
  }

  void _onKeyPressed(String value) {
    final currentText = _balanceController.text;
    if (value == '.' && currentText.contains('.')) return;
    if (currentText == '0' && value != '.') {
      _balanceController.text = value;
    } else {
      _balanceController.text = currentText + value;
    }
    setState(() {});
  }

  void _onBackspace() {
    final currentText = _balanceController.text;
    if (currentText.isNotEmpty) {
      _balanceController.text = currentText.substring(
        0,
        currentText.length - 1,
      );
      setState(() {});
    }
  }

  Future<void> _saveAccount() async {
    if (_selectedType == null) return;

    setState(() => _isSaving = true);

    try {
      final balanceText = _balanceController.text
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      final balance = double.tryParse(balanceText) ?? 0.0;

      final repo = ref.read(accountRepositoryProvider);
      final success = await repo.createAccount(
        name: _selectedType!.name,
        type: _selectedType!.type,
        initialBalance: balance,
        iconKey: _selectedType!.iconPath ?? 'wallet',
        color: _selectedType!.color,
        isDefault: false,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context, true); // Indique le succès
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ce compte existe déjà.'),
              backgroundColor: AppTheme.error,
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
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_availableTypes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppTheme.success,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tous les comptes sont configurés',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Ajouter un compte',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Types de comptes
          SizedBox(
            height: 100,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _availableTypes.length,
              itemBuilder: (context, index) {
                final type = _availableTypes[index];
                final isSelected = _selectedType == type;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedType = type);
                  },
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (type.iconPath != null)
                          Image.asset(type.iconPath!, width: 28, height: 28)
                        else
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppTheme.textSecondary,
                            size: 28,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          type.name.split(' ').first,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Champ de solde
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Solde initial',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                setState(() => _isNumpadVisible = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isNumpadVisible
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _balanceController.text.isEmpty
                            ? '0'
                            : _balanceController.text,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _balanceController.text.isEmpty
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      'FCFA',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Numpad et boutton
          if (_isNumpadVisible) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isNumpadVisible = false);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('OK'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            NumberPad(onKeyPressed: _onKeyPressed, onBackspace: _onBackspace),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Ajouter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
