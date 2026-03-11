import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/services/receipt_scanner_service.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/widgets/number_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/text_pad.dart';
import 'package:sika_app/features/transactions/presentation/widgets/category_icon_widget.dart';
import 'package:sika_app/features/accounts/data/providers/account_providers.dart';
import 'package:sika_app/core/services/analytics_service.dart';
import 'package:sika_app/main.dart' show databaseProvider;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isScanning = false;
  bool _showKeypad = false; // Clavier numérique caché par défaut
  bool _showTextPad = false; // Clavier texte caché par défaut
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Attend que l'animation du clavier soit terminée puis scrolle
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
      if (_showTextPad) {
        _showKeypad = false;
        _scrollToBottom();
      }
    });
  }

  void _toggleKeypad() {
    setState(() {
      _showKeypad = !_showKeypad;
      if (_showKeypad) {
        _showTextPad = false;
        _scrollToBottom();
      }
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
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _scanReceipt,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            tooltip: 'Scanner une facture',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // === MONTANT (FIXE en haut, hors scroll) ===
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildAmountDisplay(),
              ),

              const SizedBox(height: 8),

              // === TYPE SELECTOR (FIXE) ===
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildTypeSelector(),
              ),

              const SizedBox(height: 12),

              // Scrollable content (catégories, compte, date, note)
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // === CATÉGORIES ===
                      _buildCategorySection(categoriesAsync),

                      const SizedBox(height: 20),

                      // === COMPTE ===
                      _buildAccountSection(),

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

          // === OVERLAY SCAN EN COURS ===
          if (_isScanning) _buildScanOverlay(),
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
          'Categorie',
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
              itemCount: categories.length + 1, // +1 for the add button
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  // Bouton '+' pour creer une categorie
                  return _buildAddCategoryButton();
                }
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

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: () => _showCreateCategorySheet(),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Center(
              child: Icon(Icons.add, color: AppTheme.primaryColor, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajouter',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateCategoryBottomSheet(
        onCreated: (String name, String iconKey) async {
          final db = ref.read(databaseProvider);
          final id = const Uuid().v4();
          await db
              .into(db.categoriesTable)
              .insert(
                CategoriesTableCompanion.insert(
                  id: id,
                  name: name,
                  iconKey: Value(iconKey),
                  isSystem: Value(false),
                  syncStatus: Value(0),
                  sortOrder: Value(99),
                ),
              );
          ref.invalidate(categoriesProvider);
          setState(() => _selectedCategoryId = id);
          if (mounted) Navigator.pop(ctx);
        },
      ),
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

  /// Section de sélection du compte
  Widget _buildAccountSection() {
    final accountsAsync = ref.watch(activeAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compte',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
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
          child: accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun compte configuré'),
                );
              }
              return DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                hint: const Text('Sélectionner un compte'),
                items: accounts.map((acc) {
                  final iconData = _getAccountIcon(acc.iconKey);
                  final color = Color(
                    int.parse(acc.color.replaceFirst('#', '0xFF')),
                  );
                  return DropdownMenuItem<String>(
                    value: acc.id,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(iconData, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(acc.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedAccountId = value),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Erreur de chargement'),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getAccountIcon(String iconKey) {
    switch (iconKey) {
      case 'phone_android':
        return Icons.phone_android;
      case 'account_balance':
        return Icons.account_balance;
      case 'payments':
        return Icons.payments;
      default:
        return Icons.account_balance_wallet;
    }
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

  // ===== OCR SCANNER =====

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();

    // Ouvre la caméra ou la galerie
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  'Scanner une facture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                title: const Text('Prendre une photo'),
                subtitle: const Text('Photographier la facture'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                  ),
                ),
                title: const Text('Choisir depuis la galerie'),
                subtitle: const Text('Sélectionner une image existante'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isScanning = true);

    try {
      // Récupère la liste des catégories
      final categories = await ref.read(categoriesProvider.future);
      final categoryNames = categories.map((c) => c.name).toList();

      // Appel IA
      final result = await ReceiptScannerService.scanReceipt(
        imageFile: File(image.path),
        categoryNames: categoryNames,
      );

      if (!mounted) return;

      if (!result.hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Impossible de lire cette facture. Essayez avec une photo plus nette.',
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Auto-remplir les champs
      setState(() {
        // Montant
        if (result.amount != null) {
          _amountText = result.amount!.toStringAsFixed(0);
        }

        // Note / Description
        if (result.description != null) {
          _noteText = result.description!;
        }

        // Catégorie
        if (result.suggestedCategory != null) {
          final matchedCategory = categories
              .where(
                (c) =>
                    c.name.toLowerCase() ==
                    result.suggestedCategory!.toLowerCase(),
              )
              .firstOrNull;
          if (matchedCategory != null) {
            _selectedCategoryId = matchedCategory.id;
          }
        }

        // Les factures sont des dépenses
        _transactionType = 'expense';
      });

      // Afficher un snackbar de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Facture analysée ! Montant : ${result.amount?.toStringAsFixed(0) ?? "?"} FCFA',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du scan : $e'),
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
        setState(() => _isScanning = false);
      }
    }
  }

  Widget _buildScanOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Analyse en cours...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'L\'IA analyse votre facture',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
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

    // Vérifier le solde disponible pour les dépenses
    if (_transactionType == 'expense') {
      final availableBalance = ref.read(totalAccountsBalanceProvider);
      if (amount > availableBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solde insuffisant. Disponible : ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(availableBalance)}',
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
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
        accountId: _selectedAccountId != null
            ? Value(_selectedAccountId!)
            : const Value.absent(),
        date: Value(_selectedDate),
        externalId: const Value.absent(),
        isAiCategorized: const Value(false),
        syncStatus: const Value(0),
        validationStatus: const Value(1),
      );

      final repo = ref.read(transactionRepositoryProvider);
      await repo.addManualTransaction(companion);

      await AnalyticsService.logEvent(
        'transaction_added',
        properties: {'type': _transactionType, 'method': 'manual'},
      );

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

/// Bottom Sheet pour creer une nouvelle categorie
/// Utilise le TextPad personnalise au lieu du clavier systeme
class _CreateCategoryBottomSheet extends StatefulWidget {
  final Future<void> Function(String name, String iconKey) onCreated;

  const _CreateCategoryBottomSheet({required this.onCreated});

  @override
  State<_CreateCategoryBottomSheet> createState() =>
      _CreateCategoryBottomSheetState();
}

class _CreateCategoryBottomSheetState
    extends State<_CreateCategoryBottomSheet> {
  String _nameText = '';
  String _selectedIcon = 'tag';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final iconEntries = CategoryIconWidget.availableIcons.entries.toList();

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
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nouvelle categorie',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Name display area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: Text(
                _nameText.isEmpty ? 'Nom de la categorie' : _nameText,
                style: TextStyle(
                  color: _nameText.isEmpty
                      ? Colors.grey.shade400
                      : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: _nameText.isEmpty
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Icon picker label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisir une icone',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Scrollable icon grid
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: iconEntries.length,
                itemBuilder: (context, index) {
                  final entry = iconEntries[index];
                  final isSelected = _selectedIcon == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = entry.key),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          entry.value,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Create button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_nameText.trim().isEmpty || _isLoading)
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        await widget.onCreated(_nameText.trim(), _selectedIcon);
                      },
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
                    : const Text(
                        'Creer la categorie',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),

          // Custom TextPad
          TextPad(
            onKeyPressed: (key) {
              setState(() => _nameText += key);
            },
            onBackspace: () {
              if (_nameText.isNotEmpty) {
                setState(() {
                  _nameText = _nameText.substring(0, _nameText.length - 1);
                });
              }
            },
            onDone: () {
              // Same as create button
              if (_nameText.trim().isNotEmpty && !_isLoading) {
                setState(() => _isLoading = true);
                widget.onCreated(_nameText.trim(), _selectedIcon);
              }
            },
          ),
        ],
      ),
    );
  }
}
