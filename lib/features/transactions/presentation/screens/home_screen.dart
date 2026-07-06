import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/utils/time_utils.dart';
import 'package:sika_app/features/analytics/presentation/screens/statistics_screen.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/goals/presentation/screens/add_goal_screen.dart';
import 'package:sika_app/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:sika_app/features/goals/presentation/widgets/feed_goal_bottom_sheet.dart';
import 'package:sika_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/screens/transactions_list_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/quick_actions.dart';
import 'package:sika_app/features/debts/presentation/screens/debts_screen.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/debts/domain/entities/debt.dart';
import 'package:sika_app/features/analytics/presentation/widgets/rank_badge_widget.dart';
import 'package:sika_app/features/analytics/presentation/widgets/level_up_overlay.dart';
import 'package:sika_app/features/analytics/presentation/widgets/level_down_notification.dart';
import 'package:sika_app/features/analytics/presentation/screens/leaderboard_screen.dart';
import 'package:sika_app/features/analytics/domain/models/rank_model.dart';
import 'package:sika_app/features/analytics/data/services/rank_service.dart';
import 'package:sika_app/features/analytics/data/services/xp_service.dart';
import 'package:sika_app/core/services/settings_service.dart';
import 'package:sika_app/features/budgets/data/repositories/budget_repository.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/features/notification_sync/data/providers/pending_transaction_providers.dart';
import 'package:sika_app/features/notification_sync/presentation/screens/pending_transactions_screen.dart';



