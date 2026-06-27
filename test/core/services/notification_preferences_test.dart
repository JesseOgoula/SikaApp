import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_app/core/services/notification_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NotificationPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // On réinitialise l'instance singleton pour les tests
    // On ne peut pas facilement car c'est un singleton, mais 
    // SharedPreferences.setMockInitialValues() affectera SharedPreferences.getInstance()
    prefs = NotificationPreferences();
    await prefs.init();
  });

  group('NotificationPreferences', () {
    test('devrait avoir les valeurs par défaut correctes', () async {
      expect(await prefs.isEnabled, isTrue);
      expect(await prefs.debtRemindersEnabled, isTrue);
      expect(await prefs.debtReminderDays, equals([1, 3]));
      expect(await prefs.debtReminderHour, equals(9));
      expect(await prefs.lowBalanceEnabled, isTrue);
      expect(await prefs.lowBalanceThreshold, equals(50000));
      expect(await prefs.goalRemindersEnabled, isTrue);
      expect(await prefs.goalReminderDay, equals(7));
      expect(await prefs.goalReminderHour, equals(10));
      expect(await prefs.budgetAlertsEnabled, isTrue);
      expect(await prefs.lastBudgetNotifMonth, isNull);
    });

    test('devrait sauvegarder et lire le master switch', () async {
      await prefs.setEnabled(false);
      expect(await prefs.isEnabled, isFalse);
    });

    test('devrait sauvegarder et lire les rappels de dettes', () async {
      await prefs.setDebtRemindersEnabled(false);
      expect(await prefs.debtRemindersEnabled, isFalse);

      await prefs.setDebtReminderDays([2, 5]);
      expect(await prefs.debtReminderDays, equals([2, 5]));

      await prefs.setDebtReminderHour(14);
      expect(await prefs.debtReminderHour, equals(14));
    });

    test('devrait sauvegarder et lire le solde faible', () async {
      await prefs.setLowBalanceEnabled(false);
      expect(await prefs.lowBalanceEnabled, isFalse);

      await prefs.setLowBalanceThreshold(20000);
      expect(await prefs.lowBalanceThreshold, equals(20000));
    });

    test('devrait sauvegarder et lire les rappels d\'objectifs', () async {
      await prefs.setGoalRemindersEnabled(false);
      expect(await prefs.goalRemindersEnabled, isFalse);

      await prefs.setGoalReminderDay(3); // Mercredi
      expect(await prefs.goalReminderDay, equals(3));

      await prefs.setGoalReminderHour(18);
      expect(await prefs.goalReminderHour, equals(18));
    });

    test('devrait gérer la déduplication mensuelle des budgets', () async {
      await prefs.setBudgetAlertsEnabled(false);
      expect(await prefs.budgetAlertsEnabled, isFalse);

      await prefs.setLastBudgetNotifMonth('cat_Alimentation_2026-06');
      expect(await prefs.lastBudgetNotifMonth, equals('cat_Alimentation_2026-06'));

      await prefs.clearLastBudgetNotifMonth();
      expect(await prefs.lastBudgetNotifMonth, isNull);
    });
  });
}
