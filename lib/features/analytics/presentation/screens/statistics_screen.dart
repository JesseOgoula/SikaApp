import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:sika_app/core/database/app_database.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:sika_app/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:sika_app/features/analytics/domain/entities/category_stat.dart';
import 'package:sika_app/features/analytics/domain/entities/daily_summary.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/debts/data/providers/debt_providers.dart';

/// Dashboard Analytics - Redesign Premium avec Financial Health Score
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _selectedMonth = DateTime.now();
  final int _touchedPieIndex = -1;

  // Données
  List<CategoryStat> _categoryStats = [];
  List<DailySummary> _dailySummaries = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalSavings = 0;
  double _prevIncome = 0;
  double _prevExpense = 0;
  double _totalPendingDebt = 0;
  int _healthScore = 0;
  List<TransactionWithCategory> _topTransactions = [];
  bool _isLoading = true;

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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final repo = TransactionRepositoryImpl(db);
      final goalRepo = ref.read(goalRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);

      final results = await Future.wait([
        repo.getExpensesByCategory(_selectedMonth),
        repo.getDailySummary(_selectedMonth),
        repo.getTotalIncome(_selectedMonth),
        repo.getTotalExpense(_selectedMonth),
        goalRepo.getTotalSavedAmount(),
        repo.getTotalIncome(prevMonth),
        repo.getTotalExpense(prevMonth),
        db.select(db.transactionsTable).join([
          leftOuterJoin(
            db.categoriesTable,
            db.categoriesTable.id.equalsExp(db.transactionsTable.categoryId),
          ),
        ]).get(),
        debtRepo.getTotalPendingDebt(),
      ]);

      final allTxs = results[7] as List<TypedResult>;
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final filteredTop = allTxs
          .map(
            (row) => TransactionWithCategory(
              transaction: row.readTable(db.transactionsTable),
              category: row.readTableOrNull(db.categoriesTable),
            ),
          )
          .where(
            (t) =>
                t.transaction.type == 'expense' &&
                t.transaction.date.isAfter(
                  monthStart.subtract(const Duration(seconds: 1)),
                ) &&
                t.transaction.date.isBefore(
                  monthEnd.add(const Duration(seconds: 1)),
                ),
          )
          .toList();
      filteredTop.sort(
        (a, b) => b.transaction.amount.compareTo(a.transaction.amount),
      );

      final income = results[2] as double;
      final expense = results[3] as double;
      final savings = results[4] as double;
      final pendingDebt = results[8] as double;

      // Calcul du Score de Santé Financière (0-100)
      // 1. Taux d'épargne (40 pts max)
      final savingsRate = income > 0 ? (savings / income * 100) : 0.0;
      final savingsScore = (savingsRate * 2.0).clamp(0, 40).toDouble();

      // 2. Gestion de la dette (30 pts max)
      final debtRatio = income > 0 ? (pendingDebt / income) : 0.0;
      final debtScore = (30 - (debtRatio * 50)).clamp(0, 30).toDouble();

      // 3. Liquidité / Urgence (30 pts max)
      final liquidityRatio = expense > 0 ? (savings / expense) : 0.0;
      final liquidityScore = (liquidityRatio * 10).clamp(0, 30).toDouble();

      final totalScore = (savingsScore + debtScore + liquidityScore).round();

      if (mounted) {
        setState(() {
          _categoryStats = results[0] as List<CategoryStat>;
          _dailySummaries = results[1] as List<DailySummary>;
          _totalIncome = income;
          _totalExpense = expense;
          _totalSavings = savings;
          _prevIncome = results[5] as double;
          _prevExpense = results[6] as double;
          _totalPendingDebt = pendingDebt;
          _healthScore = totalScore;
          _topTransactions = filteredTop.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthSelector(),
                    const SizedBox(height: 24),
                    _buildHealthScoreSection(),
                    const SizedBox(height: 24),
                    _buildOverviewSection(),
                    const SizedBox(height: 24),
                    _buildTrendSection(),
                    const SizedBox(height: 24),
                    _buildCategorySection(),
                    const SizedBox(height: 24),
                    _buildTopExpensesSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
            onPressed: _previousMonth,
          ),
          Text(
            monthName[0].toUpperCase() + monthName.substring(1),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreSection() {
    Color scoreColor;
    String label;
    String description;

    if (_healthScore >= 80) {
      scoreColor = AppTheme.success;
      label = 'Excellent';
      description = 'Votre santé financière est au top ! Continuez ainsi.';
    } else if (_healthScore >= 60) {
      scoreColor = AppTheme.primaryColor;
      label = 'Bonne';
      description =
          'Vous gérez bien, mais quelques ajustements sont possibles.';
    } else if (_healthScore >= 40) {
      scoreColor = Colors.orange;
      label = 'Moyenne';
      description = 'Attention à vos dépenses. Essayez d\'épargner plus.';
    } else {
      scoreColor = AppTheme.error;
      label = 'Critique';
      description = 'Action requise ! Revoyez votre budget et vos dettes.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scoreColor.withOpacity(0.15),
            scoreColor.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scoreColor.withOpacity(0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _healthScore / 100,
                  strokeWidth: 8,
                  backgroundColor: scoreColor.withOpacity(0.1),
                  color: scoreColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_healthScore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Score de santé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                label: 'Dépenses',
                amount: _totalExpense,
                trend: expenseTrend,
                color: AppTheme.error,
                icon: Icons.north_east_rounded,
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
                color: Colors.blue,
                icon: Icons.savings_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniStatCard(
                label: 'Dettes',
                amount: _totalPendingDebt,
                trend: 0,
                color: Colors.orange,
                icon: Icons.credit_card_off_outlined,
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
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
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

  Widget _buildTrendSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Flux financier',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  _buildTrendLegend('Revenus', AppTheme.success),
                  const SizedBox(width: 12),
                  _buildTrendLegend('Dépenses', AppTheme.primaryColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _dailySummaries.isEmpty
                ? const Center(child: Text('Aucune donnée'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              if (value % 7 != 0) return const SizedBox();
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withOpacity(
                                    0.5,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _dailySummaries
                              .map(
                                (s) => FlSpot(s.day.toDouble(), s.totalIncome),
                              )
                              .toList(),
                          isCurved: true,
                          color: AppTheme.success,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.success.withOpacity(0.05),
                          ),
                        ),
                        LineChartBarData(
                          spots: _dailySummaries
                              .map(
                                (s) => FlSpot(s.day.toDouble(), s.totalExpense),
                              )
                              .toList(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withOpacity(0.05),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.primaryColor,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${_currencyFormat.format(spot.y)} F',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
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

  Widget _buildTopExpensesSection() {
    if (_topTransactions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grosses dépenses',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ..._topTransactions.map((tx) => _buildTopExpenseTile(tx)),
      ],
    );
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _parseColor(tx.category?.color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                _getCategoryIcon(tx.category?.iconKey),
                color: _parseColor(tx.category?.color),
                size: 22,
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
    switch (iconKey) {
      case 'utensils':
        return Icons.restaurant;
      case 'taxi':
        return Icons.local_taxi;
      case 'bolt':
        return Icons.bolt;
      case 'heartPulse':
        return Icons.favorite;
      case 'exchangeAlt':
        return Icons.swap_horiz;
      case 'gamepad':
        return Icons.sports_esports;
      case 'piggyBank':
        return Icons.savings;
      default:
        return Icons.category;
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
