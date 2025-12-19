import '../entities/debt.dart';

abstract class DebtRepository {
  /// Récupère la liste de toutes les dettes et factures
  Stream<List<Debt>> watchAllDebts();

  /// Récupère le total "Reste à vivre" (Safe-to-Spend)
  /// Retourne le montant des factures en attente pour le mois en cours
  Stream<double> watchPendingBillsAmountForCurrentMonth();

  /// Ajoute une nouvelle dette ou facture
  Future<void> addDebt(Debt debt);

  /// Met à jour une dette ou facture
  Future<void> updateDebt(Debt debt);

  /// Supprime une dette ou facture
  Future<void> deleteDebt(String id);

  /// Vérifie et marque les dettes en retard comme 'overdue'
  Future<void> checkOverdueDebts();

  /// Marque une dette comme payée
  /// Si [createTransaction] est vrai, crée automatiquement une transaction de dépense
  Future<void> markAsPaid(
    Debt debt, {
    bool createTransaction = true,
    String? accountId,
    String? categoryId,
  });
}
