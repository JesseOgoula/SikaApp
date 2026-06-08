import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/budgets/data/repositories/budget_repository.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';

/// Ecran de gestion du budget mensuel global
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
    final globalBudgetAsync = ref.watch(globalBudgetProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Budget Mensuel',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: globalBudgetAsync.when(
        data: (globalBudget) {
          if (globalBudget == null) {
            return _buildEmptyState(categoriesAsync);
          }
          return _buildBudgetView(globalBudget, categoriesAsync);
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
      floatingActionButton: globalBudgetAsync.valueOrNull == null
          ? FloatingActionButton(
              onPressed: () => _showGlobalBudgetSheet(null, categoriesAsync),
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
            'Aucun budget defini',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Definissez un budget mensuel global\npour controler vos depenses',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showGlobalBudgetSheet(null, categoriesAsync),
            icon: const Icon(Icons.add),
            label: const Text('Creer un budget'),
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

  Widget _buildBudgetView(
    GlobalBudget globalBudget,
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    final percentUsed = globalBudget.percentUsed.clamp(0.0, 100.0);
    final isOver = globalBudget.isOverBudget;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- Carte principale du budget global ---
        GestureDetector(
          onTap: () => _showGlobalBudgetSheet(globalBudget, categoriesAsync),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isOver
                  ? LinearGradient(
                      colors: [
                        AppTheme.error,
                        AppTheme.error.withValues(alpha: 0.85),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                      'Budget Mensuel Global',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_currencyFormat.format(globalBudget.totalSpent)} / ${_currencyFormat.format(globalBudget.amount)} F',
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
                    value: (percentUsed / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    color: Colors.white,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentUsed.toStringAsFixed(0)}% utilise',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      globalBudget.remaining >= 0
                          ? 'Reste: ${_currencyFormat.format(globalBudget.remaining)} F'
                          : 'Depasse de: ${_currencyFormat.format(-globalBudget.remaining)} F',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // --- Sous-budgets ---
        if (globalBudget.subBudgets.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Repartition par categorie',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...globalBudget.subBudgets.map((sub) => _buildSubBudgetCard(sub)),
        ],

        // --- Info non alloue ---
        if (globalBudget.unallocatedAmount > 0 &&
            globalBudget.subBudgets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Non alloue: ${_currencyFormat.format(globalBudget.unallocatedAmount)} F',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubBudgetCard(SubBudget sub) {
    final percent = sub.percentUsed.clamp(0.0, 100.0);
    final progressColor = sub.isOverBudget
        ? AppTheme.error
        : AppTheme.primaryColor;
    final iconKey = sub.category?.iconKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: FaIcon(
                    _getCategoryIcon(iconKey),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sub.categoryName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (sub.isOverBudget)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Depasse!',
                              style: TextStyle(
                                color: AppTheme.error,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormat.format(sub.currentSpent)} / ${_currencyFormat.format(sub.amount)} F',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              color: progressColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub.remaining >= 0
                    ? 'Reste: ${_currencyFormat.format(sub.remaining)} F'
                    : 'Depasse de: ${_currencyFormat.format(-sub.remaining)} F',
                style: TextStyle(
                  color: sub.remaining >= 0 ? AppTheme.success : AppTheme.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom sheet pour configurer le budget global
  void _showGlobalBudgetSheet(
    GlobalBudget? existing,
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    categoriesAsync.whenData((categories) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _GlobalBudgetBottomSheet(
          existing: existing,
          categories: categories.where((c) => c.id != 'cat-epargne').toList(),
          onSave: (totalAmount, subBudgets) async {
            final repo = ref.read(budgetRepositoryProvider);

            final globalId = await repo.createOrUpdateGlobalBudget(totalAmount);

            // Supprimer les sous-budgets qui ne sont plus selectionnes
            if (existing != null) {
              for (final oldSub in existing.subBudgets) {
                if (!subBudgets.containsKey(oldSub.categoryId)) {
                  await repo.removeSubBudget(oldSub.budget.id);
                }
              }
            }

            // Ajouter/mettre a jour les sous-budgets
            for (final entry in subBudgets.entries) {
              final cat = categories.firstWhere((c) => c.id == entry.key);
              await repo.addOrUpdateSubBudget(
                parentBudgetId: globalId,
                categoryId: entry.key,
                categoryName: cat.name,
                amount: entry.value,
              );
            }

            ref.invalidate(globalBudgetProvider);
            if (mounted) Navigator.pop(ctx);
          },
          onDelete: existing != null
              ? () async {
                  final repo = ref.read(budgetRepositoryProvider);
                  await repo.deleteGlobalBudget(existing.budget.id);
                  ref.invalidate(globalBudgetProvider);
                  if (mounted) Navigator.pop(ctx);
                }
              : null,
        ),
      );
    });
  }

  FaIconData _getCategoryIcon(String? iconKey) {
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

/// Bottom Sheet pour configurer le budget mensuel global
/// Layout: Header fixe -> Contenu scrollable -> Montant selectionne + NumberPad fixe en bas
class _GlobalBudgetBottomSheet extends StatefulWidget {
  final GlobalBudget? existing;
  final List<CategoriesTableData> categories;
  final Future<void> Function(
    double totalAmount,
    Map<String, double> subBudgets,
  )
  onSave;
  final Future<void> Function()? onDelete;

  const _GlobalBudgetBottomSheet({
    this.existing,
    required this.categories,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_GlobalBudgetBottomSheet> createState() =>
      _GlobalBudgetBottomSheetState();
}

class _GlobalBudgetBottomSheetState extends State<_GlobalBudgetBottomSheet> {
  late TextEditingController _totalController;
  final Map<String, TextEditingController> _subControllers = {};
  final Set<String> _selectedCategories = {};
  bool _isLoading = false;
  bool _editingTotal = true;
  String? _editingSubCategoryId;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.amount.toStringAsFixed(0)
          : '',
    );

    if (widget.existing != null) {
      _editingTotal = false;
      for (final sub in widget.existing!.subBudgets) {
        _selectedCategories.add(sub.categoryId);
        _subControllers[sub.categoryId] = TextEditingController(
          text: sub.amount.toStringAsFixed(0),
        );
      }
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (final c in _subControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount {
    return double.tryParse(_totalController.text.replaceAll(' ', '')) ?? 0;
  }

  double get _allocatedAmount {
    double total = 0;
    for (final catId in _selectedCategories) {
      final ctrl = _subControllers[catId];
      if (ctrl != null) {
        total += double.tryParse(ctrl.text.replaceAll(' ', '')) ?? 0;
      }
    }
    return total;
  }

  /// Controller actif (total ou sous-categorie)
  TextEditingController get _activeController {
    if (_editingTotal) return _totalController;
    if (_editingSubCategoryId != null) {
      return _subControllers.putIfAbsent(
        _editingSubCategoryId!,
        () => TextEditingController(),
      );
    }
    return _totalController;
  }

  /// Label du champ en cours
  String get _activeLabel {
    if (_editingTotal) return 'Budget total mensuel';
    if (_editingSubCategoryId != null) {
      final cat = widget.categories
          .where((c) => c.id == _editingSubCategoryId)
          .firstOrNull;
      return cat?.name ?? 'Categorie';
    }
    return '';
  }

  /// Valeur du champ actif
  double get _activeAmount {
    final text = _activeController.text.replaceAll(' ', '');
    return double.tryParse(text) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _totalAmount - _allocatedAmount;
    final showNumberPad = _editingTotal || _editingSubCategoryId != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existing != null
                      ? 'Modifier le budget'
                      : 'Budget Mensuel Global',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (widget.onDelete != null)
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            await widget.onDelete!();
                          },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.error,
                    ),
                  ),
              ],
            ),
          ),

          // Contenu scrollable (categories)
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              shrinkWrap: true,
              children: [
                // Budget total (tap pour editer)
                GestureDetector(
                  onTap: () => setState(() {
                    _editingTotal = true;
                    _editingSubCategoryId = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _editingTotal
                          ? AppTheme.primaryColor.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _editingTotal
                            ? AppTheme.primaryColor
                            : Colors.grey.shade300,
                        width: _editingTotal ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Budget total',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_totalAmount > 0 ? _currencyFormat.format(_totalAmount) : '0'} F',
                          style: TextStyle(
                            color: _editingTotal
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Section repartition (visible quand total > 0)
                if (_totalAmount > 0 && !_editingTotal) ...[
                  const SizedBox(height: 16),

                  // Info allocation
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: remaining >= 0
                          ? AppTheme.primaryColor.withValues(alpha: 0.06)
                          : AppTheme.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          remaining >= 0
                              ? Icons.info_outline
                              : Icons.warning_amber_rounded,
                          color: remaining >= 0
                              ? AppTheme.primaryColor
                              : AppTheme.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          remaining >= 0
                              ? 'Non alloue: ${_currencyFormat.format(remaining)} F'
                              : 'Depassement: ${_currencyFormat.format(-remaining)} F',
                          style: TextStyle(
                            color: remaining >= 0
                                ? AppTheme.primaryColor
                                : AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Repartition par categorie',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Categories list
                  ...widget.categories.map((cat) {
                    final isSelected = _selectedCategories.contains(cat.id);
                    final isEditing = _editingSubCategoryId == cat.id;
                    final controller = _subControllers.putIfAbsent(
                      cat.id,
                      () => TextEditingController(),
                    );
                    final subAmount =
                        double.tryParse(controller.text.replaceAll(' ', '')) ??
                        0;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingTotal = false;
                          if (!isSelected) {
                            _selectedCategories.add(cat.id);
                          }
                          _editingSubCategoryId = cat.id;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isEditing
                              ? AppTheme.primaryColor.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: isEditing
                              ? Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedCategories.add(cat.id);
                                      _editingSubCategoryId = cat.id;
                                      _editingTotal = false;
                                    } else {
                                      _selectedCategories.remove(cat.id);
                                      controller.clear();
                                      if (_editingSubCategoryId == cat.id) {
                                        _editingSubCategoryId = null;
                                      }
                                    }
                                  });
                                },
                                activeColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Text(
                                subAmount > 0
                                    ? '${_currencyFormat.format(subAmount)} F'
                                    : '\u2014',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isEditing
                                      ? AppTheme.primaryColor
                                      : subAmount > 0
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Zone fixe en bas : Montant actif + NumberPad + Bouton
          if (showNumberPad) ...[
            const Divider(height: 1),

            // Montant en cours
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Text(
                    _activeLabel,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_activeAmount > 0 ? _currencyFormat.format(_activeAmount) : '0'} F',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            // NumberPad
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: NumberPad(
                onKeyPressed: (key) {
                  setState(() => _activeController.text += key);
                },
                onBackspace: () {
                  final ctrl = _activeController;
                  if (ctrl.text.isNotEmpty) {
                    setState(() {
                      ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
                    });
                  }
                },
              ),
            ),

            // Bouton principal
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: _editingTotal
                    ? ElevatedButton(
                        onPressed: _totalAmount > 0
                            ? () => setState(() {
                                _editingTotal = false;
                                _editingSubCategoryId = null;
                              })
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Repartir le budget',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: (_isLoading || _totalAmount <= 0)
                            ? null
                            : _saveGlobalBudget,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            : Text(
                                widget.existing != null
                                    ? 'Mettre a jour'
                                    : 'Definir le budget',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
              ),
            ),
          ] else ...[
            // Pas de NumberPad : juste le bouton sauvegarder
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isLoading || _totalAmount <= 0)
                      ? null
                      : _saveGlobalBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      : Text(
                          widget.existing != null
                              ? 'Mettre a jour'
                              : 'Definir le budget',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveGlobalBudget() async {
    setState(() => _isLoading = true);

    final subBudgets = <String, double>{};
    for (final catId in _selectedCategories) {
      final ctrl = _subControllers[catId];
      if (ctrl != null) {
        final amount = double.tryParse(ctrl.text.replaceAll(' ', '')) ?? 0;
        if (amount > 0) {
          subBudgets[catId] = amount;
        }
      }
    }

    await widget.onSave(_totalAmount, subBudgets);
  }
}
