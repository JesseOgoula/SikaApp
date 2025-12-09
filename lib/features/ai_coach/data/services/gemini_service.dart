import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sika_app/core/constants/api_constants.dart';
import 'package:sika_app/features/analytics/domain/entities/category_stat.dart';

/// Service d'IA Coach financier utilisant Google Gemini
class GeminiService {
  late final GenerativeModel _model;
  bool _isInitialized = false;

  /// Initialise le modèle Gemini
  void initialize() {
    if (_isInitialized) return;

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: GEMINI_API_KEY,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 256,
      ),
    );
    _isInitialized = true;
  }

  /// Analyse le budget et retourne un conseil personnalisé
  ///
  /// [stats] : Liste des dépenses par catégorie
  /// [totalIncome] : Revenus totaux du mois (optionnel)
  Future<String> analyzeBudget(
    List<CategoryStat> stats, {
    double? totalIncome,
  }) async {
    if (!_isInitialized) initialize();

    if (stats.isEmpty) {
      return "Je n'ai pas assez de données pour t'analyser ce mois-ci. Continue à enregistrer tes transactions !";
    }

    // Construire le JSON des dépenses
    final expensesJson = stats
        .map((s) {
          return '{"categorie": "${s.categoryName}", "montant": ${s.totalAmount.toStringAsFixed(0)}, "pourcentage": ${s.percentage.toStringAsFixed(1)}}';
        })
        .join(', ');

    final totalExpenses = stats.fold<double>(
      0,
      (sum, s) => sum + s.totalAmount,
    );

    final prompt =
        '''
Tu es un conseiller financier expert pour le marché africain (Gabon). Ton ton est bienveillant, direct et motivant (tutoiement).
Analyse les dépenses suivantes et donne 1 conseil précis et actionnable en 3 phrases maximum.
Utilise la devise FCFA. Ne sois pas générique. Sois spécifique à la situation.

Données du mois :
- Total dépenses : ${totalExpenses.toStringAsFixed(0)} FCFA
${totalIncome != null ? '- Revenus : ${totalIncome.toStringAsFixed(0)} FCFA' : ''}
- Répartition : [$expensesJson]

Conseil :''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final text = response.text;
      if (text == null || text.isEmpty) {
        return "Désolé, je n'ai pas pu analyser tes dépenses. Réessaie plus tard.";
      }

      return text.trim();
    } catch (e) {
      print('Erreur Gemini: $e');
      return "Impossible de contacter l'IA pour le moment. Vérifie ta connexion internet.";
    }
  }
}

/// Instance singleton du service
final geminiService = GeminiService();
