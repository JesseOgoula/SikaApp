import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:sika_app/core/theme/app_theme.dart';

/// Boutons d'actions rapides (Ajouter, Sync, Analyse, Objectifs)
class QuickActions extends StatelessWidget {
  final VoidCallback onAddPressed;
  final VoidCallback onSyncPressed;
  final VoidCallback? onAnalysePressed;
  final VoidCallback? onGoalsPressed;
  final bool isSyncing;

  const QuickActions({
    super.key,
    required this.onAddPressed,
    required this.onSyncPressed,
    this.onAnalysePressed,
    this.onGoalsPressed,
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
        _buildActionButton(
          faIcon: FontAwesomeIcons.bullseye,
          label: 'Objectifs',
          onTap: onGoalsPressed ?? () {},
          isDisabled: onGoalsPressed == null,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    IconData? faIcon,
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
            width: 52,
            height: 52,
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
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : faIcon != null
                ? Center(
                    child: FaIcon(
                      faIcon,
                      color: isPrimary
                          ? Colors.white
                          : isDisabled
                          ? Colors.grey
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                  )
                : Icon(
                    icon,
                    color: isPrimary
                        ? Colors.white
                        : isDisabled
                        ? Colors.grey
                        : AppTheme.primaryColor,
                    size: 22,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
