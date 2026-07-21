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
  final _scrollController = ScrollController();

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
                      'Sélectionnez les comptes que vous utilisez.',
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
                      return Padding(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(_AccountConfig account, int index) {
    final isEnabled = account.enabled;
    

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        
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
                child: Center(
                  child: account.iconPath != null
                      ? Image.asset(account.iconPath!, width: 32, height: 32)
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
                  setState(() { account.enabled = value; });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),

          // Champ de solde a été supprimé
        ],
      ),
    );
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
          final balance = 0.0;

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

  _AccountConfig({
    required this.name,
    required this.type,
    required this.iconPath,
    required this.color,
    this.enabled = false,
  });
}

