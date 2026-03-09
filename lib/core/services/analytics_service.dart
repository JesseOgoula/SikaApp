import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sika_app/core/utils/logger.dart';

/// Service centralisé pour la gestion de l'analytique et du monitoring
class AnalyticsService {
  /// Initialise PostHog avec la clé depuis .env
  static Future<void> init() async {
    try {
      final apiKey = dotenv.env['POSTHOG_API_KEY'] ?? '';
      final host = dotenv.env['POSTHOG_HOST'] ?? 'https://eu.i.posthog.com';

      if (apiKey.isEmpty) {
        SikaLogger.warn(
          'POSTHOG_API_KEY non trouvée dans .env',
          tag: 'ANALYTICS',
        );
        return;
      }

      final config = PostHogConfig(apiKey);
      config.host = host;
      config.captureApplicationLifecycleEvents = true;

      await Posthog().setup(config);
      SikaLogger.info('PostHog initialisé', tag: 'ANALYTICS');
    } catch (e) {
      SikaLogger.error('Erreur init PostHog: $e', tag: 'ANALYTICS');
    }
  }

  /*
   * POSTHOG : Événements clés pour SikaApp
   * - auth_started : L'utilisateur clique sur Google Sign In
   * - auth_completed : Connexion Google réussie
   * - onboarding_started : L'utilisateur voit l'écran de création du premier compte
   * - account_created : L'utilisateur ajoute son premier compte
   * - onboarding_completed : Le setup initial est totalement terminé
   * - transaction_added : L'utilisateur saisit une transaction (propriété {method: manual/ocr})
   * - goal_created : L'utilisateur définit un objectif
   */

  /// Enregistre un événement dans PostHog
  static Future<void> logEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    try {
      await Posthog().capture(eventName: eventName, properties: properties);
    } catch (e) {
      await Sentry.captureException(
        e,
        hint: Hint.withMap({'event': eventName}),
      );
    }
  }

  /// Associe l'utilisateur courant à ses actions (PostHog + Sentry)
  static Future<void> identifyUser(String userId, {String? email}) async {
    try {
      // Identifier sur PostHog
      await Posthog().identify(
        userId: userId,
        userProperties: email != null ? {'email': email} : null,
      );

      // Identifier sur Sentry
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId, email: email));
      });
    } catch (e) {
      await Sentry.captureException(
        e,
        hint: Hint.withMap({'action': 'identifyUser'}),
      );
    }
  }

  /// Efface l'identité de l'utilisateur (Déconnexion)
  static Future<void> reset() async {
    try {
      // Reset PostHog
      await Posthog().reset();

      // Reset Sentry
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });
    } catch (e) {
      await Sentry.captureException(
        e,
        hint: Hint.withMap({'action': 'resetUser'}),
      );
    }
  }
}
