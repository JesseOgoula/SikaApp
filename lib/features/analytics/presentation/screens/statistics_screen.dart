import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:sika_app/core/database/app_database.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:sika_app/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:sika_app/features/analytics/domain/entities/category_stat.dart';

import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';
import 'package:sika_app/features/analytics/presentation/widgets/health_score_card.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';

/// Dashboard Analytics - Redesign Premium avec Financial Health Score
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

enum AnalysisPeriod { sevenDays, thisMonth, threeMonths, year }

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  AnalysisPeriod _selectedPeriod = AnalysisPeriod.thisMonth;
  final int _touchedPieIndex = -1;

  // Données
  List<CategoryStat> _categoryStats = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalSavings = 0;
  double _prevIncome = 0;
  double _prevExpense = 0;
  double _totalPendingDebt = 0;
  int _healthScore = 0;
  List<TransactionWithCategory> _topTransactions = [];
  Map<DateTime, List<TransactionWithCategory>> _groupedTransactions = {};
  bool _isLoading = true;
  bool _isBackgroundLoading = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoader) {
        _isLoading = true;
      } else {
        _isBackgroundLoading = true;
      }
    });

    try {
      final db = ref.read(databaseProvider);
      final repo = TransactionRepositoryImpl(db);
      final goalRepo = ref.read(goalRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case AnalysisPeriod.sevenDays:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case AnalysisPeriod.thisMonth:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case AnalysisPeriod.threeMonths:
          startDate = DateTime(now.year, now.month - 2, 1);
          break;
        case AnalysisPeriod.year:
          startDate = DateTime(now.year, 1, 1);
          break;
      }

      final prevStartDate = startDate.subtract(endDate.difference(startDate));
      final prevEndDate = startDate.subtract(const Duration(seconds: 1));

      final results = await Future.wait([
        repo.getExpensesByCategoryRange(startDate, endDate),
        repo.getDailySummaryRange(startDate, endDate),
        repo.getTotalIncomeRange(startDate, endDate),
        repo.getTotalExpenseRange(startDate, endDate),
        repo.getTotalSavingsRange(startDate, endDate),
        repo.getTotalIncomeRange(prevStartDate, prevEndDate),
        repo.getTotalExpenseRange(prevStartDate, prevEndDate),
        repo.getTotalSavingsRange(prevStartDate, prevEndDate),
        db.select(db.transactionsTable).join([
          leftOuterJoin(
            db.categoriesTable,
            db.categoriesTable.id.equalsExp(db.transactionsTable.categoryId),
          ),
        ]).get(),
        debtRepo.getTotalPendingDebt(),
      ]);

      final allTxs = results[8] as List<TypedResult>;

      final filteredTxs = allTxs
          .map(
            (row) => TransactionWithCategory(
              transaction: row.readTable(db.transactionsTable),
              category: row.readTableOrNull(db.categoriesTable),
            ),
          )
          .where(
            (t) =>
                t.transaction.date.isAfter(
                  startDate.subtract(const Duration(seconds: 1)),
                ) &&
                t.transaction.date.isBefore(
                  endDate.add(const Duration(seconds: 1)),
                ),
          )
          .toList();

      filteredTxs.sort(
        (a, b) => b.transaction.date.compareTo(a.transaction.date),
      );

      // Group par jour
      final grouped = <DateTime, List<TransactionWithCategory>>{};
      for (var tx in filteredTxs) {
        final date = DateTime(
          tx.transaction.date.year,
          tx.transaction.date.month,
          tx.transaction.date.day,
        );
        if (grouped[date] == null) grouped[date] = [];
        grouped[date]!.add(tx);
      }

      final income = results[2] as double;
      final expense = results[3] as double;
      final savings = results[4] as double;
      final pendingDebt = results[9] as double;

      // Calcul du Score de Santé Financière (cohérent avec HomeScreen)
      // Score basé sur 3 composantes:
      // 1. Taux d'épargne (0-40 points): Épargne / Revenus
      // 2. Ratio dette (0-30 points): inversement proportionnel aux dettes
      // 3. Ratio dépenses (0-30 points): si dépenses < revenus = bon

      double savingsScore = 0;
      double expenseScore = 0;
      double debtScore = 30; // Score max de base si pas de dette

      if (income > 0) {
        // Taux d'épargne : 20% = score max (40 points)
        final savingsRate = savings / income;
        savingsScore = (savingsRate * 200).clamp(0, 40).toDouble();

        // Ratio dépenses : si dépenses < 80% des revenus = bon score
        final expenseRate = expense / income;
        expenseScore = ((1 - expenseRate) * 60).clamp(0, 30).toDouble();

        // Ratio dette : si dette < 30% des revenus = bon score
        final debtRatio = pendingDebt / income;
        debtScore = ((1 - debtRatio) * 30).clamp(0, 30).toDouble();
      } else {
        // Pas de revenu : score basé sur présence d'épargne
        if (savings > 0) {
          expenseScore = 15;
          savingsScore = 10;
        }
      }

      final totalScore = (savingsScore + debtScore + expenseScore)
          .round()
          .clamp(0, 100);

      if (mounted) {
        setState(() {
          _categoryStats = results[0] as List<CategoryStat>;
          _totalIncome = income;
          _totalExpense = expense;
          _totalSavings = savings;
          _prevIncome = results[5] as double;
          _prevExpense = results[6] as double;
          _totalPendingDebt = pendingDebt;
          _healthScore = totalScore;
          _groupedTransactions = grouped;
          _isLoading = false;
          _isBackgroundLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundLoading = false;
        });
      }
    }
  }

  // Suppression des anciennes méthodes de mois

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de transactions pour rafraîchir automatiquement
    ref.listen<AsyncValue<List<TransactionWithCategory>>>(
      transactionWithCategoryListProvider,
      (previous, next) {
        // Recharger les données quand les transactions changent
        if (previous != next && !_isLoading && !_isBackgroundLoading) {
          _loadData(showLoader: false);
        }
      },
    );
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Analyse Financière',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primaryColor,
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_isBackgroundLoading)
                        SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            backgroundColor: Colors.transparent,
                            minHeight: 2,
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildPeriodSelector(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildHealthScoreSection(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildOverviewSection(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildCategorySection(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                        sliver: _buildTimelineSliver(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalysisPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          String label;
          switch (period) {
            case AnalysisPeriod.sevenDays:
              label = '7 jours';
              break;
            case AnalysisPeriod.thisMonth:
              label = 'Ce mois';
              break;
            case AnalysisPeriod.threeMonths:
              label = '3 mois';
              break;
            case AnalysisPeriod.year:
              label = 'Cette année';
              break;
          }

          return GestureDetector(
            onTap: () {
              if (_isBackgroundLoading) return;
              HapticFeedback.lightImpact();
              setState(() => _selectedPeriod = period);
              _loadData(showLoader: false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthScoreSection() {
    return HealthScoreCard(healthScore: _healthScore);
  }

  Widget _buildOverviewSection() {
    final balance = _totalIncome - _totalExpense;
    final incomeTrend = _prevIncome > 0
        ? ((_totalIncome - _prevIncome) / _prevIncome * 100)
        : 0.0;
    final expenseTrend = _prevExpense > 0
        ? ((_totalExpense - _prevExpense) / _prevExpense * 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Résumé financier',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildBalanceCard(
                label: 'Solde Net',
                amount: balance,
                color: balance >= 0 ? AppTheme.success : AppTheme.error,
                isMain: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                label: 'Revenus',
                amount: _totalIncome,
                trend: incomeTrend,
                color: AppTheme.success,
                icon: FontAwesomeIcons.arrowTrendUp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                label: 'Dépenses',
                amount: _totalExpense,
                trend: expenseTrend,
                color: AppTheme.error,
                icon: FontAwesomeIcons.arrowTrendDown,
                invertTrendColor: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniStatCard(
                label: 'Épargne',
                amount: _totalSavings,
                trend: 0,
                color: AppTheme.secondaryColor,
                icon: FontAwesomeIcons.piggyBank,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                label: 'Dettes',
                amount: _totalPendingDebt,
                trend: 0,
                color: AppTheme.primaryColor,
                icon: FontAwesomeIcons.creditCard,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard({
    required String label,
    required double amount,
    required Color color,
    bool isMain = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMain ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isMain ? AppTheme.primaryColor : Colors.black).withOpacity(
              0.1,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMain
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isMain
                  ? Colors.white.withOpacity(0.8)
                  : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${amount >= 0 ? '+' : ''}${_currencyFormat.format(amount)} F',
            style: TextStyle(
              color: isMain ? Colors.white : color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required double amount,
    required double trend,
    required Color color,
    required IconData icon,
    bool invertTrendColor = false,
  }) {
    final showTrend = trend.abs() > 0.1;
    final isTrendGood = invertTrendColor ? trend <= 0 : trend >= 0;
    final trendColor = isTrendGood ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(icon, color: AppTheme.primaryColor, size: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_currencyFormat.format(amount)} F',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (showTrend) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  trend >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: trendColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${trend.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    if (_categoryStats.isEmpty) return const SizedBox.shrink();
    final totalExpenses = _categoryStats.fold<double>(
      0,
      (sum, s) => sum + s.totalAmount,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des dépenses',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(),
                    centerSpaceRadius: 40,
                    sectionsSpace: 3,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: _categoryStats.take(4).map((stat) {
                    final percentage = totalExpenses > 0
                        ? (stat.totalAmount / totalExpenses)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stat.categoryName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              color: _parseColor(stat.color),
                              backgroundColor: Colors.grey.shade50,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSliver() {
    if (_groupedTransactions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final sortedDates = _groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Historique des opérations',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        final dateIndex = index - 1;
        if (dateIndex >= sortedDates.length) return null;

        final date = sortedDates[dateIndex];
        final txs = _groupedTransactions[date]!;
        final isToday = DateUtils.isSameDay(date, DateTime.now());
        final dateLabel = isToday
            ? "Aujourd'hui"
            : DateFormat('EEEE d MMMM', 'fr_FR').format(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Text(
                dateLabel[0].toUpperCase() + dateLabel.substring(1),
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...txs.map((tx) => _buildFluidTransactionTile(tx)),
          ],
        );
      }, childCount: sortedDates.length + 1),
    );
  }

  Widget _buildFluidTransactionTile(TransactionWithCategory txWithCategory) {
    final tx = txWithCategory.transaction;
    final category = txWithCategory.category;
    final isIncome = tx.type == 'income';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                _getCategoryIcon(category?.iconKey),
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
                  tx.merchantName ?? 'Transaction',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  category?.name ?? 'Divers',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_currencyFormat.format(tx.amount)} F',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isIncome ? AppTheme.success : AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopExpensesSection() {
    return const SizedBox.shrink(); // Méthode obsolete remplacée par Timeline
  }

  Widget _buildTopExpenseTile(TransactionWithCategory tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FaIcon(
                _getCategoryIcon(tx.category?.iconKey),
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.transaction.merchantName ?? 'Transaction',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.category?.name ?? 'Divers',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${_currencyFormat.format(tx.transaction.amount)} F',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.error,
                  fontSize: 15,
                ),
              ),
              Text(
                DateFormat('dd MMM', 'fr_FR').format(tx.transaction.date),
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.receipt;
    switch (iconKey) {
      case 'utensils':
        return FontAwesomeIcons.utensils;
      case 'taxi':
        return FontAwesomeIcons.taxi;
      case 'bolt':
        return FontAwesomeIcons.bolt;
      case 'heartPulse':
        return FontAwesomeIcons.heartPulse;
      case 'exchangeAlt':
        return FontAwesomeIcons.rightLeft;
      case 'gamepad':
        return FontAwesomeIcons.gamepad;
      case 'piggyBank':
        return FontAwesomeIcons.piggyBank;
      case 'question':
        return FontAwesomeIcons.receipt;
      case 'moneyBill':
        return FontAwesomeIcons.moneyBill;
      case 'wallet':
        return FontAwesomeIcons.wallet;
      default:
        return FontAwesomeIcons.receipt;
    }
  }

  List<PieChartSectionData> _buildPieSections() {
    return _categoryStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      final isTouched = index == _touchedPieIndex;
      return PieChartSectionData(
        value: stat.totalAmount,
        title: '',
        color: _parseColor(stat.color),
        radius: isTouched ? 32 : 28,
      );
    }).toList();
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
