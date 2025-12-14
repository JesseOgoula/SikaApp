import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Écran d'accueil principal - Design Neo-Bank Pro
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
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
        if (tx.date.isAfter(firstOfMonth)) {
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

    // Solde disponible = Solde total - Épargne objectifs
    final soldeDisponible = totalBalance - totalSaved;

    // Layout sans scroll vertical
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),

        // PageView des cartes de solde (hauteur fixe)
        SizedBox(
          height: 160,
          child: PageView(
            controller: _balancePageController,
            onPageChanged: (index) => setState(() => _balancePageIndex = index),
            children: [
              // Carte 1 : Solde Disponible
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBalanceCard(
                  title: 'SOLDE DISPONIBLE',
                  amount: soldeDisponible,
                  subtitle:
                      'Dépenses ce mois: ${_formatCurrency(monthlyExpenses)}',
                  showSubtitle: true,
                ),
              ),
              // Carte 2 : Solde Total Historique
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBalanceCard(
                  title: 'SOLDE TOTAL (Historique)',
                  amount: totalIncomeAllTime,
                  subtitle: 'Total revenus depuis le début',
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
            ],
          ),
        ),
      ],
    );
  }

  /// Formate un montant en FCFA
  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA';
  }

  /// Carte de solde générique
  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required String subtitle,
    required bool showSubtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // Montant principal
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),

          if (showSubtitle) ...[
            const SizedBox(height: 12),
            // Info secondaire
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
