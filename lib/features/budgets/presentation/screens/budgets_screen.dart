import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/budgets/data/repositories/budget_repository.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';

/// Écran de gestion des budgets par catégorie
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(categoryBudgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Budgets',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return _buildEmptyState(categoriesAsync);
          }
          return _buildBudgetList(budgets, categoriesAsync);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur: $e',
            style: const TextStyle(color: AppTheme.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetSheet(categoriesAsync),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun budget défini',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Définissez des limites de dépenses par catégorie',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddBudgetSheet(categoriesAsync),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un budget'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetList(
    List<CategoryBudget> budgets,
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    // Calculer les totaux
    double totalBudget = budgets.fold(0, (sum, b) => sum + b.budgetLimit);
    double totalSpent = budgets.fold(0, (sum, b) => sum + b.currentSpent);
    int overBudgetCount = budgets.where((b) => b.isOverBudget).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Résumé global
        _buildSummaryCard(totalBudget, totalSpent, overBudgetCount),
        const SizedBox(height: 24),

        // Liste des budgets
        const Text(
          'Budgets par catégorie',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        ...budgets.map((budget) => _buildBudgetCard(budget, categoriesAsync)),
      ],
    );
  }

  Widget _buildSummaryCard(
    double totalBudget,
    double totalSpent,
    int overBudgetCount,
  ) {
    final percentUsed = totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
    final isOver = totalSpent > totalBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOver
            ? LinearGradient(
                colors: [AppTheme.error, AppTheme.error.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Mensuel',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (overBudgetCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$overBudgetCount dépassé(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_currencyFormat.format(totalSpent)} / ${_currencyFormat.format(totalBudget)} F',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentUsed.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.3),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(percentUsed * 100).toStringAsFixed(0)}% utilisé',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
    CategoryBudget budget,
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    final color = _parseColor(budget.color);
    // Use primaryColor for normal progress, error for over budget
    final progressColor = budget.isOverBudget
        ? AppTheme.error
        : AppTheme.primaryColor;
    final percent = budget.percentUsed.clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: budget.isOverBudget
            ? Border.all(color: AppTheme.error.withOpacity(0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FaIcon(
                    _getCategoryIcon(budget.iconKey),
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          budget.categoryName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (budget.isOverBudget)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Dépassé!',
                              style: TextStyle(
                                color: AppTheme.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormat.format(budget.currentSpent)} / ${_currencyFormat.format(budget.budgetLimit)} F',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showEditBudgetSheet(budget, categoriesAsync),
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.grey.shade100,
              color: progressColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                budget.remaining >= 0
                    ? 'Reste: ${_currencyFormat.format(budget.remaining)} F'
                    : 'Dépassé de: ${_currencyFormat.format(-budget.remaining)} F',
                style: TextStyle(
                  color: budget.remaining >= 0
                      ? AppTheme.success
                      : AppTheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddBudgetSheet(
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    categoriesAsync.whenData((categories) {
      // Récupérer les IDs des catégories qui ont déjà un budget actif
      final budgetsAsync = ref.read(categoryBudgetsProvider);
      final budgetedCategoryIds = <String>{};
      budgetsAsync.whenData((budgets) {
        for (final b in budgets) {
          budgetedCategoryIds.add(b.category.id);
        }
      });

      // Filtrer : exclure celles avec un budget ET exclure Épargne
      final availableCategories = categories
          .where(
            (c) => !budgetedCategoryIds.contains(c.id) && c.id != 'cat-epargne',
          )
          .toList();

      if (availableCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les catégories ont déjà un budget'),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _AddBudgetBottomSheet(
          categories: availableCategories,
          onSave: (categoryId, amount) async {
            final repo = ref.read(budgetRepositoryProvider);
            await repo.setCategoryBudget(categoryId, amount);
            ref.invalidate(categoriesProvider);
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    });
  }

  void _showEditBudgetSheet(
    CategoryBudget budget,
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditBudgetBottomSheet(
        budget: budget,
        onSave: (amount) async {
          final repo = ref.read(budgetRepositoryProvider);
          await repo.setCategoryBudget(budget.category.id, amount);
          ref.invalidate(categoriesProvider);
          if (mounted) Navigator.pop(context);
        },
        onDelete: () async {
          final repo = ref.read(budgetRepositoryProvider);
          await repo.removeCategoryBudget(budget.category.id);
          ref.invalidate(categoriesProvider);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  IconData _getCategoryIcon(String? iconKey) {
    switch (iconKey) {
      case 'restaurant':
        return FontAwesomeIcons.utensils;
      case 'local_taxi':
        return FontAwesomeIcons.taxi;
      case 'local_hospital':
        return FontAwesomeIcons.hospital;
      case 'shopping_cart':
        return FontAwesomeIcons.cartShopping;
      case 'movie':
        return FontAwesomeIcons.film;
      case 'receipt':
        return FontAwesomeIcons.receipt;
      case 'savings':
        return FontAwesomeIcons.piggyBank;
      default:
        return FontAwesomeIcons.tag;
    }
  }
}

/// Bottom Sheet pour ajouter un nouveau budget
class _AddBudgetBottomSheet extends StatefulWidget {
  final List<CategoriesTableData> categories;
  final Future<void> Function(String categoryId, double amount) onSave;

  const _AddBudgetBottomSheet({required this.categories, required this.onSave});

  @override
  State<_AddBudgetBottomSheet> createState() => _AddBudgetBottomSheetState();
}

class _AddBudgetBottomSheetState extends State<_AddBudgetBottomSheet> {
  CategoriesTableData? _selectedCategory;
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nouveau Budget',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),

            // Dropdown catégorie
            DropdownButtonFormField<CategoriesTableData>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: widget.categories
                  .map(
                    (cat) =>
                        DropdownMenuItem(value: cat, child: Text(cat.name)),
                  )
                  .toList(),
              onChanged: (cat) => setState(() => _selectedCategory = cat),
            ),
            const SizedBox(height: 16),

            // Affichage du montant
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limite mensuelle',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_amountController.text.isEmpty ? '0' : _amountController.text} F',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // NumberPad personnalisé
            NumberPad(
              onKeyPressed: (key) {
                setState(() {
                  _amountController.text += key;
                });
              },
              onBackspace: () {
                if (_amountController.text.isNotEmpty) {
                  setState(() {
                    _amountController.text = _amountController.text.substring(
                      0,
                      _amountController.text.length - 1,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Définir le budget',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une catégorie')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrez un montant valide')));
      return;
    }

    setState(() => _isLoading = true);
    await widget.onSave(_selectedCategory!.id, amount);
  }
}

/// Bottom Sheet pour modifier un budget existant
class _EditBudgetBottomSheet extends StatefulWidget {
  final CategoryBudget budget;
  final Future<void> Function(double amount) onSave;
  final Future<void> Function() onDelete;

  const _EditBudgetBottomSheet({
    required this.budget,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditBudgetBottomSheet> createState() => _EditBudgetBottomSheetState();
}

class _EditBudgetBottomSheetState extends State<_EditBudgetBottomSheet> {
  late final TextEditingController _amountController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.budget.budgetLimit.toStringAsFixed(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Modifier: ${widget.budget.categoryName}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),

            // Affichage du montant
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limite mensuelle',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_amountController.text.isEmpty ? '0' : _amountController.text} F',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // NumberPad personnalisé
            NumberPad(
              onKeyPressed: (key) {
                setState(() {
                  _amountController.text += key;
                });
              },
              onBackspace: () {
                if (_amountController.text.isNotEmpty) {
                  setState(() {
                    _amountController.text = _amountController.text.substring(
                      0,
                      _amountController.text.length - 1,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            await widget.onDelete();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Supprimer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrez un montant valide')));
      return;
    }

    setState(() => _isLoading = true);
    await widget.onSave(amount);
  }
}
