import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';

/// Écran d'ajout manuel - Design Neo-Bank Premium
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _transactionType = 'expense';
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouvelle Transaction',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // === MONTANT (La Star) ===
                    _buildAmountSection(),

                    const SizedBox(height: 32),

                    // === TYPE SELECTOR ===
                    _buildTypeSelector(),

                    const SizedBox(height: 28),

                    // === CATÉGORIES ===
                    _buildCategorySection(categoriesAsync),

                    const SizedBox(height: 28),

                    // === DATE ===
                    _buildDateField(),

                    const SizedBox(height: 16),

                    // === NOTE ===
                    _buildNoteField(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // === BOUTON ENREGISTRER ===
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      children: [
        Text(
          'Combien ?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            IntrinsicWidth(
              child: TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '';
                  final amount = double.tryParse(value.replaceAll(' ', ''));
                  if (amount == null || amount <= 0) return '';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'FCFA',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
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
        children: [
          _buildTypeTab('expense', 'Dépense', AppTheme.error),
          _buildTypeTab('income', 'Revenu', AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type, String label, Color color) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transactionType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    AsyncValue<List<CategoriesTableData>> categoriesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        categoriesAsync.when(
          data: (categories) => SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _buildCategoryItem(cat);
              },
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(CategoriesTableData category) {
    final isSelected = _selectedCategoryId == category.id;
    final color = _parseColor(category.color) ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = category.id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE5E7EB),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: FaIcon(
                _getCategoryIcon(category.iconKey),
                color: isSelected ? color : AppTheme.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: TextStyle(
              color: isSelected ? color : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: AppTheme.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE dd MMMM', 'fr_FR').format(_selectedDate),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.edit,
              color: AppTheme.secondaryColor.withOpacity(0.8),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _noteController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ajouter une note...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Enregistrer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
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

  Color? _parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#')) return null;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez entrer un montant'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(' ', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Montant invalide'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final note = _noteController.text.trim();

      final companion = TransactionsTableCompanion(
        amount: Value(amount),
        type: Value(_transactionType),
        merchantName: Value(note.isNotEmpty ? note : 'Transaction manuelle'),
        categoryId: _selectedCategoryId != null
            ? Value(_selectedCategoryId!)
            : const Value.absent(),
        date: Value(_selectedDate),
        smsSender: const Value('MANUAL'),
        smsRawContent: const Value(''),
        externalId: const Value.absent(),
        isAiCategorized: const Value(false),
        syncStatus: const Value(0),
        validationStatus: const Value(1),
      );

      final repo = ref.read(transactionRepositoryProvider);
      await repo.addManualTransaction(companion);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
