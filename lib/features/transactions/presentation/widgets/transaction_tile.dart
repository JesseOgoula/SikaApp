import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Tuile de transaction avec design unifié (même style que GoalCard)
class TransactionTile extends StatelessWidget {
  final TransactionWithCategory txWithCategory;
  final VoidCallback? onTap;

  const TransactionTile({super.key, required this.txWithCategory, this.onTap});

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

    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? AppTheme.success : AppTheme.error;
    final amountPrefix = isIncome ? '+' : '-';
    final iconBgColor = isIncome
        ? AppTheme.success.withOpacity(0.1)
        : AppTheme.primaryColor.withOpacity(0.1);
    final iconColor = isIncome ? AppTheme.success : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: amountColor.withOpacity(0.15), width: 1),
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
            // Icône catégorie - Style unifié
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(
                  _getCategoryIcon(category?.iconKey),
                  color: iconColor,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),

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
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (category != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Flexible(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Montant avec badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: amountColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$amountPrefix${currencyFormat.format(tx.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
      case 'piggyBank':
        return FontAwesomeIcons.piggyBank;
      case 'question':
        return FontAwesomeIcons.question;
      default:
        return FontAwesomeIcons.tag;
    }
  }
}
