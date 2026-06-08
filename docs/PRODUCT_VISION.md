# Vision produit SIKA

## Mission de l'application

SIKA est une application mobile de gestion financière personnelle, pensée autour du contexte gabonais et de la devise FCFA. Sa mission est d'aider l'utilisateur à comprendre, piloter et sécuriser son argent au quotidien en centralisant les comptes, les transactions, les budgets, les objectifs d'épargne, les dettes et les factures.

Le code montre une orientation "offline-first" : les données sont d'abord stockées localement dans SQLite via Drift, puis synchronisées vers Supabase quand l'utilisateur est connecté et que le réseau est disponible. L'application vise donc un usage fiable même dans des conditions de connectivité variables.

## Public cible déduit

- Particuliers au Gabon qui souhaitent suivre leurs revenus, dépenses et soldes en FCFA.
- Utilisateurs qui manipulent plusieurs sources d'argent : Airtel Money, Moov Money, UBA et espèces.
- Personnes qui veulent mieux anticiper leurs factures, dettes, créances et échéances.
- Utilisateurs mobiles qui ont besoin d'une saisie rapide, avec pavés numériques personnalisés, catégories visuelles et scanner de facture.
- Utilisateurs motivés par la progression, les scores, les rangs et un classement communautaire.

## Positionnement produit

SIKA se positionne comme un assistant financier personnel mobile, localisé pour les usages d'Afrique centrale. Le produit ne se limite pas à enregistrer des transactions : il calcule un score de santé financière, propose des analyses, accompagne l'épargne, rappelle les échéances et ajoute une couche de motivation via XP, rangs et classement.

## Cas d'usage principaux

1. Configurer ses comptes financiers
   - Sélection de comptes prédéfinis : Airtel Money, Moov Money, UBA, Cash.
   - Saisie des soldes initiaux.
   - Calcul dynamique du solde par compte à partir des transactions.

2. Enregistrer ses transactions
   - Ajout manuel de revenus ou dépenses.
   - Sélection d'une catégorie, d'un compte et d'une date.
   - Création de catégories personnalisées.
   - Scan de facture depuis la caméra ou la galerie avec extraction IA du montant, de la description et de la catégorie suggérée.

3. Suivre son activité financière
   - Vue d'accueil avec solde, comptes, activités récentes et score de santé.
   - Liste des transactions filtrable par période.
   - Analyse par période : 24h, 7 jours, mois courant, 3 mois, année.
   - Graphiques de dépenses, répartition par catégorie et évolution du solde.

4. Piloter son budget
   - Budget global mensuel.
   - Sous-budgets par catégorie.
   - Calcul du montant dépensé, du reste disponible et des dépassements.
   - Alertes de dépassement de budget.

5. Construire une épargne
   - Création d'objectifs avec montant cible, icône et date limite optionnelle.
   - Alimentation d'un objectif depuis un compte.
   - Création automatique d'une transaction d'épargne.
   - Notification et célébration quand un objectif est atteint.

6. Gérer les dettes, créances et factures
   - Création d'engagements financiers de type facture, dette sortante ou créance.
   - Suivi des statuts : pending, paid, overdue.
   - Rappels avant échéance.
   - Marquage comme payé avec création optionnelle d'une transaction.

7. Sécuriser l'accès
   - Connexion Google via Supabase Auth.
   - Mode local via contournement de la connexion.
   - Configuration obligatoire d'un PIN après authentification.
   - Déverrouillage biométrique optionnel.
   - Protection visuelle quand l'app passe en arrière-plan.
   - Refus d'exécution sur appareil rooté/jailbreaké détecté.

8. Rester engagé
   - Attribution d'XP pour les actions financières positives.
   - Rangs : Novice, Apprenti Économe, Gestionnaire, Stratège, Sika Boss.
   - Classement temps réel via Supabase Realtime.
   - Bonus liés à la connexion quotidienne, au score de santé et au respect du budget.

