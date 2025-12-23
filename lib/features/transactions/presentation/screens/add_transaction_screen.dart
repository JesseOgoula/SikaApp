import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/text_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/category_icon_widget.dart';

/// Écran d'ajout manuel - Design Neo-Bank avec Keypad personnalisé
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _noteText = '';

  String _amountText = '';
  String _transactionType = 'expense';
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _showKeypad = false; // Clavier numérique caché par défaut
  bool _showTextPad = false; // Clavier texte caché par défaut

  @override
  void dispose() {
    super.dispose();
  }

  void _onKeyPressed(String key) {
    setState(() {
      // Ferme le TextPad si ouvert
      if (_showTextPad) _showTextPad = false;
      // Limite à 10 caractères
      if (_amountText.length < 10) {
        // Empêche plusieurs points
        if (key == '.' && _amountText.contains('.')) return;
        _amountText += key;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  void _onNoteKeyPressed(String key) {
    setState(() {
      // Ferme le NumberPad si ouvert
      if (_showKeypad) _showKeypad = false;
      _noteText += key;
    });
  }

  void _onNoteBackspace() {
    setState(() {
      if (_noteText.isNotEmpty) {
        _noteText = _noteText.substring(0, _noteText.length - 1);
      }
    });
  }

  void _onNoteDone() {
    setState(() => _showTextPad = false);
  }

  void _toggleTextPad() {
    setState(() {
      _showTextPad = !_showTextPad;
      if (_showTextPad) _showKeypad = false; // Ferme le NumberPad
    });
  }

  void _toggleKeypad() {
    setState(() {
      _showKeypad = !_showKeypad;
      if (_showKeypad) _showTextPad = false; // Ferme le TextPad
    });
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
        actions: const [SizedBox(width: 48)],
      ),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // === MONTANT (ReadOnly avec affichage formaté) ===
                  _buildAmountDisplay(),

                  const SizedBox(height: 24),

                  // === TYPE SELECTOR ===
                  _buildTypeSelector(),

                  const SizedBox(height: 20),

                  // === CATÉGORIES ===
                  _buildCategorySection(categoriesAsync),

                  const SizedBox(height: 20),

                  // === DATE ===
                  _buildDateField(),

                  const SizedBox(height: 12),

                  // === NOTE ===
                  _buildNoteField(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // === NUMBERPAD AVEC ANIMATION ===
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showKeypad
                ? AnimatedOpacity(
                    opacity: _showKeypad ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: NumberPad(
                      onKeyPressed: _onKeyPressed,
                      onBackspace: _onBackspace,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // === TEXTPAD AVEC ANIMATION ===
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showTextPad
                ? AnimatedOpacity(
                    opacity: _showTextPad ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: TextPad(
                      onKeyPressed: _onNoteKeyPressed,
                      onBackspace: _onNoteBackspace,
                      onDone: _onNoteDone,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // === BOUTON ENREGISTRER ===
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final displayAmount = _amountText.isEmpty ? '0' : _amountText;

    return GestureDetector(
      onTap: _toggleKeypad,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: _showKeypad
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: _showKeypad
              ? Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Combien ?',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showKeypad ? Icons.keyboard_hide : Icons.keyboard,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  displayAmount,
                  style: TextStyle(
                    color: _amountText.isEmpty
                        ? const Color(0xFFD1D5DB)
                        : AppTheme.textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
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
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontSize: 14,
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
              separatorBuilder: (_, __) => const SizedBox(width: 16),
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

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = category.id),
      child: Column(
        children: [
          CategoryIconWidget(
            iconKey: category.iconKey,
            isSelected: isSelected,
            size: 52,
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: TextStyle(
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_today,
                color: Colors.grey[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                DateFormat('EEEE dd MMMM', 'fr_FR').format(_selectedDate),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return GestureDetector(
      onTap: _toggleTextPad,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _showTextPad
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: _showTextPad
              ? Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  width: 1,
                )
              : null,
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
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit, color: Colors.grey[700], size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _noteText.isEmpty ? 'Ajouter une note...' : _noteText,
                style: TextStyle(
                  color: _noteText.isEmpty
                      ? Colors.grey[400]
                      : AppTheme.textPrimary,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              _showTextPad ? Icons.keyboard_hide : Icons.keyboard,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
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
    if (_amountText.isEmpty) {
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

    final amount = double.tryParse(_amountText);
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
      final note = _noteText.trim();

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