/// Écran d'accueil principal - Design Neo-Bank Pro
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentNavIndex = 0;
  bool _isAmountVisible = true;
  int _balancePageIndex = 0;
  bool _rankChecked = false;
  int _totalXP = 0;
  final _balancePageController = PageController();
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _configureSelectNotificationSubject();
  }

  void _configureSelectNotificationSubject() {
    _notificationSubscription = NotificationService.selectNotificationStream.stream.listen((String? payload) async {
      if (payload != null && payload.startsWith('pending_transaction') && mounted) {
        final parts = payload.split(':');
        final txId = parts.length > 1 ? parts[1] : null;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PendingTransactionsScreen(autoOpenTxId: txId)),
        );
      }
    });

    FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails().then((details) {
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        if (payload != null && payload.startsWith('pending_transaction')) {
          final parts = payload.split(':');
          final txId = parts.length > 1 ? parts[1] : null;

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PendingTransactionsScreen(autoOpenTxId: txId)),
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _balancePageController.dispose();
    super.dispose();
  }

  /// Vérifie si l'utilisateur a changé de rang et déclenche l'animation
  Future<void> _checkRankTransition(
    int healthScore,
    RankInfo currentRank,
  ) async {
    final settings = SettingsService();
    await settings.init();

    // Sauvegarder le health score pour que chaque sync Supabase l'ait
    await settings.setHealthScore(healthScore);

    // XP: check daily login + bonus santé
    final xpService = XPService();
    await xpService.checkDailyLogin();
    final healthBonus = (healthScore / 10).round();
    if (healthBonus > 0) {
      await xpService.awardCustomXP(healthBonus, 'Bonus santé financière');
    }

    final totalXP = await xpService.getTotalXP();
    final xpRank = RankDefinitions.getRankForXP(totalXP);
    final previousLevel = await settings.getPreviousRankLevel();

    // Mettre à jour l'état pour afficher les XP sur la carte
    if (mounted) {
      setState(() => _totalXP = totalXP);
    }

    // Sync vers Supabase
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final metadata = user.userMetadata ?? {};
      final displayName =
          (metadata['full_name'] ?? metadata['name'] ?? 'Utilisateur')
              as String;
      final avatarUrl = metadata['avatar_url'] as String?;

      final rankService = RankService();
      await rankService.syncRank(
        totalXP: totalXP,
        displayName: displayName,
        avatarUrl: avatarUrl,
        healthScore: healthScore,
      );
    }

    // Détecter transition
    if (previousLevel != xpRank.level) {
      final oldRank = RankDefinitions.all[previousLevel - 1];
      final transition = RankTransition(
        type: xpRank.level > previousLevel
            ? RankTransitionType.levelUp
            : RankTransitionType.levelDown,
        oldRank: oldRank,
        newRank: xpRank,
      );

      // Sauvegarder le nouveau niveau
      await settings.setPreviousRankLevel(xpRank.level);

      if (!mounted) return;

      if (transition.type == RankTransitionType.levelUp) {
        LevelUpOverlay.show(context, transition);
      } else {
        LevelDownNotification.show(context, transition);
      }
    }

    // Check budget respect pour le mois precedent (peut attribuer des XP)
    await _checkBudgetRespect(xpService, settings);

    // Rafraichir _totalXP apres tous les awards (budget, login, sante)
    final updatedXP = await xpService.getTotalXP();
    if (mounted && updatedXP != totalXP) {
      setState(() => _totalXP = updatedXP);
      // Re-sync vers Supabase avec le total final
      if (user != null) {
        final metadata = user.userMetadata ?? {};
        final displayName =
            (metadata['full_name'] ?? metadata['name'] ?? 'Utilisateur')
                as String;
        final avatarUrl = metadata['avatar_url'] as String?;
        RankService().syncRank(
          totalXP: updatedXP,
          displayName: displayName,
          avatarUrl: avatarUrl,
          healthScore: healthScore,
        );
      }
    }
  }

  /// Verifie les budgets du mois precedent et attribue +25 XP par budget respecte
  /// + envoie les notifications de depassement (une seule fois par mois)
  Future<void> _checkBudgetRespect(
    XPService xpService,
    SettingsService settings,
  ) async {
    try {
      final now = DateTime.now();
      final currentMonthKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final lastCheck = await settings.getLastBudgetCheckMonth();

      // Deja verifie ce mois-ci
      if (lastCheck == currentMonthKey) return;

      // Verifier le budget global actif
      final budgetRepo = ref.read(budgetRepositoryProvider);
      final globalBudget = await budgetRepo.getGlobalBudgetWithDetails();

      if (globalBudget != null) {
        final notifService = NotificationService();

        // Budget global respecte -> XP, sinon notification
        if (!globalBudget.isOverBudget) {
          await xpService.awardXP(ActionType.respectBudget);
        } else {
          await notifService.showGlobalBudgetExceededNotification(
            budgetLimit: globalBudget.amount,
            currentSpent: globalBudget.totalSpent,
          );
        }

        // Sous-budgets
        for (final sub in globalBudget.subBudgets) {
          if (!sub.isOverBudget) {
            await xpService.awardXP(ActionType.respectBudget);
          } else {
            await notifService.showBudgetExceededNotification(
              categoryName: sub.categoryName,
              budgetLimit: sub.amount,
              currentSpent: sub.currentSpent,
            );
          }
        }
      }

      // Marquer comme verifie
      await settings.setLastBudgetCheckMonth(currentMonthKey);
    } catch (e) {
      /* ignore */
    }
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

    // === GAMIFICATION: Sync rang + détection transition ===
    final rank = RankDefinitions.getRankForXP(
      0,
    ); // XP loaded async in _checkRankTransition
    if (!_rankChecked) {
      _rankChecked = true;
      _checkRankTransition(healthScore, rank);
    } else {
      // Toujours rafraichir les XP affiches (meme si rank deja checke)
      XPService().getTotalXP().then((xp) {
        if (mounted && xp != _totalXP) {
          setState(() => _totalXP = xp);
        }
      });
    }

    // Layout sans scroll vertical
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),

        // Banner transactions en attente
        _buildPendingTransactionsBanner(),

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

        // Section Activités récentes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Activités récentes',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Liste des 3 dernières activités
        Expanded(child: _buildRecentActivities(transactions)),
      ],
    );
  }

  /// Construit la bannière des transactions en attente
  Widget _buildPendingTransactionsBanner() {
    final pendingAsync = ref.watch(pendingTransactionsProvider);
    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PendingTransactionsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_toggle_off, color: AppTheme.primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pending.length} transaction${pending.length > 1 ? 's' : ''} en attente',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Text(
                      'Revoir',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppTheme.primaryColor, size: 16),
                  ],
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

  /// Carte individuelle pour un compte avec solde calculé (design premium enrichi)
  Widget _buildAccountCardDynamic(AccountWithBalance acc) {
    final accountColor = Color(int.parse(acc.color.replaceFirst('#', '0xFF')));
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);

    // Calcul des stats par compte
    final transactionsAsync = ref.watch(transactionWithCategoryListProvider);
    final allTransactions = transactionsAsync.valueOrNull ?? [];
    final totalBalance = ref.watch(totalAccountsBalanceProvider);

    double monthlyIncome = 0;
    double monthlyExpense = 0;
    int monthTxCount = 0; // ignore: unused_local_variable
    DateTime? lastTxDate;

    for (final txWithCat in allTransactions) {
      final tx = txWithCat.transaction;
      if (tx.accountId == acc.id) {
        // Dernière transaction (toutes périodes)
        if (lastTxDate == null || tx.date.isAfter(lastTxDate)) {
          lastTxDate = tx.date;
        }
        // Stats mensuelles
        if (tx.date.isAfter(firstOfMonth)) {
          monthTxCount++;
          if (tx.type == 'income') {
            monthlyIncome += tx.amount;
          } else if (tx.type == 'expense') {
            monthlyExpense += tx.amount;
          }
        }
      }
    }

    // Pourcentage du solde total
    final percentage = totalBalance > 0
        ? ((acc.balance / totalBalance) * 100).round()
        : 0;

    // Formatage dernière activité
    String lastActivityText;
    if (lastTxDate == null) {
      lastActivityText = 'Aucune activité';
    } else {
      final diff = now.difference(lastTxDate);
      if (diff.inMinutes < 60) {
        lastActivityText = 'Il y a ${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        lastActivityText = 'Il y a ${diff.inHours}h';
      } else if (diff.inDays == 1) {
        lastActivityText = 'Hier ${DateFormat('HH:mm').format(lastTxDate)}';
      } else if (diff.inDays < 7) {
        lastActivityText = 'Il y a ${diff.inDays}j';
      } else {
        lastActivityText = DateFormat('dd/MM').format(lastTxDate);
      }
    }

    // Icône appropriée par type de compte
    IconData accountIcon;
    switch (acc.iconKey) {
      case 'phone_android':
        accountIcon = Icons.phone_android;
        break;
      case 'account_balance':
        accountIcon = Icons.account_balance;
        break;
      case 'payments':
        accountIcon = Icons.payments;
        break;
      default:
        accountIcon = Icons.account_balance_wallet;
    }

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
          // === TOP ROW: Type badge + % du total ===
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
                    acc.iconKey.startsWith('assets/') || acc.iconKey.endsWith('.png')
                        ? Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              acc.iconKey,
                              width: 14,
                              height: 14,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(accountIcon, color: Colors.white, size: 14),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percentage% du total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // === MIDDLE: Nom + Solde + Toggle ===
          Text(
            acc.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isAmountVisible ? _formatAmount(acc.balance) : '••••••',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.1,
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
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Text(
            'FCFA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),

          const Spacer(),

          // === BOTTOM: Stats mensuelles + Dernière activité ===
          Row(
            children: [
              // Revenus du mois
              Icon(
                Icons.arrow_upward_rounded,
                color: Colors.greenAccent.shade200,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                _isAmountVisible ? _formatAmount(monthlyIncome) : '•••',
                style: TextStyle(
                  color: Colors.greenAccent.shade200,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              // Dépenses du mois
              Icon(
                Icons.arrow_downward_rounded,
                color: Colors.redAccent.shade100,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                _isAmountVisible ? _formatAmount(monthlyExpense) : '•••',
                style: TextStyle(
                  color: Colors.redAccent.shade100,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Dernière activité
              Icon(
                Icons.access_time,
                color: Colors.white.withOpacity(0.5),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                lastActivityText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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

    // Gradient dynamique basé sur le rang (AppTheme par défaut)
    final cardGradient = AppTheme.cardGradient;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(28),
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
              // Rank Badge (remplace HealthScoreBadge)
              RankBadgeWidget(xp: _totalXP, size: 42),
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
          Row(
            children: [
              // Bouton Classement
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LeaderboardScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                    size: 20,
                  ),
                ),
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
                  width: 42,
                  height: 42,
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
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                  ),
                ),
              ),
            ],
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
            'Ajoutez une transaction pour commencer.',
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
    showAddDebtOptions(context);
  }

  // ==================== ACTIVITÉS RÉCENTES ====================

  Widget _buildRecentActivities(List<TransactionWithCategory> transactions) {
    final goalsAsync = ref.watch(activeGoalsProvider);
    final debtsAsync = ref.watch(allDebtsProvider);

    final goals = goalsAsync.valueOrNull ?? [];
    final debts = debtsAsync.valueOrNull ?? [];

    // Construire une liste unifiée d'activités
    final List<_RecentActivity> activities = [];

    // Ajouter les transactions
    for (final txWithCat in transactions) {
      final tx = txWithCat.transaction;
      activities.add(
        _RecentActivity(
          type: _ActivityType.transaction,
          title:
              tx.merchantName ?? (tx.type == 'income' ? 'Revenu' : 'Dépense'),
          subtitle: txWithCat.category?.name ?? 'Transaction',
          amount: tx.amount,
          isPositive: tx.type == 'income',
          date: tx.date,
          icon: tx.type == 'income'
              ? FontAwesomeIcons.arrowDown
              : FontAwesomeIcons.arrowUp,
          iconColor: tx.type == 'income'
              ? const Color(0xFF2ECC71)
              : const Color(0xFFE74C3C),
        ),
      );
    }

    // Ajouter les objectifs
    for (final goal in goals) {
      activities.add(
        _RecentActivity(
          type: _ActivityType.goal,
          title: goal.name,
          subtitle: 'Objectif d\'épargne',
          amount: goal.targetAmount,
          isPositive: true,
          date: goal.createdAt,
          icon: FontAwesomeIcons.bullseye,
          iconColor: AppTheme.primaryColor,
        ),
      );
    }

    // Ajouter les dettes
    for (final debt in debts) {
      activities.add(
        _RecentActivity(
          type: _ActivityType.debt,
          title: debt.name,
          subtitle: debt.type == DebtType.bill ? 'Facture' : 'Prêt',
          amount: debt.amount,
          isPositive: false,
          date: debt.createdAt,
          icon: debt.type == DebtType.bill
              ? FontAwesomeIcons.fileInvoiceDollar
              : FontAwesomeIcons.handHoldingDollar,
          iconColor: const Color(0xFFE67E22),
        ),
      );
    }

    // Trier par date décroissante et prendre les 3 plus récents
    activities.sort((a, b) => b.date.compareTo(a.date));
    final recentActivities = activities.take(3).toList();

    if (recentActivities.isEmpty) {
      return _buildEmptyState();
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: recentActivities
            .map((activity) => _buildActivityTile(activity, currencyFormat))
            .toList(),
      ),
    );
  }

  Widget _buildActivityTile(
    _RecentActivity activity,
    NumberFormat currencyFormat,
  ) {
    return GestureDetector(
      onTap: () => _navigateToActivityScreen(activity.type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: activity.iconColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  activity.icon,
                  color: activity.iconColor,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Titre + Sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Montant + Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${activity.isPositive ? '+' : '-'} ${currencyFormat.format(activity.amount)}',
                  style: TextStyle(
                    color: activity.isPositive
                        ? const Color(0xFF2ECC71)
                        : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDate(activity.date),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Il y a $diff jours';
    return DateFormat('dd MMM', 'fr_FR').format(date);
  }

  void _navigateToActivityScreen(_ActivityType type) {
    switch (type) {
      case _ActivityType.transaction:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
        );
        break;
      case _ActivityType.goal:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalsListScreen()),
        );
        break;
      case _ActivityType.debt:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DebtsScreen()),
        );
        break;
    }
  }

  Future<void> _onFeedGoal(GoalsTableData goal) async {
    await FeedGoalBottomSheet.show(context, goal);
  }
}

// ==================== MODÈLES PRIVÉS ====================

enum _ActivityType { transaction, goal, debt }

class _RecentActivity {
  final _ActivityType type;
  final String title;
  final String subtitle;
  final double amount;
  final bool isPositive;
  final DateTime date;
  final FaIconData icon;
  final Color iconColor;

  _RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.date,
    required this.icon,
    required this.iconColor,
  });
}

class _CountryInfo {
  final String flag;
  final String name;
  final String currencyName;

  _CountryInfo(this.flag, this.name, this.currencyName);
}
