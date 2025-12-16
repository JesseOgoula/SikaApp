import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/auth/data/repositories/auth_repository.dart';
import '../../domain/entities/debt.dart';
import '../../data/providers/debt_providers.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _personController = TextEditingController();
  final _notesController = TextEditingController();

  DebtType _selectedType = DebtType.bill;
  DateTime _dueDate = DateTime.now();
  bool _isRecurring = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _personController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Nouvel Engagement'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Segmented Control Style for Type
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSegment('Facture', DebtType.bill)),
                  Expanded(child: _buildSegment('Je dois', DebtType.debtOut)),
                  Expanded(child: _buildSegment('On me doit', DebtType.debtIn)),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Card Style for Inputs
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détails',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nom
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: _inputDecoration(
                      'Titre',
                      Icons.description_outlined,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),

                  // Montant
                  TextFormField(
                    controller: _amountController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      'Montant (FCFA)',
                      Icons.attach_money,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                  ),

                  // Personne (Optionnel)
                  if (_selectedType != DebtType.bill) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _personController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: _inputDecoration(
                        _selectedType == DebtType.debtOut ? 'À qui ?' : 'Qui ?',
                        Icons.person_outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Date & Recurring Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Date d\'échéance',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecurring
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.loop,
                        color: _isRecurring
                            ? AppTheme.primaryColor
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Répéter tous les mois',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    value: _isRecurring,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) => setState(() => _isRecurring = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveDebt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getTypeColor(_selectedType),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                  shadowColor: _getTypeColor(_selectedType).withOpacity(0.4),
                ),
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(String label, DebtType type) {
    final isSelected = _selectedType == type;
    final color = _getTypeColor(type);

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(DebtType type) {
    switch (type) {
      case DebtType.bill:
        return AppTheme.primaryColor;
      case DebtType.debtOut:
        return Colors.orange; // Ou Rouge si vous préférez
      case DebtType.debtIn:
        return Colors.green;
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8)),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _dueDate = date);
  }

  void _saveDebt() {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final debt = Debt(
      id: const Uuid().v4(),
      userId: userId,
      name: _nameController.text,
      amount: double.tryParse(_amountController.text) ?? 0.0,
      type: _selectedType,
      dueDate: _dueDate,
      personName: _personController.text.isEmpty
          ? null
          : _personController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      isRecurring: _isRecurring,
      recurrenceRule: _isRecurring ? 'monthly' : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(debtRepositoryProvider).addDebt(debt);
    Navigator.pop(context);
  }
}
