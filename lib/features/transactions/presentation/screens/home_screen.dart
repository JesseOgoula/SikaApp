import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/sms_parser/data/providers/sms_providers.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';

/// Écran d'accueil principal de l'application SIKA
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  final _dateFormat = DateFormat('dd MMM yyyy', 'fr_FR');
  final _timeFormat = DateFormat('HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    debugPrint('🏁 [HomeScreen] initState called');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [HomeScreen] build called');

    debugPrint(
      '🔍 [HomeScreen] Watching transactionWithCategoryListProvider...',
    );
    final transactionsAsync = ref.watch(transactionWithCategoryListProvider);
    debugPrint(
      '✅ [HomeScreen] transactionWithCategoryListProvider watched. State: ${transactionsAsync.toString()}',
    );

    debugPrint('🔍 [HomeScreen] Watching smsImportNotifierProvider...');
    final importState = ref.watch(smsImportNotifierProvider);
    debugPrint('✅ [HomeScreen] smsImportNotifierProvider watched.');

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: _buildAppBar(importState),
      body: transactionsAsync.when(
        data: (transactions) {
          debugPrint(
            '📊 [HomeScreen] Transactions loaded: ${transactions.length}',
          );
          return _buildBody(transactions);
        },
        loading: () {
          debugPrint('⏳ [HomeScreen] Loading transactions...');
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          );
        },
        error: (error, stack) {
          debugPrint('❌ [HomeScreen] Error loading transactions: $error');
          debugPrint('❌ [HomeScreen] Stacktrace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: $error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (result == true) {
            // Rafraîchit la liste (le StreamProvider le fait automatiquement)
            ref.invalidate(transactionWithCategoryListProvider);
          }
        },
        backgroundColor: const Color(0xFF00D9FF),
        child: const Icon(Icons.add, color: Color(0xFF0A0E21)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SmsImportState importState) {
    return AppBar(
      backgroundColor: const Color(0xFF0A0E21),
      elevation: 0,
      title: const Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Color(0xFF00D9FF)),
          SizedBox(width: 12),
          Text(
            'SIKA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
      actions: [
        // Bouton d'import SMS
        importState.isImporting
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00D9FF),
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.download, color: Color(0xFF00D9FF)),
                tooltip: 'Importer les SMS',
                onPressed: _onImportPressed,
              ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(List<TransactionWithCategory> transactions) {
    return Column(
      children: [
        // Header avec solde
        _buildBalanceHeader(transactions),

        // Liste des transactions
        Expanded(
          child: transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(transactions),
        ),
      ],
    );
  }

  Widget _buildBalanceHeader(List<TransactionWithCategory> transactions) {
    debugPrint(
      '💰 [HomeScreen] Building balance header with ${transactions.length} txs',
    );
    // Calcule le solde total (revenus - dépenses)
    double totalBalance = 0;
    double totalIncome = 0;
    double totalExpense = 0;

    for (final txWithCat in transactions) {
      final tx = txWithCat.transaction;
      if (tx.type == 'income') {
        totalIncome += tx.amount;
        totalBalance += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
        totalBalance -= tx.amount;
      }
      // Les transferts ne sont pas comptés dans le solde global
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F38), Color(0xFF0D1025)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'SOLDE TOTAL',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(totalBalance),
            style: TextStyle(
              color: totalBalance >= 0
                  ? const Color(0xFF00D9FF)
                  : Colors.redAccent,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat(
                icon: Icons.arrow_downward,
                label: 'Revenus',
                value: totalIncome,
                color: const Color(0xFF00E676),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              _buildMiniStat(
                icon: Icons.arrow_upward,
                label: 'Dépenses',
                value: totalExpense,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(value),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    debugPrint('📭 [HomeScreen] Building empty state');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune transaction',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Appuyez sur le bouton ⬇️ pour\nimporter vos SMS',
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _onImportPressed,
            icon: const Icon(Icons.download),
            label: const Text('Importer les SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: const Color(0xFF0A0E21),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionWithCategory> transactions) {
    debugPrint(
      '📋 [HomeScreen] Building transaction list (${transactions.length} items)',
    );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final txWithCat = transactions[index];
        return _buildTransactionTile(txWithCat);
      },
    );
  }

  Widget _buildTransactionTile(TransactionWithCategory txWithCat) {
    final tx = txWithCat.transaction;
    final category = txWithCat.category;

    final isExpense = tx.type == 'expense';
    final isIncome = tx.type == 'income';
    final amountColor = isIncome
        ? const Color(0xFF00E676)
        : isExpense
        ? Colors.redAccent
        : const Color(0xFF00D9FF);
    final amountPrefix = isIncome
        ? '+'
        : isExpense
        ? '-'
        : '';

    // Catégorie: icône et couleur
    final categoryIcon = _getCategoryIcon(category?.iconKey);
    final categoryColor = _parseColor(category?.color) ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icône de la catégorie
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(categoryIcon, color: categoryColor, size: 20),
            ),
          ),
          const SizedBox(width: 16),

          // Infos de la transaction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchantName ?? 'Transaction',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateFormat.format(tx.date)} • ${_timeFormat.format(tx.date)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          // Montant
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${_currencyFormat.format(tx.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _buildSyncBadge(tx.syncStatus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBadge(int syncStatus) {
    final isSynced = syncStatus == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSynced
            ? const Color(0xFF00E676).withOpacity(0.2)
            : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isSynced ? 'Sync' : 'Local',
        style: TextStyle(
          color: isSynced ? const Color(0xFF00E676) : Colors.orange,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Maps category iconKey to FontAwesome icon
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

  /// Parses hex color string to Color
  Color? _parseColor(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#')) return null;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  Future<void> _onImportPressed() async {
    debugPrint('📥 [HomeScreen] Import button pressed');
    try {
      final result = await ref
          .read(smsImportNotifierProvider.notifier)
          .importFromInbox();

      debugPrint('✅ [HomeScreen] Import completed: $result');

      if (!mounted) return;

      // Affiche un snackbar avec le résultat
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1F38),
          content: Row(
            children: [
              Icon(
                result.imported > 0 ? Icons.check_circle : Icons.info,
                color: result.imported > 0
                    ? const Color(0xFF00E676)
                    : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.imported > 0
                      ? '${result.imported} transaction(s) importée(s)'
                      : 'Aucune nouvelle transaction',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [HomeScreen] Import error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Erreur: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
