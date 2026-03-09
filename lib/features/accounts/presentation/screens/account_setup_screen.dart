import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';
import 'package:sika_app/core/services/analytics_service.dart';

/// Écran de configuration initiale des comptes
/// Affiché après la première connexion pour définir les soldes initiaux
class AccountSetupScreen extends ConsumerStatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  ConsumerState<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends ConsumerState<AccountSetupScreen> {
  // Comptes disponibles avec leurs configurations
  List<_AccountConfig> _accounts = [];

  bool _isLoading = true;
  int? _focusedIndex;
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent('onboarding_started');
    _loadAvailableAccounts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFocusedCard(int index) {
    final key = _cardKeys[index];
    if (key?.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    }
  }

  Future<void> _loadAvailableAccounts() async {
    final repo = ref.read(accountRepositoryProvider);
    final availableTypes = await repo.getAvailableAccountTypes();

    if (mounted) {
      if (availableTypes.isEmpty) {
        // Déjà tout configuré, redirection Home directe
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      setState(() {
        _accounts = availableTypes
            .map(
              (config) => _AccountConfig(
                name: config.name,
                type: config.type,
                iconPath: config.iconPath,
                color: config.color,
              ),
            )
            .toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Configuration',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    const Text(
                      'Vos comptes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sélectionnez les comptes que vous utilisez et entrez vos soldes actuels.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Liste des comptes
                    ..._accounts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final account = entry.value;
                      _cardKeys.putIfAbsent(index, () => GlobalKey());
                      return Padding(
                        key: _cardKeys[index],
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAccountCard(account, index),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Zone du bas : Bouton Continuer OU Pavé numérique
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_focusedIndex != null) ...[
                    // Barre de validation pour le pavé numérique
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _focusedIndex = null;
                              });
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
                    // Pavé numérique
                    NumberPad(
                      onKeyPressed: _onKeyPressed,
                      onBackspace: _onBackspace,
                    ),
                  ] else ...[
                    // Bouton Continuer
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _hasSelectedAccounts()
                              ? _onContinue
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Continuer',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(_AccountConfig account, int index) {
    final isEnabled = account.enabled;
    final isFocused = _focusedIndex == index;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: isFocused
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec toggle
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: account.iconPath != null
                      ? Image.asset(account.iconPath!, width: 26, height: 26)
                      : const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Nom
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _getTypeLabel(account.type),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle
              Switch.adaptive(
                value: isEnabled,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    account.enabled = value;
                    if (!value) {
                      account.balanceController.clear();
                      if (_focusedIndex == index) {
                        _focusedIndex = null;
                      }
                    } else {
                      // Focus automatically on enable
                      _focusedIndex = index;
                      _scrollToFocusedCard(index);
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),

          // Champ de solde (visible si activé)
          if (isEnabled) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _focusedIndex = index;
                });
                _scrollToFocusedCard(index);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: isFocused
                      ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.balanceController.text.isEmpty
                            ? 'Solde actuel'
                            : account.balanceController.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: account.balanceController.text.isEmpty
                              ? AppTheme.textSecondary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'FCFA',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onKeyPressed(String value) {
    if (_focusedIndex == null) return;

    final controller = _accounts[_focusedIndex!].balanceController;
    final currentText = controller.text;

    if (value == '.' && currentText.contains('.')) return;
    if (currentText == '0' && value != '.') {
      controller.text = value;
    } else {
      controller.text = currentText + value;
    }
    setState(() {}); // Rebuild to update UI
  }

  void _onBackspace() {
    if (_focusedIndex == null) return;

    final controller = _accounts[_focusedIndex!].balanceController;
    final currentText = controller.text;
    if (currentText.isNotEmpty) {
      controller.text = currentText.substring(0, currentText.length - 1);
      setState(() {});
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'mobileMoney':
        return 'Mobile Money';
      case 'bank':
        return 'Compte bancaire';
      case 'cash':
        return 'Espèces';
      default:
        return type;
    }
  }

  bool _hasSelectedAccounts() {
    return _accounts.any((a) => a.enabled);
  }

  Future<void> _onContinue() async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(accountRepositoryProvider);

      // Crée les comptes activés
      for (final account in _accounts) {
        if (account.enabled) {
          final balanceText = account.balanceController.text
              .replaceAll(' ', '')
              .replaceAll(',', '.');
          final balance = double.tryParse(balanceText) ?? 0.0;

          await repo.createAccount(
            name: account.name,
            type: account.type,
            initialBalance: balance,
            iconKey: account.iconPath ?? 'wallet',
            color: account.color,
            isDefault: _accounts.indexOf(account) == 0,
          );
          await AnalyticsService.logEvent(
            'account_created',
            properties: {'type': account.type},
          );
        }
      }

      await AnalyticsService.logEvent('onboarding_completed');

      // Navigation vers Home
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
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
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Configuration d'un compte pour le setup
class _AccountConfig {
  final String name;
  final String type;
  final String? iconPath;
  final String color;
  bool enabled;
  final TextEditingController balanceController = TextEditingController();

  _AccountConfig({
    required this.name,
    required this.type,
    required this.iconPath,
    required this.color,
    this.enabled = false,
  });
}
