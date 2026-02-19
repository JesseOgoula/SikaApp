import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';
import 'package:sika_app/features/accounts/presentation/screens/account_setup_screen.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final flagCompleted = prefs.getBool(kHasCompletedAccountSetup) ?? false;

    if (flagCompleted) {
      // Double-check : vérifier qu'il y a bien des comptes en base
      try {
        final hasAccounts = await ref
            .read(accountRepositoryProvider)
            .hasAnyAccounts();
        if (!hasAccounts) {
          // Flag dit "fait" mais pas de comptes → reset le flag
          await prefs.setBool(kHasCompletedAccountSetup, false);
          if (mounted) {
            setState(() {
              _hasCompletedSetup = false;
              _isLoading = false;
            });
          }
          return;
        }
      } catch (_) {
        // En cas d'erreur DB, on fait confiance au flag
      }
    }

    if (mounted) {
      setState(() {
        _hasCompletedSetup = flagCompleted;
        _isLoading = false;
      });
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
