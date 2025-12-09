import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/features/sms_parser/data/providers/sms_providers.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';

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

    debugPrint('🔍 [HomeScreen] Watching transactionListProvider...');
    final transactionsAsync = ref.watch(transactionListProvider);
    debugPrint(
      '✅ [HomeScreen] transactionListProvider watched. State: ${transactionsAsync.toString()}',
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

  Widget _buildBody(List<TransactionsTableData> transactions) {
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

  Widget _buildBalanceHeader(List<TransactionsTableData> transactions) {
    debugPrint(
      '💰 [HomeScreen] Building balance header with ${transactions.length} txs',
    );
    // Calcule le solde total (revenus - dépenses)
    double totalBalance = 0;
    double totalIncome = 0;
    double totalExpense = 0;

    for (final tx in transactions) {
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

  Widget _buildTransactionList(List<TransactionsTableData> transactions) {
    debugPrint(
      '📋 [HomeScreen] Building transaction list (${transactions.length} items)',
    );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionTile(tx);
      },
    );
  }

  Widget _buildTransactionTile(TransactionsTableData tx) {
    // Debug print for first transaction to check fields
    // if (tx == transactions.first) {
    //  debugPrint('📝 [HomeScreen] First transaction: id=${tx.id}, amount=${tx.amount}, type=${tx.type}, sender=${tx.smsSender}');
    // }

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icône de l'opérateur
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getOperatorColor(tx.smsSender).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getOperatorIcon(tx.smsSender),
              color: _getOperatorColor(tx.smsSender),
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

  IconData _getOperatorIcon(String? operator) {
    if (operator == null) return Icons.receipt;
    switch (operator.toUpperCase()) {
      case 'AIRTEL_MONEY':
        return Icons.phone_android;
      case 'MOOV_MONEY':
        return Icons.phone_iphone;
      case 'UBA':
        return Icons.account_balance;
      default:
        return Icons.receipt;
    }
  }

  Color _getOperatorColor(String? operator) {
    if (operator == null) return Colors.grey;
    switch (operator.toUpperCase()) {
      case 'AIRTEL_MONEY':
        return Colors.red;
      case 'MOOV_MONEY':
        return Colors.blue;
      case 'UBA':
        return Colors.green;
      default:
        return Colors.grey;
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
