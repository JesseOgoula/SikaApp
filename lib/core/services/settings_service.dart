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

  // ==================== RESET ====================

  /// Réinitialise tous les paramètres
  Future<void> resetAll() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    await prefs.clear();
  }
}
