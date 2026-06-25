import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sika_app/features/notification_sync/domain/models/parsed_transaction.dart';

/// Carte affichant une transaction détectée en attente de validation
///
/// Affiche le badge opérateur coloré, le montant, la description,
/// la catégorie suggérée, et 3 boutons d'action (Ignorer / Modifier / Enregistrer).
class PendingTransactionCard extends StatelessWidget {
  final ParsedTransaction tx;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  const PendingTransactionCard({
    super.key,
    required this.tx,
    required this.onConfirm,
    required this.onEdit,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final formattedAmount = NumberFormat('#,###', 'fr_FR').format(tx.amount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : badge opérateur + source + heure ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Badge opérateur
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tx.operatorColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tx.operatorColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tx.operatorLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tx.operatorColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badge source (SMS / Push)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tx.source == ParsedSource.sms ? 'SMS' : 'Push',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                // Heure
                Text(
                  _formatTime(tx.receivedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Montant + description ──
            Text(
              '$sign $formattedAmount FCFA',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: amountColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tx.description,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '📁 ${tx.patternLabel}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),

            // ── Solde détecté (si disponible) ──
            if (tx.detectedBalance != null) ...[
              const SizedBox(height: 8),
              Text(
                'Solde détecté : ${NumberFormat('#,###', 'fr_FR').format(tx.detectedBalance)} FCFA',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Boutons d'action ──
            Row(
              children: [
                // Ignorer
                Expanded(
                  child: _ActionButton(
                    label: 'Ignorer',
                    onTap: onReject,
                    backgroundColor: Colors.transparent,
                    textColor: Colors.grey.shade600,
                    borderColor: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 8),
                // Modifier
                Expanded(
                  child: _ActionButton(
                    label: 'Modifier',
                    onTap: onEdit,
                    backgroundColor: Colors.grey.shade100,
                    textColor: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 8),
                // Enregistrer
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: 'Enregistrer',
                    onTap: onConfirm,
                    backgroundColor: const Color(0xFF16A34A),
                    textColor: Colors.white,
                    isBold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool isBold;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: borderColor != null
                ? Border.all(color: borderColor!)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
