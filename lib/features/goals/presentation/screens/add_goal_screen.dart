import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/transactions/presentation/widgets/text_pad.dart';

/// Écran d'ajout d'un objectif d'épargne avec claviers en bas
class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  String _nameText = '';
  String _amountText = '';
  String? _selectedIconKey;
  DateTime? _selectedDeadline;
  bool _isLoading = false;
  bool _showTextPad = false;
  bool _showNumberPad = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  final List<Map<String, dynamic>> _availableIcons = [
    {'key': 'laptop', 'icon': FontAwesomeIcons.laptop, 'label': 'PC'},
    {
      'key': 'phone',
      'icon': FontAwesomeIcons.mobileScreen,
      'label': 'Téléphone',
    },
    {'key': 'car', 'icon': FontAwesomeIcons.car, 'label': 'Voiture'},
    {'key': 'plane', 'icon': FontAwesomeIcons.plane, 'label': 'Voyage'},
    {'key': 'home', 'icon': FontAwesomeIcons.house, 'label': 'Maison'},
    {
      'key': 'graduation',
      'icon': FontAwesomeIcons.graduationCap,
      'label': 'Études',
    },
    {'key': 'gift', 'icon': FontAwesomeIcons.gift, 'label': 'Cadeau'},
    {
      'key': 'piggyBank',
      'icon': FontAwesomeIcons.piggyBank,
      'label': 'Épargne',
    },
  ];

  void _onTextKeyPressed(String key) {
    setState(() {
      if (_nameText.length < 30) {
        _nameText += key;
      }
    });
  }

  void _onTextBackspace() {
    setState(() {
      if (_nameText.isNotEmpty) {
        _nameText = _nameText.substring(0, _nameText.length - 1);
      }
    });
  }

  void _onNumberKeyPressed(String key) {
    setState(() {
      if (_amountText.length < 10) {
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

  void _closeAllKeyboards() {
    setState(() {
      _showTextPad = false;
      _showNumberPad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Nouvel Objectif',
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
          // Contenu scrollable
          GestureDetector(
            onTap: _closeAllKeyboards,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: (_showTextPad || _showNumberPad) ? 280 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === NOM ===
                  _buildLabel('Nom de l\'objectif'),
                  const SizedBox(height: 8),
                  _buildNameField(),

                  const SizedBox(height: 24),

                  // === MONTANT ===
                  _buildLabel('Montant cible'),
                  const SizedBox(height: 12),
                  _buildAmountField(),

                  const SizedBox(height: 24),

                  // === ICÔNE ===
                  _buildLabel('Icône'),
                  const SizedBox(height: 12),
                  _buildIconSelector(),

                  const SizedBox(height: 24),

                  // === DATE LIMITE ===
                  _buildLabel('Date limite (optionnel)'),
                  const SizedBox(height: 8),
                  _buildDateField(),

                  const SizedBox(height: 40),

                  // === BOUTON ===
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveGoal,
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
                              'Créer l\'objectif',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // TextPad en bas de l'écran
          if (_showTextPad)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TextPad(
                onKeyPressed: _onTextKeyPressed,
                onBackspace: _onTextBackspace,
                onDone: () => setState(() {
                  _showTextPad = false;
                  _showNumberPad = true;
                }),
              ),
            ),

          // NumberPad en bas de l'écran
          if (_showNumberPad)
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
            height: 44,
            child: ElevatedButton(
              onPressed: _closeAllKeyboards,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
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
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildNameField() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showTextPad = !_showTextPad;
          _showNumberPad = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _showTextPad
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.2),
            width: _showTextPad ? 2 : 1,
          ),
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
                color: _showTextPad
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.flag,
                color: _showTextPad ? AppTheme.primaryColor : Colors.grey[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _nameText.isEmpty ? 'Appuyer pour saisir' : _nameText,
                style: TextStyle(
                  color: _nameText.isEmpty
                      ? Colors.grey[400]
                      : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              _showTextPad ? Icons.keyboard_hide : Icons.keyboard,
              color: _showTextPad
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showNumberPad = !_showNumberPad;
          _showTextPad = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _showNumberPad
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.2),
            width: _showNumberPad ? 2 : 1,
          ),
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
                color: _showNumberPad
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.savings,
                color: _showNumberPad
                    ? AppTheme.primaryColor
                    : Colors.grey[700],
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _amountText.isEmpty
                    ? 'Appuyer pour saisir'
                    : _currencyFormat.format(double.parse(_amountText)),
                style: TextStyle(
                  color: _amountText.isEmpty
                      ? Colors.grey[400]
                      : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _showNumberPad ? Icons.keyboard_hide : Icons.dialpad,
              color: _showNumberPad
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableIcons.map((item) {
        final isSelected = _selectedIconKey == item['key'];
        return GestureDetector(
          onTap: () {
            _closeAllKeyboards();
            setState(() => _selectedIconKey = item['key']);
          },
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: AppTheme.primaryColor, width: 2)
                      : null,
                ),
                child: Center(
                  child: FaIcon(
                    item['icon'] as IconData,
                    color: isSelected ? Colors.white : Colors.grey[700],
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['label'] as String,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () {
        _closeAllKeyboards();
        _selectDeadline();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
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
                _selectedDeadline != null
                    ? DateFormat(
                        'EEEE dd MMMM yyyy',
                        'fr_FR',
                      ).format(_selectedDeadline!)
                    : 'Aucune date limite',
                style: TextStyle(
                  color: _selectedDeadline != null
                      ? AppTheme.textPrimary
                      : Colors.grey[400],
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
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
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (_nameText.isEmpty) {
      _showError('Veuillez entrer un nom');
      return;
    }

    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) {
      _showError('Veuillez entrer un montant valide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(goalRepositoryProvider);
      await repo.addGoal(
        name: _nameText,
        targetAmount: amount,
        iconKey: _selectedIconKey,
        deadline: _selectedDeadline,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
