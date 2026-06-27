import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/auth/data/repositories/auth_repository.dart';
import '../../domain/entities/debt.dart';
import '../../data/providers/debt_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/text_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/blinking_cursor.dart';

class AddReceivableScreen extends ConsumerStatefulWidget {
  final Debt? existingDebt;

  const AddReceivableScreen({super.key, this.existingDebt});

  @override
  ConsumerState<AddReceivableScreen> createState() =>
      _AddReceivableScreenState();
}

class _AddReceivableScreenState extends ConsumerState<AddReceivableScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _nameText;
  late String _personText;
  late String _amountText;
  late DateTime _dueDate;
  late bool _isRecurring;

  bool _showNumberPad = false;
  bool _showTextPad = false;
  String _activeTextField = ''; // 'name' ou 'person'

  @override
  void initState() {
    super.initState();
    final debt = widget.existingDebt;
    _nameText = debt?.name ?? '';
    _personText = debt?.personName ?? '';
    _amountText = debt != null ? debt.amount.toStringAsFixed(0) : '';
    _dueDate = debt?.dueDate ?? DateTime.now();
    _isRecurring = debt?.isRecurring ?? false;
  }

  void _onNumberKeyPressed(String key) {
    setState(() {
      if (_showTextPad) _showTextPad = false;
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

  void _onTextPadKeyPressed(String key) {
    setState(() {
      if (_showNumberPad) _showNumberPad = false;
      if (_activeTextField == 'name') {
        _nameText += key;
      } else if (_activeTextField == 'person') {
        _personText += key;
      }
    });
  }

  void _onTextPadBackspace() {
    setState(() {
      if (_activeTextField == 'name' && _nameText.isNotEmpty) {
        _nameText = _nameText.substring(0, _nameText.length - 1);
      } else if (_activeTextField == 'person' && _personText.isNotEmpty) {
        _personText = _personText.substring(0, _personText.length - 1);
      }
    });
  }

  void _closeKeyboard() {
    setState(() {
      _showNumberPad = false;
      _showTextPad = false;
    });
  }

  void _openTextPad(String field) {
    setState(() {
      _activeTextField = field;
      _showTextPad = true;
      _showNumberPad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingDebt != null;
    final themeColor = AppTheme.primaryColor;

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
        title: Text(
          isEditing ? 'Modifier à percevoir' : 'Nouveau à percevoir',
          style: const TextStyle(
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
                      bottom: (_showNumberPad || _showTextPad) ? 300 : 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildAmountDisplay(themeColor),
                          const SizedBox(height: 24),
                          _buildDetailsCard(themeColor),
                          const SizedBox(height: 20),
                          _buildOptionsCard(themeColor),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_showNumberPad && !_showTextPad)
                  _buildSubmitButton(themeColor),
              ],
            ),
          ),

          if (_showNumberPad)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNumberPad(themeColor),
            ),

          if (_showTextPad)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TextPad(
                onKeyPressed: _onTextPadKeyPressed,
                onBackspace: _onTextPadBackspace,
                onDone: () => setState(() => _showTextPad = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNumberPad(Color themeColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
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
          NumberPad(
            onKeyPressed: _onNumberKeyPressed,
            onBackspace: _onNumberBackspace,
            themeColor: themeColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => setState(() => _showNumberPad = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
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
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay(Color themeColor) {
    final displayAmount = _amountText.isEmpty ? '0' : _amountText;
    final isFocused = _showNumberPad;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showNumberPad = !_showNumberPad;
          if (_showNumberPad) _showTextPad = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isFocused ? themeColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFocused ? themeColor : Colors.grey.shade100,
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
            const Text(
              'Montant à percevoir',
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
                if (isFocused && _amountText.isEmpty)
                  BlinkingCursor(
                    height: 40,
                    width: 3,
                    color: themeColor,
                  )
                else ...[
                  Text(
                    displayAmount,
                    style: TextStyle(
                      color: _amountText.isEmpty
                          ? const Color(0xFFD1D5DB)
                          : themeColor,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isFocused)
                    BlinkingCursor(
                      height: 40,
                      width: 3,
                      color: themeColor,
                    ),
                ],
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

  Widget _buildDetailsCard(Color themeColor) {
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
          _buildTextPadField(
            field: 'name',
            value: _nameText,
            label: 'Objet du revenu',
            hint: 'Ex: Salaire, Remboursement...',
            icon: Icons.description_outlined,
            themeColor: themeColor,
          ),
          const SizedBox(height: 20),
          _buildTextPadField(
            field: 'person',
            value: _personText,
            label: 'Source / Débiteur',
            hint: 'Nom de la source',
            icon: Icons.person_outline,
            themeColor: themeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTextPadField({
    required String field,
    required String value,
    required String label,
    required String hint,
    required IconData icon,
    required Color themeColor,
  }) {
    final isFocused = _showTextPad && _activeTextField == field;

    return GestureDetector(
      onTap: () => _openTextPad(field),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
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
                  color: isFocused ? themeColor : Colors.grey.shade200,
                  width: isFocused ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      if (isFocused && value.isEmpty)
                        BlinkingCursor(
                          height: 18,
                          width: 2,
                          color: themeColor,
                        )
                      else ...[
                        Flexible(
                          child: Text(
                            value.isEmpty ? hint : value,
                            style: TextStyle(
                              color: value.isEmpty
                                  ? Colors.grey.shade400
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFocused)
                          BlinkingCursor(
                            height: 18,
                            width: 2,
                            color: themeColor,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(Color themeColor) {
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
            leading: Icon(Icons.calendar_today, color: themeColor, size: 20),
            title: const Text(
              'Date de réception prévue',
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
            secondary: Icon(Icons.repeat, color: themeColor, size: 20),
            title: const Text(
              'Répéter mensuellement',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            activeThumbColor: themeColor,
            activeTrackColor: themeColor.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color themeColor) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saveDebt,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.existingDebt != null
                  ? 'Enregistrer les modifications'
                  : 'Ajouter à percevoir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    _closeKeyboard();
    final themeColor = AppTheme.primaryColor;
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: themeColor),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _dueDate = date);
  }

  void _saveDebt() {
    if (_amountText.isEmpty || _nameText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir le montant et l\'objet'),
        ),
      );
      return;
    }

    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;

    final isEditing = widget.existingDebt != null;

    final debt = Debt(
      id: isEditing ? widget.existingDebt!.id : const Uuid().v4(),
      userId: userId,
      name: _nameText.trim(),
      amount: double.tryParse(_amountText) ?? 0.0,
      paidAmount: isEditing ? widget.existingDebt!.paidAmount : 0.0,
      type: DebtType.debtIn,
      dueDate: _dueDate,
      status: isEditing ? widget.existingDebt!.status : DebtStatus.pending,
      personName: _personText.trim().isEmpty ? null : _personText.trim(),
      notes: null,
      isRecurring: _isRecurring,
      recurrenceRule: _isRecurring ? 'monthly' : null,
      createdAt: isEditing ? widget.existingDebt!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      ref.read(debtRepositoryProvider).updateDebt(debt);
    } else {
      ref.read(debtRepositoryProvider).addDebt(debt);
    }

    Navigator.pop(context);
  }
}
