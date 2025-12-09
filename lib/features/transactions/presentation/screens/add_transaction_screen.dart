import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';

/// Écran d'ajout manuel d'une transaction (cash, etc.)
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

  String _transactionType = 'expense'; // 'expense' ou 'income'
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
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouvelle Transaction',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === MONTANT ===
              const Text(
                'Montant',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  suffixText: 'FCFA',
                  suffixStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: const Color(0xFF1A1F38),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF00D9FF),
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  final amount = double.tryParse(value.replaceAll(' ', ''));
                  if (amount == null || amount <= 0) {
                    return 'Montant invalide';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // === TYPE (DÉPENSE / REVENU) ===
              const Text(
                'Type',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F38),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTypeButton(
                      'expense',
                      'Dépense',
                      Icons.arrow_upward,
                      Colors.redAccent,
                    ),
                    _buildTypeButton(
                      'income',
                      'Revenu',
                      Icons.arrow_downward,
                      const Color(0xFF00E676),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // === CATÉGORIE ===
              const Text(
                'Catégorie',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => _buildCategoryGrid(categories),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Erreur: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

              const SizedBox(height: 24),

              // === NOTE ===
              const Text(
                'Note (optionnel)',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Beignets au marché',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: const Color(0xFF1A1F38),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF00D9FF),
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // === DATE ===
              const Text(
                'Date',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F38),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF00D9FF),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat(
                          'EEEE dd MMMM yyyy',
                          'fr_FR',
                        ).format(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // === BOUTON ENREGISTRER ===
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: const Color(0xFF0A0E21),
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
                            color: Color(0xFF0A0E21),
                          ),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transactionType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.white38, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.white38,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<CategoriesTableData> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = _selectedCategoryId == cat.id;
        final color = _parseColor(cat.color) ?? Colors.grey;

        return GestureDetector(
          onTap: () => setState(() => _selectedCategoryId = cat.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.3)
                  : const Color(0xFF1A1F38),
              borderRadius: BorderRadius.circular(20),
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(_getCategoryIcon(cat.iconKey), color: color, size: 14),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
      case 'question':
        return FontAwesomeIcons.question;
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
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00D9FF),
              surface: Color(0xFF1A1F38),
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(' ', ''));
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
        externalId: const Value.absent(), // UUID généré par le repository
        isAiCategorized: const Value(false),
        syncStatus: const Value(0),
        validationStatus: const Value(1), // Validé d'office
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
            backgroundColor: Colors.redAccent,
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
