/// SMS Parser Feature
///
/// Module de parsing des SMS bancaires et Mobile Money pour le marché gabonais.
///
/// Opérateurs supportés:
/// - Airtel Money
/// - Moov Money
/// - UBA
///
/// Usage:
/// ```dart
/// import 'package:sika_app/features/sms_parser/sms_parser.dart';
///
/// final parser = SmsParserService();
/// final result = parser.parseSms('AirtelMoney', 'Paiement effectué...');
/// ```
library;

// Domain
export 'domain/entities/parsed_transaction.dart';

// Data - Services
export 'data/services/sms_parser_service.dart';
export 'data/services/sms_import_service.dart';

// Data - Providers
export 'data/providers/sms_providers.dart';
