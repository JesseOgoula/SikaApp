import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/core/services/notification_preferences.dart';
import 'package:sika_app/core/services/auto_sync_service.dart';
import 'package:sika_app/features/notification_sync/data/services/notification_sync_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/utils/logger.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/constants/supabase_constants.dart';
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:sika_app/features/auth/presentation/screens/login_screen.dart';
import 'package:sika_app/core/widgets/privacy_shield.dart';
import 'package:sika_app/core/services/security_service.dart';
import 'package:sika_app/core/services/app_lock_service.dart';
import 'package:sika_app/core/services/analytics_service.dart';
import 'package:sika_app/features/accounts/presentation/widgets/account_setup_checker.dart';
import 'package:sika_app/features/auth/presentation/screens/setup_security_screen.dart';
import 'package:sika_app/features/auth/presentation/screens/app_lock_screen.dart';

/// Instance globale d'AutoSyncService
AutoSyncService? autoSyncService;

void main() async {
  SikaLogger.info('Starting app initialization...', tag: 'MAIN');

  // Assure que les bindings Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  SikaLogger.info('WidgetsFlutterBinding initialized', tag: 'MAIN');

  // Charge les variables d'environnement (.env)
  try {
    await dotenv.load(fileName: '.env');
    SikaLogger.info('Environment variables loaded', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error loading .env: $e', tag: 'MAIN');
  }

  // Initialise les données de localisation pour le formatage des dates
  try {
    await initializeDateFormatting('fr_FR', null);
    SikaLogger.info('Locale initialized', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error initializing locale: $e', tag: 'MAIN');
  }

  // Initialise Supabase
  try {
    SikaLogger.info('Initializing Supabase...', tag: 'MAIN');
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
    SikaLogger.info('Supabase initialized', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error initializing Supabase: $e', tag: 'MAIN');
  }

  // Note: PowerSync désactivé - utilise AutoSyncService à la place
  // pour synchroniser directement avec Supabase
  // 6. Initialise la base de données Drift (locale)
  late final AppDatabase database;
  try {
    database = AppDatabase();
    // Force sync de toutes les catégories existantes (une seule fois au démarrage)
    await database.customUpdate(
      'UPDATE categories SET sync_status = 0 WHERE sync_status = 1',
      updates: {database.categoriesTable},
    );
  } catch (e) {
    SikaLogger.error('CRITICAL ERROR IN DATABASE INIT: $e', tag: 'MAIN');
    return; // Impossible de continuer sans base de données
  }

  // Initialise AutoSyncService pour la synchronisation automatique
  try {
    autoSyncService = AutoSyncService(database);
    autoSyncService!.startListening();
  } catch (e) {
    /* ignore */
  }

  // Init Notification Services
  try {
    await NotificationPreferences().init();
    await NotificationService().init();
    await NotificationService().requestPermissions();
  } catch (e) {
    SikaLogger.error('Failed to init basic notifications: $e', tag: 'MAIN');
  }

  // Auto-detection sync service (indépendant pour ne pas être bloqué)
  try {
    await NotificationSyncService().init(database);
  } catch (e) {
    SikaLogger.error('Failed to init NotificationSyncService: $e', tag: 'MAIN');
  }

  // Init PostHog Analytics (clé chargée depuis .env, plus dans les manifests natifs)
  try {
    await AnalyticsService.init();
  } catch (e) {
    /* ignore */
  }

  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://0e879dedaea1a1698e26073922c6957e@o4511013665964032.ingest.de.sentry.io/4511013669306448';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const SikaApp(),
      ),
    ),
  );
}

/// Provider pour la base de données (override dans main)
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

class SikaApp extends StatelessWidget {
  const SikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIKA',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return PrivacyShield(child: child!);
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _showSplash = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDeviceSecure = true;
  bool _isLocallyAuthenticated = false;
  bool _securitySetupDone = false;
  bool _securityChecked = false;

  final _appLock = AppLockService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurity();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Attendre 2 secondes puis masquer le splash
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Re-verrouille l'app quand elle revient au premier plan
  /// (fermeture, mise en veille, verrouillage du téléphone)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Quand l'app revient au premier plan, on re-verrouille
      // seulement si la sécurité a été configurée, l'utilisateur est authentifié,
      // et que le verrouillage n'a pas été désactivé dans les paramètres
      final lockEnabled = await _appLock.isLockEnabled();
      if (_securitySetupDone && _isLocallyAuthenticated && lockEnabled) {
        setState(() => _isLocallyAuthenticated = false);
      }
    }
  }

  Future<void> _checkSecurity() async {
    final security = SecurityService();
    final isSecure = await security.checkDeviceIntegrity();
    if (!mounted) return;
    setState(() => _isDeviceSecure = isSecure);

    if (!isSecure) return;

    // Vérifie si le setup sécurité a été fait
    final setupDone = await _appLock.isSecuritySetupDone();
    final lockEnabled = await _appLock.isLockEnabled();

    if (!mounted) return;
    setState(() {
      _securitySetupDone = setupDone;
      _securityChecked = true;
    });

    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.authenticated && lockEnabled) {
      // Ne pas marquer comme authentifié — le lock screen s'affichera
      setState(() => _isLocallyAuthenticated = false);
    } else {
      setState(() => _isLocallyAuthenticated = true);
    }
  }

  void _onSecuritySetupComplete() {
    setState(() {
      _securitySetupDone = true;
      _isLocallyAuthenticated = true;
    });
  }

  void _onUnlocked() {
    setState(() => _isLocallyAuthenticated = true);
  }

  Future<void> _onForgotPin() async {
    // Réinitialise la sécurité et déconnecte
    await _appLock.clearSecurity();
    if (!mounted) return;
    ref.read(authControllerProvider.notifier).logout();
    setState(() {
      _securitySetupDone = false;
      _isLocallyAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Écran Rouge si sécurité compromise
    if (!_isDeviceSecure) {
      return Scaffold(
        backgroundColor: const Color(0xFFEF4444),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.security_update_warning,
                  size: 80,
                  color: Colors.white,
                ),
                SizedBox(height: 24),
                Text(
                  'Sécurité Compromise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Désolé, SIKA ne peut pas s\'exécuter sur un appareil rooté ou en mode développeur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showSplash) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A237E),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/logowhite.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Image.asset(
                  'assets/images/logo2.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (authState.status) {
      case AuthStatus.authenticated:
        // Étape 1 : Si la config sécurité n'a pas été faite → setup obligatoire
        if (_securityChecked && !_securitySetupDone) {
          return SetupSecurityScreen(onComplete: _onSecuritySetupComplete);
        }

        // Étape 2 : Si pas encore déverrouillé localement → lock screen
        if (!_isLocallyAuthenticated) {
          return AppLockScreen(
            onUnlocked: _onUnlocked,
            onForgotPin: _onForgotPin,
          );
        }

        // Étape 3 : Accès à l'app
        return const AccountSetupChecker();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();

      default: // Loading or Initial
        return const Scaffold(
          backgroundColor: Color(0xFF1A237E),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
    }
  }
}
