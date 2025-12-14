/// Utilitaires pour la gestion du temps et des salutations
library;

/// Retourne un message de salutation basé sur l'heure actuelle
///
/// - 5h00 - 17h59 : "Bonjour"
/// - 18h00 - 4h59 : "Bonsoir"
String getGreetingMessage([DateTime? now]) {
  final currentTime = now ?? DateTime.now();
  final hour = currentTime.hour;

  // Entre 5h et 17h inclus -> Bonjour
  // Entre 18h et 4h inclus -> Bonsoir
  if (hour >= 5 && hour <= 17) {
    return 'Bonjour';
  } else {
    return 'Bonsoir';
  }
}

/// Retourne un emoji basé sur l'heure actuelle
String getGreetingEmoji([DateTime? now]) {
  final currentTime = now ?? DateTime.now();
  final hour = currentTime.hour;

  if (hour >= 5 && hour < 12) {
    return '☀️'; // Matin
  } else if (hour >= 12 && hour < 18) {
    return '🌤️'; // Après-midi
  } else if (hour >= 18 && hour < 21) {
    return '🌆'; // Soir
  } else {
    return '🌙'; // Nuit
  }
}

/// Extrait le prénom d'un nom complet
String getFirstName(String? fullName) {
  if (fullName == null || fullName.isEmpty) {
    return 'Utilisateur';
  }

  // Prend le premier mot du nom complet
  final parts = fullName.trim().split(' ');
  return parts.first;
}
