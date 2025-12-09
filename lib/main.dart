import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sika_app/core/database/app_database.dart';
import 'package:sika_app/core/notifications/notification_controller.dart';
import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/features/sms_listener/data/services/background_sms_service.dart';
import 'package:sika_app/features/transactions/presentation/screens/home_screen.dart';

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

  // Initialise la base de données
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
    // debugPrint('🏗️ [SikaApp] Building MaterialApp');
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

      // Écran d'accueil
      home: const HomeScreen(),
    );
  }
}
