/// Résumé quotidien des transactions pour le dashboard
class DailySummary {
  final DateTime date;
  final double totalIncome;
  final double totalExpense;

  DailySummary({
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
  });

  /// Solde net du jour (revenus - dépenses)
  double get netBalance => totalIncome - totalExpense;

  /// Jour du mois (1-31)
  int get day => date.day;
}
