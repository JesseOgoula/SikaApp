import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';
import 'package:sika_app/features/accounts/presentation/screens/account_setup_screen.dart';

/// Constante pour le flag de setup
const String kHasCompletedAccountSetup = 'has_completed_account_setup';

/// Widget qui vérifie si le setup des comptes a été fait
/// Redirige vers AccountSetupScreen ou HomeScreen selon le cas
class AccountSetupChecker extends StatefulWidget {
  const AccountSetupChecker({super.key});

  @override
  State<AccountSetupChecker> createState() => _AccountSetupCheckerState();
}

class _AccountSetupCheckerState extends State<AccountSetupChecker> {
  bool _isLoading = true;
  bool _hasCompletedSetup = false;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompleted = prefs.getBool(kHasCompletedAccountSetup) ?? false;

    if (mounted) {
      setState(() {
        _hasCompletedSetup = hasCompleted;
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
