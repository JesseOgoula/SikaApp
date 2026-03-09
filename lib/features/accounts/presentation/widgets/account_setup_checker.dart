import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';
import 'package:sika_app/features/accounts/presentation/screens/account_setup_screen.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/main.dart' show autoSyncService;

/// Constante pour le flag de setup
const String kHasCompletedAccountSetup = 'has_completed_account_setup';

/// Widget qui vérifie si le setup des comptes a été fait
/// Vérifie à la fois le flag local ET la présence de comptes en base
class AccountSetupChecker extends ConsumerStatefulWidget {
  const AccountSetupChecker({super.key});

  @override
  ConsumerState<AccountSetupChecker> createState() =>
      _AccountSetupCheckerState();
}

class _AccountSetupCheckerState extends ConsumerState<AccountSetupChecker> {
  bool _isLoading = true;
  bool _hasCompletedSetup = false;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    try {
      final repo = ref.read(accountRepositoryProvider);

      // 1. Tenter de récupérer les comptes depuis Supabase
      final hasCloudAccounts = await repo.fetchAccountsFromSupabase();

      if (hasCloudAccounts) {
        // Des comptes ont été trouvés ! Restaurer TOUTES les données
        await autoSyncService?.restoreFromCloud();

        if (mounted) {
          setState(() {
            _hasCompletedSetup = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Si rien sur le cloud, vérifier localement (cas offline ou nouveau device sans internet)
      final hasLocalAccounts = await repo.hasAnyAccounts();

      if (mounted) {
        setState(() {
          _hasCompletedSetup = hasLocalAccounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      // En cas d'erreur complète, se rabattre sur le local minimum
      if (mounted) {
        final repo = ref.read(accountRepositoryProvider);
        final hasLocal = await repo.hasAnyAccounts();
        setState(() {
          _hasCompletedSetup = hasLocal;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasCompletedSetup) {
      return const HomeScreen();
    } else {
      return const AccountSetupScreen();
    }
  }
}
