import 'package:flutter/material.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/core/services/auto_sync_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/utils/logger.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/notifications/notification_controller.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/constants/supabase_constants.dart';
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:sika_app/features/auth/presentation/screens/login_screen.dart';
import 'package:sika_app/core/widgets/privacy_shield.dart';
import 'package:sika_app/core/services/security_service.dart';
import 'package:sika_app/features/accounts/presentation/widgets/account_setup_checker.dart';

/// Instance globale d'AutoSyncService
AutoSyncService? autoSyncService;

void main() async {
  SikaLogger.info('Starting app initialization...', tag: 'MAIN');

  // Assure que les bindings Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  SikaLogger.info('WidgetsFlutterBinding initialized', tag: 'MAIN');

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
  debugPrint('🔄 [MAIN] PowerSync disabled - using AutoSyncService instead');

  // 6. Initialise la base de données Drift (locale)
  late final AppDatabase database;
  try {
    debugPrint('⏳ [MAIN] Initializing AppDatabase...');
    database = AppDatabase();
    debugPrint('✅ [MAIN] AppDatabase instance created');

    // Force sync de toutes les catégories existantes (une seule fois au démarrage)
    await database.customUpdate(
      'UPDATE categories SET sync_status = 0 WHERE sync_status = 1',
      updates: {database.categoriesTable},
    );
    debugPrint('🔄 [MAIN] Categories marked for sync');
  } catch (e) {
    SikaLogger.error('CRITICAL ERROR IN DATABASE INIT: $e', tag: 'MAIN');
    return; // Impossible de continuer sans base de données
  }

  // Initialise AutoSyncService pour la synchronisation automatique
  try {
    debugPrint('🔄 [MAIN] Initializing AutoSyncService...');
    autoSyncService = AutoSyncService(database);
    autoSyncService!.startListening();
    debugPrint('✅ [MAIN] AutoSyncService started');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing AutoSyncService: $e');
  }

  // Initialise le contrôleur de notifications
  try {
    SikaLogger.info('Initializing NotificationController...', tag: 'MAIN');
    await NotificationController.initialize();
    SikaLogger.info('NotificationController initialized', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error(
      'Error initializing NotificationController: $e',
      tag: 'MAIN',
    );
  }

  // Init Notification Services
  try {
    debugPrint('📱 [MAIN] Initializing NotificationService...');
    await NotificationService().init();
    await NotificationService().requestPermissions();
    await NotificationService().scheduleWeeklySummary();
    debugPrint('✅ [MAIN] NotificationService initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing NotificationService: $e');
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const SikaApp(),
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
    with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDeviceSecure = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSecurity() async {
    final security = SecurityService();
    final isSecure = await security.checkDeviceIntegrity();
    if (!mounted) return;
    setState(() => _isDeviceSecure = isSecure);

    if (!isSecure) return;

    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.authenticated) {
      final authenticated = await security.authenticate();
      if (mounted) setState(() => _isAuthenticated = authenticated);
    } else {
      // Si pas encore connecté, pas besoin de bio maintenant
      setState(() => _isAuthenticated = true);
    }
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

    if (_showSplash || !_isAuthenticated) {
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
