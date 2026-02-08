import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqlite3/open.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_app/core/utils/logger.dart';
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
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:sika_app/features/auth/presentation/screens/login_screen.dart';
import 'package:sika_app/core/widgets/privacy_shield.dart';
import 'package:sika_app/core/utils/encryption_utils.dart';
import 'package:sika_app/core/services/security_service.dart';

/// Instance globale de PowerSyncDatabase pour l'accès depuis AuthRepository
PowerSyncDatabase? powerSyncDatabase;

void main() async {
  // Override SQLite library on Android to use SQLCipher
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, () {
      return DynamicLibrary.open('libsqlcipher.so');
    });
  }

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

  // 4. Récupère la clé de chiffrement sécurisée
  late final String encryptionKey;
  try {
    encryptionKey = await EncryptionUtils.getDatabaseKey();
    SikaLogger.info('Encryption key loaded', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error loading encryption key: $e', tag: 'MAIN');
    encryptionKey = ''; // Devrait peut-être empêcher le démarrage ici ?
  }

  // 5. Initialise PowerSync
  try {
    SikaLogger.info('Initializing PowerSync...', tag: 'MAIN');
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sika_powersync.db');

    powerSyncDatabase = PowerSyncDatabase(schema: schema, path: dbPath);
    await powerSyncDatabase!.initialize();

    final connector = SupabaseConnector();

    if (Supabase.instance.client.auth.currentSession != null) {
      await powerSyncDatabase!.connect(connector: connector);
      SikaLogger.info('PowerSync connected (user was logged in)', tag: 'MAIN');
    } else {
      SikaLogger.info('PowerSync initialized (waiting for login)', tag: 'MAIN');
    }
  } catch (e) {
    SikaLogger.error('Error initializing PowerSync: $e', tag: 'MAIN');
  }

  // 6. Initialise la base de données Drift (locale) avec chiffrement
  late final AppDatabase database;
  try {
    SikaLogger.info('Initializing AppDatabase (Encrypted)...', tag: 'MAIN');
    database = AppDatabase.encrypted(encryptionKey);
    SikaLogger.info('AppDatabase instance created', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('CRITICAL ERROR IN DATABASE INIT: $e', tag: 'MAIN');
    return; // Impossible de continuer sans base de données
  }

  // Initialise le contrôleur de notifications
  try {
    SikaLogger.info('Initializing NotificationController...', tag: 'MAIN');
    await NotificationController.initialize();
    SikaLogger.info('NotificationController initialized', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error initializing NotificationController: $e', tag: 'MAIN');
  }

  // Initialise le service SMS background
  try {
    SikaLogger.info('Initializing BackgroundSmsService...', tag: 'MAIN');
    final smsService = BackgroundSmsService();
    smsService.setDatabase(database);
    await smsService.startListening();
    SikaLogger.info('BackgroundSmsService initialized', tag: 'MAIN');
  } catch (e) {
    SikaLogger.error('Error initializing BackgroundSmsService: $e', tag: 'MAIN');
  }

  // Init Services
  await NotificationService().init();
  await NotificationService().requestPermissions();

  runApp(
    ProviderScope(
      overrides: [
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

class _AuthGateState extends ConsumerState<_AuthGate> with SingleTickerProviderStateMixin {
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

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
                Icon(Icons.security_update_warning, size: 80, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Sécurité Compromise',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
        return const HomeScreen();

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
