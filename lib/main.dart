import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart' hide Column;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/database/supabase_connector.dart';
import 'package:sika_app/core/database/powersync_schema.dart';
import 'package:sika_app/core/notifications/notification_controller.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/core/constants/supabase_constants.dart';
import 'package:sika_app/features/sms_listener/data/services/background_sms_service.dart';
import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';
import 'package:sika_app/features/auth/presentation/screens/login_screen.dart';
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';

/// Instance globale de PowerSyncDatabase pour l'accès depuis AuthRepository
PowerSyncDatabase? powerSyncDatabase;

void main() async {
  debugPrint('🚀 [MAIN] Starting app initialization...');

  // Assure que les bindings Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ [MAIN] WidgetsFlutterBinding initialized');

  // Initialise les données de localisation pour le formatage des dates
  try {
    await initializeDateFormatting('fr_FR', null);
    debugPrint('✅ [MAIN] Locale initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing locale: $e');
  }

  // Initialise Supabase
  try {
    debugPrint('☁️ [MAIN] Initializing Supabase...');
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );
    debugPrint('✅ [MAIN] Supabase initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing Supabase: $e');
  }

  // Initialise PowerSync
  try {
    debugPrint('🔄 [MAIN] Initializing PowerSync...');
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sika_powersync.db');

    powerSyncDatabase = PowerSyncDatabase(schema: schema, path: dbPath);

    // Initialise la DB PowerSync
    await powerSyncDatabase!.initialize();

    // Configure le connector Supabase
    final connector = SupabaseConnector();

    // Si l'utilisateur est déjà connecté, démarre la synchro
    if (Supabase.instance.client.auth.currentSession != null) {
      await powerSyncDatabase!.connect(connector: connector);
      debugPrint('✅ [MAIN] PowerSync connected (user was logged in)');
    } else {
      debugPrint('⏸️ [MAIN] PowerSync initialized (waiting for login)');
    }

    debugPrint('✅ [MAIN] PowerSync initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing PowerSync: $e');
  }

  // Initialise la base de données Drift (locale)
  late final AppDatabase database;
  try {
    debugPrint('⏳ [MAIN] Initializing AppDatabase...');
    database = AppDatabase();
    debugPrint('✅ [MAIN] AppDatabase instance created');
  } catch (e) {
    debugPrint('❌ [MAIN] CRITICAL ERROR IN DATABASE INIT: $e');
    return; // Impossible de continuer sans base de données
  }

  // Initialise le contrôleur de notifications
  try {
    debugPrint('🔔 [MAIN] Initializing NotificationController...');
    await NotificationController.initialize();
    debugPrint('✅ [MAIN] NotificationController initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing NotificationController: $e');
  }

  // Initialise le service SMS background
  try {
    debugPrint('📩 [MAIN] Initializing BackgroundSmsService...');
    final smsService = BackgroundSmsService();
    smsService.setDatabase(database);
    await smsService.startListening();
    debugPrint('✅ [MAIN] BackgroundSmsService initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing BackgroundSmsService: $e');
  }

  runApp(
    // Wrap avec ProviderScope pour Riverpod
    ProviderScope(
      overrides: [
        // Override le provider de base de données avec notre instance
        databaseProvider.overrideWithValue(database),
      ],
      child: const SikaApp(),
    ),
  );
}

/// Provider pour la base de données (override dans main)
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// Application principale SIKA
class SikaApp extends StatelessWidget {
  const SikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIKA',
      debugShowCheckedModeBanner: false,

      // Localisation française
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Thème Neo-Bank Pro (Light)
      theme: AppTheme.lightTheme,

      // Auth Gate - Redirection intelligente
      home: const _AuthGate(),
    );
  }
}

/// AuthGate - Redirige vers LoginScreen ou HomeScreen selon l'état de connexion
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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Affiche le splash screen pendant le chargement initial
    if (_showSplash) {
      return Scaffold(
        backgroundColor: const Color(0xFF303F9F),
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
              // Logo centré
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
              // Branding en bas
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

    // Après le splash, redirige selon l'état d'authentification
    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const Scaffold(
          backgroundColor: Color(0xFF303F9F),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );

      case AuthStatus.authenticated:
        return const HomeScreen();

      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
    }
  }
}
