import 'package:shared_preferences/shared_preferences.dart';

/// Service de préférences de notifications
///
/// Stocke les paramètres de notification via SharedPreferences.
/// Singleton pour un accès global.
class NotificationPreferences {
  static final NotificationPreferences _instance =
      NotificationPreferences._internal();

  factory NotificationPreferences() => _instance;

  NotificationPreferences._internal();

  SharedPreferences? _prefs;

  // ==================== KEYS ====================
  static const String _keyEnabled = 'notif_enabled';
  static const String _keyDebtEnabled = 'notif_debt_enabled';
  static const String _keyDebtDays = 'notif_debt_days';
  static const String _keyDebtHour = 'notif_debt_hour';
  static const String _keyLowBalanceEnabled = 'notif_low_balance_enabled';
  static const String _keyLowBalanceThreshold = 'notif_low_balance_threshold';
  static const String _keyGoalEnabled = 'notif_goal_enabled';
  static const String _keyGoalDay = 'notif_goal_day';
  static const String _keyGoalHour = 'notif_goal_hour';
  static const String _keySummaryEnabled = 'notif_summary_enabled';
  static const String _keySummaryDay = 'notif_summary_day';
  static const String _keySummaryHour = 'notif_summary_hour';

  // ==================== INIT ====================

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  // ==================== MASTER SWITCH ====================

  Future<bool> get isEnabled async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyEnabled, value);
  }

  // ==================== DEBT REMINDERS ====================

  Future<bool> get debtRemindersEnabled async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyDebtEnabled) ?? true;
  }

  Future<void> setDebtRemindersEnabled(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDebtEnabled, value);
  }

  /// Jours avant l'échéance pour les rappels (ex: [1, 3] = J-1, J-3)
  Future<List<int>> get debtReminderDays async {
    final prefs = await _getPrefs();
    final stored = prefs.getStringList(_keyDebtDays);
    if (stored == null) return [1, 3]; // Défaut: J-1 et J-3
    return stored.map((s) => int.parse(s)).toList();
  }

  Future<void> setDebtReminderDays(List<int> days) async {
    final prefs = await _getPrefs();
    await prefs.setStringList(
      _keyDebtDays,
      days.map((d) => d.toString()).toList(),
    );
  }

  /// Heure du rappel (0-23)
  Future<int> get debtReminderHour async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyDebtHour) ?? 9;
  }

  Future<void> setDebtReminderHour(int hour) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyDebtHour, hour);
  }

  // ==================== LOW BALANCE ====================

  Future<bool> get lowBalanceEnabled async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyLowBalanceEnabled) ?? true;
  }

  Future<void> setLowBalanceEnabled(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyLowBalanceEnabled, value);
  }

  /// Seuil de solde faible en FCFA
  Future<double> get lowBalanceThreshold async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_keyLowBalanceThreshold) ?? 50000;
  }

  Future<void> setLowBalanceThreshold(double value) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_keyLowBalanceThreshold, value);
  }

  // ==================== GOAL REMINDERS ====================

  Future<bool> get goalRemindersEnabled async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyGoalEnabled) ?? true;
  }

  Future<void> setGoalRemindersEnabled(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyGoalEnabled, value);
  }

  /// Jour du rappel objectif (1=lundi ... 7=dimanche)
  Future<int> get goalReminderDay async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyGoalDay) ?? 7; // Dimanche par défaut
  }

  Future<void> setGoalReminderDay(int day) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyGoalDay, day);
  }

  /// Heure du rappel objectif (0-23)
  Future<int> get goalReminderHour async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyGoalHour) ?? 10;
  }

  Future<void> setGoalReminderHour(int hour) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyGoalHour, hour);
  }

  // ==================== WEEKLY SUMMARY ====================

  Future<bool> get weeklySummaryEnabled async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keySummaryEnabled) ?? true;
  }

  Future<void> setWeeklySummaryEnabled(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keySummaryEnabled, value);
  }

  /// Jour du résumé (1=lundi ... 7=dimanche)
  Future<int> get weeklySummaryDay async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keySummaryDay) ?? 7; // Dimanche par défaut
  }

  Future<void> setWeeklySummaryDay(int day) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keySummaryDay, day);
  }

  /// Heure du résumé (0-23)
  Future<int> get weeklySummaryHour async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keySummaryHour) ?? 18;
  }

  Future<void> setWeeklySummaryHour(int hour) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keySummaryHour, hour);
  }

  // ==================== HELPERS ====================

  /// Nom du jour de la semaine en français
  static String dayName(int day) {
    const days = {
      1: 'Lundi',
      2: 'Mardi',
      3: 'Mercredi',
      4: 'Jeudi',
      5: 'Vendredi',
      6: 'Samedi',
      7: 'Dimanche',
    };
    return days[day] ?? 'Dimanche';
  }

  /// Formatte une heure (ex: 9 -> "09:00")
  static String formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
  }
}
