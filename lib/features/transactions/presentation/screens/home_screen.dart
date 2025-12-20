import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/services/sync_service.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/utils/time_utils.dart';
import 'package:sika_app/features/analytics/presentation/screens/statistics_screen.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/goals/presentation/screens/add_goal_screen.dart';
import 'package:sika_app/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:sika_app/features/goals/presentation/widgets/feed_goal_bottom_sheet.dart';
import 'package:sika_app/features/goals/presentation/widgets/goal_card.dart';
import 'package:sika_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:sika_app/features/sms_parser/data/providers/sms_providers.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/quick_actions.dart';
import 'package:sika_app/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:sika_app/features/debts/presentation/screens/debts_screen.dart';
import 'package:sika_app/features/debts/presentation/screens/add_debt_screen.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';

/// Écran d'accueil principal - Design Neo-Bank Pro
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isAmountVisible = true;
  int _sliderPageIndex = 0;
  int _balancePageIndex = 0;
  final _pageController = PageController();
  final _balancePageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    _balancePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionWithCategoryListProvider);
    final importState = ref.watch(smsImportNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(child: _buildBodyForIndex(transactionsAsync, importState)),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBodyForIndex(
    AsyncValue<List<TransactionWithCategory>> transactionsAsync,
    SmsImportState importState,
  ) {
    switch (_currentNavIndex) {
      case 0: // Accueil
        return transactionsAsync.when(
          data: (transactions) => _buildContent(transactions, importState),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (error, _) => Center(
            child: Text(
              'Erreur: $error',
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        );
      case 1: // Analyse
        return const StatisticsScreen();
      case 2: // Transactions
        return const TransactionsListScreen();
      case 3: // Objectifs
        return const GoalsListScreen();
      case 4: // Dettes
        return const DebtsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent(
    List<TransactionWithCategory> transactions,
    SmsImportState importState,
  ) {
    // Calculs locaux
    double totalBalance = 0;
    double monthlyExpenses = 0;
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    for (final txWithCat in transactions) {
      final tx = txWithCat.transaction;
      if (tx.type == 'income') {
        totalBalance += tx.amount;
      } else if (tx.type == 'expense') {
        totalBalance -= tx.amount;
        // N'ajouter aux dépenses mensuelles que ce qui n'est pas de l'épargne
        if (tx.date.isAfter(firstOfMonth) &&
            txWithCat.transaction.categoryId != 'cat-epargne') {
          monthlyExpenses += tx.amount;
        }
      }
    }

    // Récupère le total épargné dans les objectifs
    final totalSavedAsync = ref.watch(totalSavedInGoalsProvider);
    final totalSaved = totalSavedAsync.valueOrNull ?? 0.0;

    // Récupère le total historique des revenus
    final totalIncomeAllTimeAsync = ref.watch(totalIncomeAllTimeProvider);
    final totalIncomeAllTime = totalIncomeAllTimeAsync.valueOrNull ?? 0.0;

    // Récupère le montant des factures en attente pour le mois
    final pendingBillsAsync = ref.watch(pendingBillsAmountProvider);
    final pendingBills = pendingBillsAsync.valueOrNull ?? 0.0;

    // Solde disponible = Argent restant en compte (donc déjà déduit de l'épargne faite par transactions)
    // On ne soustrait plus totalSaved ici car chaque "ajout à un objectif" crée une transaction de dépense
    // qui réduit déjà totalBalance.
    final soldeDisponible = totalBalance - pendingBills;

    // Layout sans scroll vertical
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),

        // PageView des cartes de solde (hauteur ajustée pour le nouveau design)
        SizedBox(
          height: 200,
          child: PageView(
            controller: _balancePageController,
            onPageChanged: (index) => setState(() => _balancePageIndex = index),
            children: [
              // Carte 1 : Solde Disponible
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBalanceCard(
                  title: 'Solde disponible',
                  amount: soldeDisponible,
                  subtitle: 'Compte principal',
                  showSubtitle: true,
                ),
              ),
              // Carte 2 : Solde Total
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBalanceCard(
                  title: 'Solde total',
                  amount: totalIncomeAllTime,
                  subtitle: 'Tous comptes confondus',
                  showSubtitle: false,
                ),
              ),
            ],
          ),
        ),

        // Dots indicator pour les cartes de solde
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBalanceDot(0),
                const SizedBox(width: 6),
                _buildBalanceDot(1),
              ],
            ),
          ),
        ),

        // Quick Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: QuickActions(
            onAddPressed: _onAddPressed,
            onSyncPressed: _onSyncPressed,
            isSyncing: importState.isImporting,
            onGoalsPressed: _onAddGoalPressed,
            onDebtsPressed: _onAddDebtPressed,
          ),
        ),

        // Section Title avec indicateur de slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _sliderPageIndex == 0
                      ? 'Transactions Récentes'
                      : _sliderPageIndex == 1
                      ? 'Mes Objectifs'
                      : 'Mes Engagements',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Dots indicator
              Row(
                children: [
                  _buildDot(0),
                  const SizedBox(width: 6),
                  _buildDot(1),
                  const SizedBox(width: 6),
                  _buildDot(2),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // PageView Slider (Transactions / Objectifs) - prend l'espace restant
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _sliderPageIndex = index),
            children: [
              // Page 1: Transactions
              _buildTransactionsPage(transactions),
              // Page 2: Objectifs
              _buildGoalsPage(),
              // Page 3: Engagements
              _buildDebtsPage(),
            ],
          ),
        ),
      ],
    );
  }

  /// Formate un montant en FCFA
  /// Formate un montant en fonction de la devise du pays
  String _formatCurrency(double amount, String currencyCode) {
    final currency = currencyCode.split('(').last.replaceAll(')', '').trim();
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} $currency';
  }

  /// Carte de solde premium (Style Apple Wallet / Revolut)
  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required String subtitle,
    required bool showSubtitle,
  }) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final locale =
        (metadata['locale'] ?? metadata['preferred_locale'] ?? 'fr-GA')
            as String;
    debugPrint('SIKA_DEBUG: User Metadata: $metadata');
    debugPrint('SIKA_DEBUG: Selected Locale: $locale');
    final userInfo = _getCountryAndCurrency(locale);

    // Date et Heure "de connexion" (Heure actuelle simulée pour le design)
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Info Pays + Logo Carte
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(userInfo.flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      userInfo.currencyName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Middle: Label + Amount + Visibility
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isAmountVisible
                      ? _formatCurrency(amount, userInfo.currencyName)
                      : '••••••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _isAmountVisible = !_isAmountVisible),
                icon: Icon(
                  _isAmountVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Bottom: Account Info + Time/Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Numéro de compte',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '**** ${user?.id.substring(0, 4).toUpperCase() ?? "9934"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Dernière activité',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$formattedDate • $formattedTime',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper pour obtenir les infos pays/devise
  _CountryInfo _getCountryAndCurrency(String locale) {
    if (locale.contains('GA') || locale.contains('fr-GA')) {
      return _CountryInfo('🇬🇦', 'Gabon', 'Franc CFA (XAF)');
    } else if (locale.contains('CI') || locale.contains('fr-CI')) {
      return _CountryInfo('🇨🇮', 'Côte d\'Ivoire', 'Franc CFA (XOF)');
    } else if (locale.contains('SN') || locale.contains('fr-SN')) {
      return _CountryInfo('🇸🇳', 'Sénégal', 'Franc CFA (XOF)');
    } else if (locale.contains('CM') || locale.contains('fr-CM')) {
      return _CountryInfo('🇨🇲', 'Cameroun', 'Franc CFA (XAF)');
    } else if (locale.contains('BJ') || locale.contains('fr-BJ')) {
      return _CountryInfo('🇧🇯', 'Bénin', 'Franc CFA (XOF)');
    } else if (locale.contains('TG') || locale.contains('fr-TG')) {
      return _CountryInfo('🇹🇬', 'Togo', 'Franc CFA (XOF)');
    } else if (locale.contains('ML') || locale.contains('fr-ML')) {
      return _CountryInfo('🇲🇱', 'Mali', 'Franc CFA (XOF)');
    } else if (locale.contains('BF') || locale.contains('fr-BF')) {
      return _CountryInfo('🇧🇫', 'Burkina Faso', 'Franc CFA (XOF)');
    } else if (locale.contains('FR') || locale.contains('fr-FR')) {
      return _CountryInfo('🇫🇷', 'France', 'Euro (EUR)');
    } else if (locale.contains('US') || locale.contains('en-US')) {
      return _CountryInfo('🇺🇸', 'USA', 'US Dollar (USD)');
    } else {
      // Valeur par défaut pour SIKA (Afrique)
      return _CountryInfo('🇬🇦', 'Gabon', 'Franc CFA (XAF)');
    }
  }

  /// Dot indicator pour les cartes de solde
  Widget _buildBalanceDot(int index) {
    final isActive = _balancePageIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildHeader() {
    // Récupère les infos utilisateur
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final firstName = getFirstName(fullName);
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final greeting = getGreetingMessage();
    final emoji = getGreetingEmoji();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting $emoji',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Avatar cliquable -> ProfileScreen
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : const Icon(Icons.person, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune transaction',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importez vos SMS ou ajoutez manuellement',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) => setState(() => _currentNavIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Analyse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag_outlined),
            activeIcon: Icon(Icons.flag),
            label: 'Objectifs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Dettes',
          ),
        ],
      ),
    );
  }

  Future<void> _onAddPressed() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (result == true) {
      ref.invalidate(transactionWithCategoryListProvider);
    }
  }

  Future<void> _onSyncPressed() async {
    // 1. Import SMS
    final result = await ref
        .read(smsImportNotifierProvider.notifier)
        .importFromInbox();

    // 2. Sync vers le cloud
    final syncService = ref.read(syncServiceProvider);
    SyncResult? cloudResult;

    if (syncService.isLoggedIn) {
      cloudResult = await syncService.syncAll();
    }

    if (mounted) {
      final message = cloudResult != null
          ? '${result.imported} SMS + ${cloudResult.totalCount} sync cloud'
          : '${result.imported} nouvelles transactions';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cloudResult?.success == true
              ? AppTheme.success
              : AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                cloudResult?.success == true
                    ? Icons.cloud_done
                    : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _onAddGoalPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
    );
  }

  void _onAddDebtPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDebtScreen()),
    );
  }

  Widget _buildDot(int index) {
    final isActive = _sliderPageIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildTransactionsPage(List<TransactionWithCategory> transactions) {
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: transactions
            .take(3)
            .map((tx) => TransactionTile(txWithCategory: tx))
            .toList(),
      ),
    );
  }

  Widget _buildGoalsPage() {
    final goalsAsync = ref.watch(activeGoalsProvider);
    return goalsAsync.when(
      data: (goals) {
        if (goals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Aucun objectif',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Créer un objectif'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: goals
                .take(3)
                .map(
                  (goal) => GoalCard(
                    goal: goal,
                    onFeedPressed: () => _onFeedGoal(goal),
                  ),
                )
                .toList(),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (e, _) => Center(child: Text('Erreur: $e')),
    );
  }

  Widget _buildDebtsPage() {
    final debtsAsync = ref.watch(allDebtsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');

    return debtsAsync.when(
      data: (debts) {
        if (debts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Aucun engagement',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _onAddDebtPressed,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        // On n'affiche que les 3 prochains engagements non payés ou récents
        final displayDebts = debts
            .where((d) => d.status != DebtStatus.paid)
            .toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: displayDebts
                .take(3)
                .map((debt) => _buildDebtTile(debt, currencyFormat, dateFormat))
                .toList(),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (e, _) => Center(child: Text('Erreur: $e')),
    );
  }

  Widget _buildDebtTile(
    Debt debt,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FaIcon(
                debt.type == DebtType.bill
                    ? FontAwesomeIcons.fileInvoiceDollar
                    : FontAwesomeIcons.handHoldingDollar,
                color: AppTheme.primaryColor,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Échéance: ${dateFormat.format(debt.dueDate)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(debt.amount),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onFeedGoal(GoalsTableData goal) async {
    await FeedGoalBottomSheet.show(context, goal);
  }
}

class _CountryInfo {
  final String flag;
  final String name;
  final String currencyName;

  _CountryInfo(this.flag, this.name, this.currencyName);
}
