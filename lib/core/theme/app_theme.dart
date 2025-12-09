import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Thème Neo-Bank Pro pour SIKA
///
/// Style inspiré de Revolut/Apple Wallet avec:
/// - Fond clair (#F4F6F8)
/// - Couleur primaire Bleu Nuit (#1A237E)
/// - Couleur secondaire Ambre/Or (#FFC107)
/// - Police Poppins
class AppTheme {
  // Couleurs principales
  static const Color primaryColor = Color(0xFF1A237E); // Bleu Nuit
  static const Color secondaryColor = Color(0xFFFFC107); // Ambre/Or
  static const Color scaffoldBackground = Color(0xFFF4F6F8); // Gris Perle
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981); // Vert
  static const Color error = Color(0xFFEF4444); // Rouge

  // Gradients pour les cartes
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A237E), // Bleu Nuit
      Color(0xFF311B92), // Violet profond
    ],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7C66), Color(0xFF10B981)],
  );

  /// ThemeData principal
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardBackground,
        error: error,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Couleurs pastel pour les catégories
  static Color getCategoryPastelColor(String? hexColor) {
    if (hexColor == null) return const Color(0xFFE5E7EB);
    try {
      final hex = hexColor.replaceFirst('#', '');
      final color = Color(int.parse('FF$hex', radix: 16));
      // Rend la couleur pastel (plus claire)
      return Color.lerp(color, Colors.white, 0.7)!;
    } catch (_) {
      return const Color(0xFFE5E7EB);
    }
  }
}
