import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/presentation/screens/statistics_screen.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/goals/presentation/screens/add_goal_screen.dart';
import 'package:sika_app/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:sika_app/features/goals/presentation/widgets/feed_goal_bottom_sheet.dart';
import 'package:sika_app/features/goals/presentation/widgets/goal_card.dart';
import 'package:sika_app/features/sms_parser/data/providers/sms_providers.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/balance_card.dart';
import 'package:sika_app/features/transactions/presentation/widgets/quick_actions.dart';
import 'package:sika_app/features/transactions/presentation/widgets/transaction_tile.dart';

/// Écran d'accueil principal - Design Neo-Bank Pro
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
  int _sliderPageIndex = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
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
      case 1: // Objectifs
        return const GoalsListScreen();
      case 2: // Transactions
        return const TransactionsListScreen();
      case 3: // Profil
        return _buildProfilePlaceholder();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProfilePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Profil (bientôt)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<TransactionWithCategory> transactions,
    SmsImportState importState,
  ) {
    // Calculs
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
        if (tx.date.isAfter(firstOfMonth)) {
          monthlyExpenses += tx.amount;
        }
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),

          // Balance Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BalanceCard(
              totalBalance: totalBalance,
              monthlyExpenses: monthlyExpenses,
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: QuickActions(
              onAddPressed: _onAddPressed,
              onSyncPressed: _onSyncPressed,
              isSyncing: importState.isImporting,
              onAnalysePressed: _onAnalysePressed,
              onGoalsPressed: _onGoalsPressed,
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
                        : 'Mes Objectifs',
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
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // PageView Slider (Transactions / Objectifs)
          SizedBox(
            height: 280,
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => _sliderPageIndex = index),
              children: [
                // Page 1: Transactions
                _buildTransactionsPage(transactions),
                // Page 2: Objectifs
                _buildGoalsPage(),
              ],
            ),
          ),

          // Bottom padding
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour 👋',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bienvenue sur SIKA',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppTheme.primaryColor),
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
            icon: Icon(Icons.flag_outlined),
            activeIcon: Icon(Icons.flag),
            label: 'Objectifs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
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
    final result = await ref
        .read(smsImportNotifierProvider.notifier)
        .importFromInbox();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                '${result.imported} nouvelles transactions',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _onAnalysePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  void _onGoalsPressed() {
    setState(() => _currentNavIndex = 1);
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
    return Padding(
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
        return Padding(
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

  Future<void> _onFeedGoal(GoalsTableData goal) async {
    await FeedGoalBottomSheet.show(context, goal);
  }
}
