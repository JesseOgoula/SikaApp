/// Constantes API pour les services externes
///
/// Les clés API sont chargées depuis le fichier .env via flutter_dotenv.
/// Ne JAMAIS commiter de clés en dur dans ce fichier.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

String get GEMINI_API_KEY => dotenv.env['GEMINI_API_KEY'] ?? '';

// OpenRouter API (OCR Receipt Scanner)
String get OPENROUTER_API_KEY => dotenv.env['OPENROUTER_API_KEY'] ?? '';
String get OPENROUTER_BASE_URL =>
    dotenv.env['OPENROUTER_BASE_URL'] ?? 'https://openrouter.ai/api/v1';
