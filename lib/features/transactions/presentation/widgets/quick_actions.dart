import 'package:flutter/material.dart';

import 'package:sika_app/core/theme/app_theme.dart';

/// Boutons d'actions rapides (Ajouter, Sync, Analyse)
class QuickActions extends StatelessWidget {
  final VoidCallback onAddPressed;
  final VoidCallback onSyncPressed;
  final VoidCallback? onAnalysePressed;
  final bool isSyncing;

  const QuickActions({
    super.key,
    required this.onAddPressed,
    required this.onSyncPressed,
    this.onAnalysePressed,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.add,
          label: 'Ajouter',
          onTap: onAddPressed,
          isPrimary: true,
        ),
        _buildActionButton(
          icon: isSyncing ? null : Icons.sync,
          label: 'Sync',
          onTap: onSyncPressed,
          isLoading: isSyncing,
        ),
        _buildActionButton(
          icon: Icons.bar_chart,
          label: 'Analyse',
          onTap: onAnalysePressed ?? () {},
          isDisabled: onAnalysePressed == null,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData? icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isLoading = false,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppTheme.primaryColor
                  : isDisabled
                  ? Colors.grey.shade200
                  : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: isPrimary
                            ? AppTheme.primaryColor.withOpacity(0.3)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    icon,
                    color: isPrimary
                        ? Colors.white
                        : isDisabled
                        ? Colors.grey
                        : AppTheme.primaryColor,
                    size: 24,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
