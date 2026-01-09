import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/quick_actions.dart';
import 'package:sika_app/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:sika_app/features/debts/presentation/screens/debts_screen.dart';
import 'package:sika_app/features/debts/presentation/screens/add_debt_screen.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';
import 'package:sika_app/features/analytics/presentation/widgets/health_score_badge.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(child: _buildBodyForIndex(transactionsAsync)),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBodyForIndex(
    AsyncValue<List<TransactionWithCategory>> transactionsAsync,
  ) {
    switch (_currentNavIndex) {
      case 0: // Accueil
        return transactionsAsync.when(
          data: (transactions) => _buildContent(transactions),
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

  Widget _buildContent(List<TransactionWithCategory> transactions) {
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

    // Récupère le solde total des comptes et le nombre de comptes actifs
    final totalAccountsBalance = ref.watch(totalAccountsBalanceProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);
    final activeAccountsCount = accountsAsync.valueOrNull?.length ?? 0;

    // Solde disponible = Argent restant en compte (donc déjà déduit de l'épargne faite par transactions)
    final soldeDisponible = totalBalance - pendingBills;

    // Calcul du score de santé financière AMÉLIORÉ
    // 5 composantes pour 100 points total:
    // 1. Taux d'épargne (0-30 points)
    // 2. Ratio dépenses (0-20 points)
    // 3. Ratio dette (0-20 points)
    // 4. Coussin de sécurité (0-20 points) - NOUVEAU
    // 5. Diversification comptes (0-10 points) - NOUVEAU

    double monthlyIncome = 0;
    double monthlySavings = 0;
    for (final txWithCat in transactions) {
      final tx = txWithCat.transaction;
      if (tx.date.isAfter(firstOfMonth)) {
        if (tx.type == 'income') {
          monthlyIncome += tx.amount;
        } else if (tx.categoryId == 'cat-epargne') {
          monthlySavings += tx.amount;
        }
      }
    }

    double savingsScore = 0;
    double expenseScore = 0;
    double debtScore = 20; // Score max de base si pas de dette
    double cushionScore = 0; // NOUVEAU: Coussin de sécurité
    double diversificationScore = 0; // NOUVEAU: Diversification

    if (monthlyIncome > 0) {
      // Taux d'épargne : 20% = score max (30 points)
      final savingsRate = monthlySavings / monthlyIncome;
      savingsScore = (savingsRate * 150).clamp(0, 30).toDouble();

      // Ratio dépenses : si dépenses < 80% des revenus = bon score (20 pts)
      final expenseRate = monthlyExpenses / monthlyIncome;
      expenseScore = ((1 - expenseRate) * 40).clamp(0, 20).toDouble();

      // Ratio dette : si dette < 30% des revenus = bon score (20 pts)
      final debtRatio = pendingBills / monthlyIncome;
      debtScore = ((1 - debtRatio) * 20).clamp(0, 20).toDouble();
    } else if (soldeDisponible > 0) {
      expenseScore = 10;
      savingsScore = 5;
    }

    // NOUVEAU: Coussin de sécurité (20 pts)
    // Objectif: avoir 3 mois de dépenses en réserve
    if (monthlyExpenses > 0) {
      final monthsCovered = totalAccountsBalance / monthlyExpenses;
      cushionScore = (monthsCovered / 3 * 20).clamp(0, 20).toDouble();
    } else if (totalAccountsBalance > 0) {
      cushionScore = 10; // Score moyen si pas de dépenses
    }

    // NOUVEAU: Diversification comptes (10 pts)
    // 1 compte = 0, 2 = 5, 3+ = 10
    if (activeAccountsCount >= 3) {
      diversificationScore = 10;
    } else if (activeAccountsCount == 2) {
      diversificationScore = 5;
    }

    final healthScore =
        (savingsScore +
                expenseScore +
                debtScore +
                cushionScore +
                diversificationScore)
            .round()
            .clamp(0, 100);

    // Layout sans scroll vertical
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),

        // PageView des cartes de compte dynamiques
        _buildDynamicAccountCards(healthScore, soldeDisponible),

        // Dots indicator dynamiques
        _buildDynamicBalanceDots(),

        // Quick Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: QuickActions(
            onAddPressed: _onAddPressed,
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

  /// Construit les cartes de compte dynamiques avec soldes calculés
  Widget _buildDynamicAccountCards(int healthScore, double defaultBalance) {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final totalBalance = ref.watch(totalAccountsBalanceProvider);

    return accountsAsync.when(
      data: (accounts) {
        // Si aucun compte, afficher une carte par défaut
        if (accounts.isEmpty) {
          return SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildBalanceCard(
                title: 'Solde disponible',
                amount: defaultBalance,
                subtitle: 'Configurez vos comptes',
                showSubtitle: true,
                healthScore: healthScore,
              ),
            ),
          );
        }

        // Construire les cartes: Total + chaque compte
        final cards = <Widget>[
          // Carte Total
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildBalanceCard(
              title: 'Solde total',
              amount: totalBalance,
              subtitle: 'Tous comptes',
              showSubtitle: true,
              healthScore: healthScore,
            ),
          ),
          // Cartes pour chaque compte avec solde calculé
          ...accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildAccountCardDynamic(acc),
            ),
          ),
        ];

        return SizedBox(
          height: 200,
          child: PageView(
            controller: _balancePageController,
            onPageChanged: (index) => setState(() => _balancePageIndex = index),
            children: cards,
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      ),
      error: (_, __) => SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildBalanceCard(
            title: 'Solde disponible',
            amount: defaultBalance,
            subtitle: 'Erreur de chargement',
            showSubtitle: true,
            healthScore: healthScore,
          ),
        ),
      ),
    );
  }

  /// Carte individuelle pour un compte avec solde calculé (design premium)
  Widget _buildAccountCardDynamic(AccountWithBalance acc) {
    final accountColor = Color(int.parse(acc.color.replaceFirst('#', '0xFF')));
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accountColor,
        HSLColor.fromColor(accountColor).withLightness(0.3).toColor(),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accountColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getAccountTypeLabel(acc.type),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$formattedDate • $formattedTime',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            acc.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(acc.balance),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          Text(
            'FCFA',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _getAccountTypeLabel(String type) {
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

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }

  /// Dots indicator dynamiques selon le nombre de comptes
  Widget _buildDynamicBalanceDots() {
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return accountsAsync.when(
      data: (accounts) {
        final dotCount = accounts.isEmpty ? 1 : accounts.length + 1;
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                dotCount,
                (index) => Padding(
                  padding: EdgeInsets.only(left: index > 0 ? 6 : 0),
                  child: _buildBalanceDot(index),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
    required int healthScore,
  }) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final locale =
        (metadata['locale'] ?? metadata['preferred_locale'] ?? 'fr-GA')
            as String;
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
              // Health Score Badge
              HealthScoreBadge(score: healthScore, size: 42),
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
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isAmountVisible = !_isAmountVisible);
                },
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 40,
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune transaction',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importez vos SMS pour commencer.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    size: 40,
                    color: AppTheme.primaryColor.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun objectif',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Épargnez pour vos rêves.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 40,
                    color: AppTheme.primaryColor.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun engagement',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tout est en ordre !',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
