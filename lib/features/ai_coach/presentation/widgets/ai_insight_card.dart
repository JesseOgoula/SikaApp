import 'package:flutter/material.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Carte affichant les conseils de l'IA Coach
class AiInsightCard extends StatelessWidget {
  final String? insight;
  final bool isLoading;
  final String? error;
  final VoidCallback onAnalyzePressed;

  const AiInsightCard({
    super.key,
    this.insight,
    this.isLoading = false,
    this.error,
    required this.onAnalyzePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.08),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Coach IA',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (insight != null)
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: isLoading ? null : onAnalyzePressed,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Content
          if (isLoading) _buildLoading(),
          if (error != null && !isLoading) _buildError(),
          if (insight != null && !isLoading && error == null) _buildInsight(),
          if (insight == null && !isLoading && error == null) _buildInitial(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          "L'IA analyse tes dépenses...",
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error!, style: TextStyle(color: AppTheme.error, fontSize: 14)),
        const SizedBox(height: 12),
        _buildAnalyzeButton(),
      ],
    );
  }

  Widget _buildInsight() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb,
              color: AppTheme.secondaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight!,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitial() {
    return Center(child: _buildAnalyzeButton());
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: onAnalyzePressed,
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: const Text('Analyser mes dépenses'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
