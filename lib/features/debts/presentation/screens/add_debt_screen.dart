import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/auth/data/repositories/auth_repository.dart';
import 'package:sika_app/features/transactions/presentation/widgets/text_pad.dart';
import '../../domain/entities/debt.dart';
import '../../data/providers/debt_providers.dart';

enum _FocusedField { none, amount, name, person, notes }

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({super.key});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();

  String _nameText = '';
  String _personText = '';
  String _amountText = '';
  String _notesText = '';

  DebtType _selectedType = DebtType.bill;
  DateTime _dueDate = DateTime.now();
  bool _isRecurring = false;

  _FocusedField _focusedField = _FocusedField.none;

  @override
  void dispose() {
    super.dispose();
  }

  void _onNumberKeyPressed(String key) {
    setState(() {
      if (_amountText.length < 12) {
        if (key == '.' && _amountText.contains('.')) return;
        _amountText += key;
      }
    });
  }

  void _onNumberBackspace() {
    setState(() {
      if (_amountText.isNotEmpty) {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  void _onTextKeyPressed(String key) {
    setState(() {
      if (_focusedField == _FocusedField.name) {
        if (_nameText.length < 40) _nameText += key;
      } else if (_focusedField == _FocusedField.person) {
        if (_personText.length < 40) _personText += key;
      } else if (_focusedField == _FocusedField.notes) {
        if (_notesText.length < 100) _notesText += key;
      }
    });
  }

  void _onTextBackspace() {
    setState(() {
      if (_focusedField == _FocusedField.name && _nameText.isNotEmpty) {
        _nameText = _nameText.substring(0, _nameText.length - 1);
      } else if (_focusedField == _FocusedField.person &&
          _personText.isNotEmpty) {
        _personText = _personText.substring(0, _personText.length - 1);
      } else if (_focusedField == _FocusedField.notes &&
          _notesText.isNotEmpty) {
        _notesText = _notesText.substring(0, _notesText.length - 1);
      }
    });
  }

  void _closeKeyboard() {
    setState(() {
      _focusedField = _FocusedField.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showNumberPad = _focusedField == _FocusedField.amount;
    final showTextPad =
        _focusedField == _FocusedField.name ||
        _focusedField == _FocusedField.person ||
        _focusedField == _FocusedField.notes;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouvel Engagement',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _closeKeyboard,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 20,
                      bottom: (showNumberPad || showTextPad) ? 300 : 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // === MONTANT DISPLAY ===
                          _buildAmountDisplay(),

                          const SizedBox(height: 24),

                          // === TYPE SELECTOR ===
                          _buildTypeSelector(),

                          const SizedBox(height: 24),

                          // === DÉTAILS CARD ===
                          _buildDetailsCard(),

                          const SizedBox(height: 20),

                          // === DATE & RÉCURRENCE ===
                          _buildOptionsCard(),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // === BOUTON ENREGISTRER ===
                if (!showNumberPad && !showTextPad) _buildSubmitButton(),
              ],
            ),
          ),

          // === TEXT PAD ===
          if (showTextPad)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TextPad(
                onKeyPressed: _onTextKeyPressed,
                onBackspace: _onTextBackspace,
                onDone: () {
                  if (_focusedField == _FocusedField.name) {
                    setState(
                      () => _focusedField = (_selectedType == DebtType.debtOut || _selectedType == DebtType.debtIn)
                          ? _FocusedField.person
                          : _FocusedField.none,
                    );
                  } else {
                    _closeKeyboard();
                  }
                },
              ),
            ),

          // === NUMBER PAD ===
          if (showNumberPad)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNumberPad(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNumberPad() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNumRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _buildNumRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _buildNumRow(['7', '8', '9']),
          const SizedBox(height: 8),
          _buildNumRow(['.', '0', '⌫']),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () =>
                  setState(() => _focusedField = _FocusedField.name),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Suivant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final isBackspace = key == '⌫';
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (isBackspace) {
                _onNumberBackspace();
              } else {
                _onNumberKeyPressed(key);
              }
            },
            child: Container(
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: isBackspace
                    ? Icon(
                        Icons.backspace_outlined,
                        color: AppTheme.primaryColor,
                        size: 22,
                      )
                    : Text(
                        key,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountDisplay() {
    final displayAmount = _amountText.isEmpty ? '0' : _amountText;
    final isFocused = _focusedField == _FocusedField.amount;

    return GestureDetector(
      onTap: () => setState(
        () => _focusedField = isFocused
            ? _FocusedField.none
            : _FocusedField.amount,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isFocused
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFocused ? AppTheme.primaryColor : Colors.grey.shade100,
            width: isFocused ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Montant de l\'engagement',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
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
                        : AppTheme.primaryColor,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'FCFA',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTypeTab(DebtType.bill, 'Facture'),
          _buildTypeTab(DebtType.debtOut, 'Dette'),
          _buildTypeTab(DebtType.debtIn, 'Revenu'),
        ],
      ),
    );
  }

  Widget _buildTypeTab(DebtType type, String label) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCustomInputField(
            value: _nameText,
            label: 'Objet de l\'engagement',
            hint: 'Ex: Loyer, Electricité, Prêt...',
            icon: Icons.description_outlined,
            isFocused: _focusedField == _FocusedField.name,
            onTap: () => setState(
              () => _focusedField = _focusedField == _FocusedField.name
                  ? _FocusedField.none
                  : _FocusedField.name,
            ),
          ),
          if (_selectedType == DebtType.debtOut || _selectedType == DebtType.debtIn) ...[
            const SizedBox(height: 20),
            _buildCustomInputField(
              value: _personText,
              label: _selectedType == DebtType.debtIn ? 'Source / Client' : 'Bénéficiaire / Personne',
              hint: 'Nom de la personne',
              icon: Icons.person_outline,
              isFocused: _focusedField == _FocusedField.person,
              onTap: () => setState(
                () => _focusedField = _focusedField == _FocusedField.person
                    ? _FocusedField.none
                    : _FocusedField.person,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomInputField({
    required String value,
    required String label,
    required String hint,
    required IconData icon,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isFocused
                      ? AppTheme.primaryColor
                      : Colors.grey.shade100,
                  width: isFocused ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isFocused
                      ? AppTheme.primaryColor
                      : Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value.isEmpty ? hint : value,
                    style: TextStyle(
                      color: value.isEmpty
                          ? Colors.grey.shade300
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isFocused)
                  const SizedBox(
                    height: 18,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: _pickDate,
            leading: const Icon(
              Icons.calendar_today,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            title: const Text(
              'Date d\'échéance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(_dueDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
            secondary: const Icon(
              Icons.repeat,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            title: const Text(
              'Répéter mensuellement',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
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
            onPressed: _saveDebt,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Enregistrer l\'engagement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    _closeKeyboard();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _dueDate = date);
  }

  void _saveDebt() {
    if (_amountText.isEmpty || _nameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le montant et l\'objet'),
        ),
      );
      return;
    }

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final debt = Debt(
      id: const Uuid().v4(),
      userId: userId,
      name: _nameText,
      amount: double.tryParse(_amountText) ?? 0.0,
      type: _selectedType,
      dueDate: _dueDate,
      personName: _personText.isEmpty ? null : _personText,
      notes: _notesText.isEmpty ? null : _notesText,
      isRecurring: _isRecurring,
      recurrenceRule: _isRecurring ? 'monthly' : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(debtRepositoryProvider).addDebt(debt);
    Navigator.pop(context);
  }
}
