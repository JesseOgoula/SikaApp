import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des préférences utilisateur
class SettingsService {
  static const String _keyAutoSave = 'auto_save_enabled';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyLastSyncDate = 'last_sync_date';

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Initialise le service (doit être appelé au démarrage)
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    } catch (e) {
      // Ignore les erreurs d'initialisation
      _isInitialized = false;
    }
  }

  /// Vérifie si le service est initialisé
  bool get isInitialized => _isInitialized && _prefs != null;

  /// Assure que les prefs sont chargées (DÉFENSIF - pas de !)
  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs; // Retourne nullable, pas de !
  }

  // ==================== AUTO-SAVE SETTING ====================

  /// Indique si l'enregistrement automatique est activé
  /// Retourne false par défaut si les prefs ne sont pas disponibles
  Future<bool> isAutoSaveEnabled() async {
    final prefs = await _getPrefs();
    if (prefs == null) return false;
    return prefs.getBool(_keyAutoSave) ?? false;
  }

  /// Active ou désactive l'enregistrement automatique
  Future<void> setAutoSaveEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setBool(_keyAutoSave, enabled);
  }

  /// Bascule le mode auto-save
  Future<bool> toggleAutoSave() async {
    final current = await isAutoSaveEnabled();
    await setAutoSaveEnabled(!current);
    return !current;
  }

  // ==================== NOTIFICATIONS SETTING ====================

  /// Indique si les notifications sont activées
  Future<bool> areNotificationsEnabled() async {
    final prefs = await _getPrefs();
    if (prefs == null) return true;
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Active ou désactive les notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  // ==================== SYNC TRACKING ====================

  /// Récupère la date du dernier sync
  Future<DateTime?> getLastSyncDate() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    final timestamp = prefs.getInt(_keyLastSyncDate);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Enregistre la date du dernier sync
  Future<void> setLastSyncDate(DateTime date) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setInt(_keyLastSyncDate, date.millisecondsSinceEpoch);
  }

  /// Marque le sync actuel
  Future<void> markSyncNow() async {
    await setLastSyncDate(DateTime.now());
  }

  // ==================== RANK TRACKING ====================

  static const String _keyPreviousRankLevel = 'previous_rank_level';
  static const String _keyTotalXP = 'total_xp';
  static const String _keyDailyStreak = 'daily_streak';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyLastBudgetCheckMonth = 'last_budget_check_month';

  /// Récupère le niveau de rang précédent (pour détecter les transitions)
  Future<int> getPreviousRankLevel() async {
    final prefs = await _getPrefs();
    if (prefs == null) return 1;
    return prefs.getInt(_keyPreviousRankLevel) ?? 1;
  }

  /// Enregistre le niveau de rang actuel
  Future<void> setPreviousRankLevel(int level) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setInt(_keyPreviousRankLevel, level);
  }

  /// Récupère le total XP accumulé
  Future<int> getTotalXP() async {
    final prefs = await _getPrefs();
    if (prefs == null) return 0;
    return prefs.getInt(_keyTotalXP) ?? 0;
  }

  /// Enregistre le total XP
  Future<void> setTotalXP(int xp) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setInt(_keyTotalXP, xp);
  }

  /// Récupère le streak de connexion (jours consécutifs)
  Future<int> getDailyStreak() async {
    final prefs = await _getPrefs();
    if (prefs == null) return 0;
    return prefs.getInt(_keyDailyStreak) ?? 0;
  }

  /// Enregistre le streak de connexion
  Future<void> setDailyStreak(int streak) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setInt(_keyDailyStreak, streak);
  }

  /// Récupère la dernière date de connexion
  Future<DateTime?> getLastLoginDate() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    final dateStr = prefs.getString(_keyLastLoginDate);
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Enregistre la dernière date de connexion
  Future<void> setLastLoginDate(DateTime date) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyLastLoginDate, date.toIso8601String());
  }

  // ==================== BUDGET CHECK TRACKING ====================

  /// Récupère le dernier mois vérifié pour les budgets (format "YYYY-MM")
  Future<String?> getLastBudgetCheckMonth() async {
    final prefs = await _getPrefs();
    if (prefs == null) return null;
    return prefs.getString(_keyLastBudgetCheckMonth);
  }

  /// Enregistre le mois vérifié pour les budgets
  Future<void> setLastBudgetCheckMonth(String monthKey) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.setString(_keyLastBudgetCheckMonth, monthKey);
  }

  // ==================== RESET ====================

  /// Réinitialise tous les paramètres
  Future<void> resetAll() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.clear();
  }
}
