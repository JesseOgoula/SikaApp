import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/transactions/data/providers/transaction_providers.dart';
import 'package:sika_app/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/screens/edit_transaction_screen.dart';
import 'package:sika_app/features/transactions/presentation/widgets/transaction_tile.dart';

/// Périodes de filtrage disponibles
enum TransactionPeriod {
  all,
  twentyFourHours,
  sevenDays,
  thisMonth,
  threeMonths,
}

/// Écran affichant toutes les transactions avec filtrage par période
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  TransactionPeriod _selectedPeriod = TransactionPeriod.all;

  /// Filtre les transactions selon la période sélectionnée
  List<TransactionWithCategory> _filterTransactions(
    List<TransactionWithCategory> transactions,
  ) {
    if (_selectedPeriod == TransactionPeriod.all) {
      return transactions;
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case TransactionPeriod.twentyFourHours:
        startDate = now.subtract(const Duration(hours: 24));
        break;
      case TransactionPeriod.sevenDays:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case TransactionPeriod.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case TransactionPeriod.threeMonths:
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case TransactionPeriod.all:
        return transactions;
    }

    return transactions
        .where((t) => t.transaction.date.isAfter(startDate))
        .toList();
  }

  String _getPeriodLabel(TransactionPeriod period) {
    switch (period) {
      case TransactionPeriod.all:
        return 'Tout';
      case TransactionPeriod.twentyFourHours:
        return '24h';
      case TransactionPeriod.sevenDays:
        return '7 jours';
      case TransactionPeriod.thisMonth:
        return 'Ce mois';
      case TransactionPeriod.threeMonths:
        return '3 mois';
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionWithCategoryListProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Toutes les Transactions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sélecteur de période
          _buildPeriodSelector(),

          // Liste des transactions
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                final filtered = _filterTransactions(transactions);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final txWithCat = filtered[index];
                    return TransactionTile(
                      txWithCategory: txWithCat,
                      onEdit: () => _editTransaction(txWithCat.transaction),
                      onDelete: () async {
                        final repo = ref.read(transactionRepositoryProvider);
                        await repo.deleteTransaction(txWithCat.transaction.id);
                        await Future.delayed(const Duration(milliseconds: 300));
                        ref.invalidate(transactionWithCategoryListProvider);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Erreur: $error',
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: TransactionPeriod.values.map((period) {
            final isSelected = _selectedPeriod == period;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedPeriod = period);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  _getPeriodLabel(period),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedPeriod != TransactionPeriod.all;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off : Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'Aucune transaction sur cette période'
                : 'Aucune transaction',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Essayez une période différente'
                : 'Ajoutez votre première transaction manuelle',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (result == true) {
      ref.invalidate(transactionWithCategoryListProvider);
    }
  }

  Future<void> _editTransaction(dynamic transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true) {
      ref.invalidate(transactionWithCategoryListProvider);
    }
  }
}
