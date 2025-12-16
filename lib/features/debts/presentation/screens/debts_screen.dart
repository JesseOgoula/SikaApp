import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import '../../data/providers/debt_providers.dart';
import '../../domain/entities/debt.dart';
import 'add_debt_screen.dart'; // To be created

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Engagements'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'À Payer'),
            Tab(text: 'On me doit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DebtsList(typeFilter: [DebtType.bill, DebtType.debtOut]),
          _DebtsList(typeFilter: [DebtType.debtIn]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDebtScreen()),
          );
        },
        label: const Text('Ajouter'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

class _DebtsList extends ConsumerWidget {
  final List<DebtType> typeFilter;

  const _DebtsList({required this.typeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDebtsAsync = ref.watch(allDebtsProvider);

    return allDebtsAsync.when(
      data: (allDebts) {
        final filteredDebts = allDebts
            .where((d) => typeFilter.contains(d.type))
            .toList();

        if (filteredDebts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 64,
                  color: AppTheme.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun engagement',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDebts.length,
          itemBuilder: (context, index) {
            final debt = filteredDebts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: _getColorForType(debt.type).withOpacity(0.1),
                  child: Icon(
                    _getIconForType(debt.type),
                    color: _getColorForType(debt.type),
                  ),
                ),
                title: Text(
                  debt.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Échéance : ${_formatDate(debt.dueDate)}',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${debt.amount.toStringAsFixed(0)} F',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _getColorForType(debt.type),
                      ),
                    ),
                    if (debt.status == DebtStatus.paid)
                      const Text(
                        'Payé',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                  ],
                ),
                onTap: () {
                  if (debt.status == DebtStatus.paid) return;

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        debt.type == DebtType.debtIn
                            ? 'Confirmer réception ?'
                            : 'Confirmer paiement ?',
                      ),
                      content: Text(
                        'Voulez-vous marquer "${debt.name}" comme ${debt.type == DebtType.debtIn ? 'reçu' : 'payé'} ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(debtRepositoryProvider).markAsPaid(debt);
                            Navigator.pop(context);
                          },
                          child: const Text('Confirmer'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }

  Color _getColorForType(DebtType type) {
    switch (type) {
      case DebtType.bill:
        return Colors.orange;
      case DebtType.debtOut:
        return Colors.redAccent;
      case DebtType.debtIn:
        return Colors.greenAccent;
    }
  }

  IconData _getIconForType(DebtType type) {
    switch (type) {
      case DebtType.bill:
        return Icons.receipt_long;
      case DebtType.debtOut:
        return Icons.money_off;
      case DebtType.debtIn:
        return Icons.attach_money;
    }
  }

  String _formatDate(DateTime date) {
    // Basic formatting
    return '${date.day}/${date.month}/${date.year}';
  }
}
