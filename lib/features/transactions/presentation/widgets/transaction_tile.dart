import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Tuile de transaction avec design Neo-Bank
class TransactionTile extends StatelessWidget {
  final TransactionWithCategory txWithCategory;

  const TransactionTile({super.key, required this.txWithCategory});

  @override
  Widget build(BuildContext context) {
    final tx = txWithCategory.transaction;
    final category = txWithCategory.category;

    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM', 'fr_FR');

    final isExpense = tx.type == 'expense';
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? AppTheme.success : AppTheme.error;
    final amountPrefix = isIncome ? '+' : '-';

    // Couleur pastel pour l'icône
    final categoryColor = _parseColor(category?.color) ?? Colors.grey;
    final pastelColor = AppTheme.getCategoryPastelColor(category?.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône catégorie
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: pastelColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(
                _getCategoryIcon(category?.iconKey),
                color: categoryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchantName ?? 'Transaction',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateFormat.format(tx.date),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (category != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      Text(
                        category.name,
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Montant
          Text(
            '$amountPrefix${currencyFormat.format(tx.amount)}',
            style: TextStyle(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
}
