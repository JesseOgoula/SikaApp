import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Tuile de transaction avec design sobre et élégant
/// Style unifié avec les cartes d'objectifs
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

    // Design sobre : couleurs basées sur le thème principal
    // Revenus : Secondaire (teal) / Dépenses : Nuance de gris foncé
    final amountColor = isIncome
        ? AppTheme.secondaryColor
        : AppTheme.textPrimary;
    final amountPrefix = isIncome ? '+' : '-';

    // Icône toujours avec la couleur primaire (cohérence avec goals)
    const iconBgColor = Color(0xFFF5F7FA);
    const iconColor = AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône catégorie - Style sobre
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
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
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (category != null) ...[
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
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

            // Montant - Style simple et élégant
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix${currencyFormat.format(tx.amount)}',
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // Petit indicateur de type
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isIncome
                            ? AppTheme.secondaryColor.withOpacity(0.6)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isIncome ? 'Revenu' : 'Dépense',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? iconKey) {
    if (iconKey == null) return FontAwesomeIcons.receipt;
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
        return FontAwesomeIcons.receipt;
      case 'moneyBill':
        return FontAwesomeIcons.moneyBill;
      case 'wallet':
        return FontAwesomeIcons.wallet;
      default:
        return FontAwesomeIcons.receipt;
    }
  }
}
