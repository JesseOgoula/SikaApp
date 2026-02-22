import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/goals/data/repositories/goal_repository.dart';
import 'package:sika_app/features/goals/presentation/screens/add_goal_screen.dart';
import 'package:sika_app/features/goals/presentation/widgets/feed_goal_bottom_sheet.dart';
import 'package:sika_app/features/goals/presentation/widgets/goal_card.dart';
import 'package:sika_app/features/goals/presentation/widgets/delete_goal_dialog.dart';

/// Ecran listant tous les objectifs d'epargne
class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(activeGoalsProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: const Text(
          'Mes Objectifs',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return GoalCard(
                goal: goal,
                onFeedPressed: () => _onFeedGoal(context, goal),
                onDeletePressed: () => _onDeleteGoal(context, ref, goal),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addGoal(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun objectif',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Creez votre premier objectif d\'epargne',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addGoal(context),
            icon: const Icon(Icons.add),
            label: const Text('Creer un objectif'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addGoal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
    );
  }

  void _onFeedGoal(BuildContext context, GoalsTableData goal) {
    FeedGoalBottomSheet.show(context, goal);
  }

  void _onDeleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => DeleteGoalDialog(goal: goal),
    );

    // If result is null, user cancelled or pressed outside
    if (result == null || result['confirmed'] != true) return;

    final repo = ref.read(goalRepositoryProvider);
    final selectedAccount = result['account'] as AccountsTableData?;

    if (selectedAccount != null && goal.savedAmount > 0) {
      // Option 1 : Rembourser
      await repo.deleteGoalWithRefund(
        goalId: goal.id,
        goalName: goal.name,
        savedAmount: goal.savedAmount,
        accountId: selectedAccount.id,
      );
    } else {
      // Option 2 : Supprimer sans remboursement (ou objectif vide)
      await repo.deleteGoal(goal.id);
    }

    // Invalidate providers to refresh the list and transaction/account balances
    ref.invalidate(activeGoalsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${goal.name}" a été supprimé',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
