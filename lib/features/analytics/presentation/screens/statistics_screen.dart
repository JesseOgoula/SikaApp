import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:sika_app/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:sika_app/features/analytics/domain/entities/category_stat.dart';
import 'package:sika_app/features/analytics/domain/entities/daily_summary.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';

/// Dashboard Analytics - Style moderne minimaliste
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _selectedMonth = DateTime.now();
  int _touchedPieIndex = -1;

  // Données
  List<CategoryStat> _categoryStats = [];
  List<DailySummary> _dailySummaries = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalSavings = 0;
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
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final repo = TransactionRepositoryImpl(db);
      final goalRepo = ref.read(goalRepositoryProvider);

      final results = await Future.wait([
        repo.getExpensesByCategory(_selectedMonth),
        repo.getDailySummary(_selectedMonth),
        repo.getTotalIncome(_selectedMonth),
        repo.getTotalExpense(_selectedMonth),
        goalRepo.getTotalSavedAmount(),
      ]);

      setState(() {
        _categoryStats = results[0] as List<CategoryStat>;
        _dailySummaries = results[1] as List<DailySummary>;
        _totalIncome = results[2] as double;
        _totalExpense = results[3] as double;
        _totalSavings = results[4] as double;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
          'Statistiques',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sélecteur de mois
                    _buildMonthSelector(),
                    const SizedBox(height: 24),

                    // Résumé du mois
                    _buildSummaryCard(),
                    const SizedBox(height: 20),

                    // Graphique barres
                    _buildBarChartCard(),
                    const SizedBox(height: 20),

                    // Répartition
                    _buildCategoryCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthSelector() {
    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(_selectedMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.chevron_left,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          onPressed: _previousMonth,
        ),
        Text(
          monthName[0].toUpperCase() + monthName.substring(1),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.chevron_right,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final balance = _totalIncome - _totalExpense;
    final savingsRate = _totalIncome > 0
        ? (_totalSavings / _totalIncome * 100).clamp(0, 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Solde du mois',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              Text(
                '${balance >= 0 ? '+' : ''}${_currencyFormat.format(balance)} FCFA',
                style: TextStyle(
                  color: balance >= 0 ? AppTheme.success : AppTheme.error,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Revenus / Dépenses
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Revenus',
                  amount: _totalIncome,
                  icon: Icons.arrow_downward,
                  isPositive: true,
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey[200]),
              Expanded(
                child: _buildStatItem(
                  label: 'Dépenses',
                  amount: _totalExpense,
                  icon: Icons.arrow_upward,
                  isPositive: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Taux d'épargne
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.piggyBank,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Taux d\'épargne',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${savingsRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required double amount,
    required IconData icon,
    required bool isPositive,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isPositive
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isPositive ? AppTheme.success : AppTheme.error,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${_currencyFormat.format(amount)} F',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activité',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: _dailySummaries.isEmpty
                ? Center(
                    child: Text(
                      'Aucune donnée',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= _dailySummaries.length) {
                                return const SizedBox();
                              }
                              final day = _dailySummaries[value.toInt()].day;
                              // Afficher seulement certains jours
                              if (_dailySummaries.length > 10 &&
                                  value.toInt() % 3 != 0) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
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
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroups(),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot(
                AppTheme.primaryColor.withOpacity(0.7),
                'Revenus',
              ),
              const SizedBox(width: 20),
              _buildLegendDot(AppTheme.primaryColor, 'Dépenses'),
            ],
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return _dailySummaries.asMap().entries.map((entry) {
      final index = entry.key;
      final summary = entry.value;
      final total = summary.totalIncome + summary.totalExpense;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: total,
            width: _dailySummaries.length > 15 ? 6 : 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            rodStackItems: [
              BarChartRodStackItem(
                0,
                summary.totalIncome,
                AppTheme.primaryColor.withOpacity(0.4),
              ),
              BarChartRodStackItem(
                summary.totalIncome,
                total,
                AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    double max = 0;
    for (final summary in _dailySummaries) {
      final total = summary.totalIncome + summary.totalExpense;
      if (total > max) max = total;
    }
    return max * 1.2;
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCategoryCard() {
    final totalExpenses = _categoryStats.fold<double>(
      0,
      (sum, s) => sum + s.totalAmount,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          if (_categoryStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Aucune dépense',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Row(
              children: [
                // PieChart
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: _buildPieSections(),
                      centerSpaceRadius: 30,
                      sectionsSpace: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Liste catégories
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _categoryStats.take(5).map((stat) {
                      final percentage = totalExpenses > 0
                          ? (stat.totalAmount / totalExpenses * 100)
                          : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _parseColor(stat.color),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stat.categoryName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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

  List<PieChartSectionData> _buildPieSections() {
    return _categoryStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      final isTouched = index == _touchedPieIndex;

      return PieChartSectionData(
        value: stat.totalAmount,
        title: '',
        color: _parseColor(stat.color),
        radius: isTouched ? 28 : 22,
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
