import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sika_app/core/constants/api_constants.dart';
import 'package:sika_app/core/utils/logger.dart';

/// Résultat du scan d'une facture
class ReceiptScanResult {
  final double? amount;
  final String? description;
  final String? suggestedCategory;

  const ReceiptScanResult({
    this.amount,
    this.description,
    this.suggestedCategory,
  });

  bool get hasData => amount != null || description != null;

  @override
  String toString() =>
      'ReceiptScanResult(amount: $amount, description: $description, category: $suggestedCategory)';
}

/// Service d'analyse de factures par IA via OpenRouter (Gemini 3 Flash)
///
/// Envoie une photo de facture à l'API OpenRouter et extrait :
/// - Le montant total
/// - Une description courte
/// - Une suggestion de catégorie
class ReceiptScannerService {
  static const String _model = 'google/gemini-3-flash-preview';

  /// Analyse une image de facture et extrait les informations clés
  ///
  /// [imageFile] : Le fichier image de la facture
  /// [categoryNames] : Liste des noms de catégories disponibles dans l'app
  ///
  /// Retourne un [ReceiptScanResult] avec les données extraites
  static Future<ReceiptScanResult> scanReceipt({
    required File imageFile,
    required List<String> categoryNames,
  }) async {
    try {
      SikaLogger.info('Début du scan de facture...', tag: 'OCR');

      // Encode l'image en base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Détecte le type MIME
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      // Construit le prompt avec les catégories disponibles
      final categoriesList = categoryNames.join(', ');
      final prompt =
          '''Analyse cette image de facture/reçu/ticket de caisse.

Extrais les informations suivantes et retourne UNIQUEMENT un JSON valide, sans markdown, sans commentaire :

{
  "amount": <montant total en nombre décimal, ou null si introuvable>,
  "description": "<description courte de la facture en 5-10 mots, ou null si indéterminable>",
  "category": "<catégorie la plus appropriée parmi: $categoriesList, ou null si aucune ne convient>"
}

Règles :
- Le montant doit être le TOTAL à payer (TTC), pas un sous-total
- Si la devise est en FCFA/XAF, garde juste le nombre
- La description doit résumer le contenu de la facture (ex: "Courses alimentaires au supermarché")  
- Pour la catégorie, choisis EXACTEMENT un des noms fournis dans la liste
- Si l'image n'est pas une facture, retourne {"amount": null, "description": null, "category": null}''';

      // Appel API OpenRouter
      final response = await http.post(
        Uri.parse('$OPENROUTER_BASE_URL/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $OPENROUTER_API_KEY',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
                },
                {'type': 'text', 'text': prompt},
              ],
            },
          ],
          'max_tokens': 500,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode != 200) {
        SikaLogger.error(
          'Erreur API OpenRouter: ${response.statusCode} - ${response.body}',
          tag: 'OCR',
        );
        throw Exception('Erreur du service OCR (${response.statusCode})');
      }

      // Parse la réponse
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          responseData['choices'][0]['message']['content'] as String;

      SikaLogger.info('Réponse IA brute: $content', tag: 'OCR');

      return _parseResponse(content);
    } catch (e) {
      SikaLogger.error('Erreur scan facture: $e', tag: 'OCR');
      rethrow;
    }
  }

  /// Parse la réponse JSON de l'IA
  static ReceiptScanResult _parseResponse(String content) {
    try {
      // Nettoie la réponse (enlève les backticks markdown si présents)
      var cleanContent = content.trim();
      if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent
            .replaceFirst(RegExp(r'^```\w*\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(cleanContent) as Map<String, dynamic>;

      double? amount;
      if (json['amount'] != null) {
        amount = (json['amount'] is int)
            ? (json['amount'] as int).toDouble()
            : (json['amount'] as num).toDouble();
      }

      return ReceiptScanResult(
        amount: amount,
        description: json['description'] as String?,
        suggestedCategory: json['category'] as String?,
      );
    } catch (e) {
      SikaLogger.error('Erreur parsing réponse IA: $e', tag: 'OCR');
      return const ReceiptScanResult();
    }
  }
}
