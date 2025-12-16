import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart'; // import databaseProvider
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../repositories/debt_repository_impl.dart';

/// Provider du repository
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DebtRepositoryImpl(db, ref);
});

/// Stream de toutes les dettes
final allDebtsProvider = StreamProvider<List<Debt>>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.watchAllDebts();
});

/// Stream des dettes filtrées (pour les onglets)
/// [type] peut être 'bill', 'debt_in', 'debt_out'
final debtsByTypeProvider = StreamProvider.family<List<Debt>, DebtType>((
  ref,
  type,
) {
  return ref.watch(allDebtsProvider.stream).map((debts) {
    return debts.where((d) => d.type == type).toList();
  });
});

/// Stream du montant "Reste à vivre" engagé (Factures du mois)
final pendingBillsAmountProvider = StreamProvider<double>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return repository.watchPendingBillsAmountForCurrentMonth();
});
