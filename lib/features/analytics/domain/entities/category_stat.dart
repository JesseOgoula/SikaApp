/// Statistique par catégorie pour les graphiques
class CategoryStat {
  final String categoryId;
  final String categoryName;
  final String? iconKey;
  final String? color;
  final double totalAmount;
  final double percentage;

  const CategoryStat({
    required this.categoryId,
    required this.categoryName,
    this.iconKey,
    this.color,
    required this.totalAmount,
    required this.percentage,
  });

  @override
  String toString() =>
      'CategoryStat($categoryName: $totalAmount FCFA, $percentage%)';
}
