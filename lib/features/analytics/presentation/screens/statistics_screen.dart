import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/analytics/domain/entities/category_stat.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';

/// Écran de statistiques - Design Neo-Bank avec PieChart
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  DateTime _selectedMonth = DateTime.now();
  int _touchedIndex = -1;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analyse',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<CategoryStat>>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? [];
          final totalExpenses = stats.fold<double>(
            0,
            (sum, stat) => sum + stat.totalAmount,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Month Selector
                _buildMonthSelector(),

                const SizedBox(height: 24),

                // Pie Chart Card
                _buildChartCard(stats, totalExpenses),

                const SizedBox(height: 24),

                // Category Legend
                _buildLegend(stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<CategoryStat>> _loadStats() {
    final repo = ref.read(transactionRepositoryProvider);
    return repo.getExpensesByCategory(_selectedMonth);
  }

  Widget _buildMonthSelector() {
    final monthFormat = DateFormat('MMMM yyyy', 'fr_FR');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            monthFormat.format(_selectedMonth).toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
            onPressed:
                _selectedMonth.month < DateTime.now().month ||
                    _selectedMonth.year < DateTime.now().year
                ? () {
                    setState(() {
                      _selectedMonth = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month + 1,
                      );
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<CategoryStat> stats, double total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: stats.isEmpty
                ? _buildEmptyChart()
                : PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: _buildChartSections(stats),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total Dépenses',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(total),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune dépense\nce mois-ci',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(List<CategoryStat> stats) {
    return stats.asMap().entries.map((entry) {
      final index = entry.key;
      final stat = entry.value;
      final isTouched = index == _touchedIndex;
      final color = _parseColor(stat.color) ?? _getDefaultColor(index);

      return PieChartSectionData(
        color: color,
        value: stat.totalAmount,
        title: isTouched ? '${stat.percentage.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 45 : 35,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: isTouched ? null : null,
      );
    }).toList();
  }

  Widget _buildLegend(List<CategoryStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Par catégorie',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...stats.asMap().entries.map((entry) {
            final index = entry.key;
            final stat = entry.value;
            final color = _parseColor(stat.color) ?? _getDefaultColor(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: FaIcon(
                        _getCategoryIcon(stat.iconKey),
                        color: color,
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
                          stat.categoryName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${stat.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _currencyFormat.format(stat.totalAmount),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getDefaultColor(int index) {
    const colors = [
      Color(0xFF1A237E),
      Color(0xFFE91E63),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFF795548),
    ];
    return colors[index % colors.length];
  }

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#')) return null;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  IconData _getCategoryIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.question;
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
      default:
        return FontAwesomeIcons.tag;
    }
  }
}
