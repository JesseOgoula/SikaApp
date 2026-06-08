# PRD fonctionnalités actuelles

## Vue d'ensemble technique

Le code source analysé correspond à une application Flutter nommée `sika_app`. Elle utilise Riverpod pour l'état applicatif, Drift/SQLite pour le stockage local, Supabase pour l'authentification et la synchronisation cloud, des notifications locales, Sentry/PostHog pour l'observabilité et Gemini/OpenRouter pour les fonctionnalités IA.

## Frontend Flutter

### Authentification et onboarding

- Écran de connexion Google connecté à Supabase Auth.
- Flux d'authentification local contrôlé par `AuthGate`.
- Possibilité de passer en mode local via `skipLogin`.
- Splash screen animé avec assets de marque.
- Configuration initiale obligatoire des comptes si aucun compte local/cloud n'est trouvé.
- Restauration des comptes et données depuis Supabase après connexion.

### Navigation principale

La navigation basse expose cinq sections :

- Accueil.
- Analyse.
- Transactions.
- Objectifs.
- Dettes.

Le profil et le classement sont accessibles depuis l'en-tête de l'accueil.

### Accueil

- Cartes de solde total et de soldes par compte.
- Masquage/affichage du montant.
- Calcul d'un score de santé financière.
- Affichage du rang et des XP.
- Actions rapides : ajouter une transaction, ajouter un objectif, ajouter une dette/facture.
- Activités récentes unifiant transactions, objectifs et dettes.
- Détection des changements de rang et affichage d'overlays de progression.
- Vérification du respect des budgets et déclenchement d'XP ou notifications.

### Transactions

- Ajout manuel de revenus ou dépenses.
- Montant en FCFA avec pavé numérique personnalisé.
- Saisie de note avec clavier texte personnalisé.
- Sélection de catégorie.
- Création de catégorie personnalisée depuis l'écran d'ajout.
- Sélection du compte source.
- Sélection d'une date.
- Blocage des dépenses supérieures au solde disponible calculé.
- Liste des transactions et édition/suppression via écrans dédiés.
- Filtres de période dans l'historique des transactions.

### OCR et IA facture

- Sélection d'image depuis la caméra ou la galerie.
- Compression/redimensionnement avant analyse.
- Appel OpenRouter avec modèle `google/gemini-3-flash-preview`.
- Extraction du montant, d'une description courte et d'une catégorie suggérée.
- Préremplissage automatique du formulaire de transaction.

### Analyse financière

- Sélecteur de période : 24h, 7 jours, mois courant, 3 mois, année.
- Résumé financier : solde net, revenus, dépenses, épargne, dettes.
- Score de santé financière sur 100.
- Répartition des dépenses par catégorie.
- Évolution du solde.
- Dépenses récentes.
- Timeline des opérations.
- Lien vers la gestion des budgets depuis l'analyse.

### Budgets

- Création ou mise à jour d'un budget global mensuel.
- Ajout ou mise à jour de sous-budgets par catégorie.
- Calcul du montant dépensé, du reste à dépenser, du pourcentage utilisé et des dépassements.
- Suppression de sous-budget.
- Suppression du budget global avec ses sous-budgets.

### Objectifs d'épargne

- Création d'objectif avec nom, montant cible, icône et deadline optionnelle.
- Liste des objectifs actifs et complétés.
- Alimentation d'un objectif depuis un compte.
- Création automatique d'une transaction de dépense catégorisée `cat-epargne`.
- Remboursement possible de l'épargne vers un compte lors d'une suppression.
- Notification de célébration à l'atteinte de l'objectif.
- Rappel hebdomadaire pour alimenter l'objectif.

### Dettes, créances et factures

- Création de dettes entrantes, dettes sortantes et factures.
- Champs : nom, montant, type, échéance, statut, personne/organisme, notes, récurrence, notification.
- Liste filtrée pour les factures/dettes.
- Marquage en payé.
- Création optionnelle d'une transaction lors du paiement.
- Mise à jour automatique des dettes en retard.
- Rappels locaux avant échéance.

### Profil et paramètres

- Affichage du profil Google : nom, email, avatar.
- Accès aux budgets, comptes, notifications et sécurité.
- Ajout de comptes après onboarding.
- Effacement de toutes les données utilisateur.
- Suppression du compte.
- Déconnexion.
- À propos avec version applicative.

### Notifications

- Activation globale des notifications.
- Rappels de dettes/factures configurables par jours avant échéance et heure.
- Alertes de solde faible avec seuil configurable.
- Alertes de dépassement de budget.
- Rappels hebdomadaires d'objectifs.
- Résumé hebdomadaire configurable par jour et heure.
- Notifications de célébration d'objectif atteint.

### Sécurité locale

- Configuration PIN à 4 chiffres.
- Stockage du hash du PIN dans `FlutterSecureStorage`.
- Activation/désactivation biométrique.
- Déverrouillage par empreinte lorsque disponible.
- Vérification d'intégrité de l'appareil avec `safe_device`.
- Écran d'alerte si l'appareil est rooté/jailbreaké.
- Re-verrouillage au retour au premier plan.
- Privacy shield sur pause/inactive pour masquer le contenu sensible.

### Gamification et classement

- XP attribués aux actions : transaction, connexion quotidienne, streak, objectif, budget, dette, compte, score de santé.
- Rangs de progression de 0 à 10000 XP.
- Classement top 50 basé sur `user_ranks`.
- Stream temps réel Supabase pour le leaderboard.
- Synchronisation du rang, du score de santé, du nom et de l'avatar.

## API et services externes

### Supabase Auth

- Connexion Google via `signInWithIdToken`.
- Écoute des changements d'état d'authentification.
- Déconnexion Supabase et Google.
- Suppression de données cloud liées à l'utilisateur.

### Supabase Database

Tables utilisées côté cloud :

- `categories`.
- `accounts`.
- `transactions`.
- `goals`.
- `debts`.
- `budgets`.
- `user_ranks`.

Le script SQL principal définit des politiques RLS pour `categories`, `accounts`, `transactions`, `goals` et `debts`. Le code applicatif utilise aussi `budgets` et `user_ranks`.

### Supabase Edge Function

- Fonction `delete-user`.
- Vérifie le JWT utilisateur.
- Supprime les données cloud dans plusieurs tables.
- Supprime l'utilisateur Supabase Auth avec une clé service role.
- CORS configuré avec `Access-Control-Allow-Origin: *`.

### Synchronisation

- `AutoSyncService` synchronise automatiquement au démarrage, au retour réseau et toutes les 5 minutes.
- Synchronisation des éléments en attente via `syncStatus == 0`.
- Upsert vers Supabase pour catégories, transactions, comptes, dettes, objectifs et budgets.
- Restauration cloud vers SQLite locale par table.
- `SyncService` fournit aussi une synchronisation manuelle globale pour catégories, transactions, objectifs et dettes.

### IA

- `GeminiService` utilise `gemini-1.5-flash` pour générer un conseil financier à partir des statistiques de dépenses.
- `ReceiptScannerService` utilise OpenRouter pour analyser une image de reçu/facture.
- Les clés Gemini/OpenRouter sont lues depuis `.env`.

### Observabilité et analytics

- Sentry est initialisé avec un DSN codé dans `main.dart`.
- PostHog est utilisé via `AnalyticsService`.
- Événements suivis : onboarding, création de compte, ajout de transaction, authentification.

## Base de données locale

### Moteur

- Drift sur SQLite.
- Fichier local : `sika_database.sqlite`.
- Version de schéma : 8.
- Tables locales déclarées : `transactions`, `accounts`, `categories`, `goals`, `debts`, `budgets`.

### Tables locales

#### `accounts`

- Comptes financiers.
- Types : `bank`, `mobileMoney`, `cash`.
- Solde initial, devise XAF, numéro mobile money, icône, couleur, compte actif/par défaut, statut de synchronisation.

#### `transactions`

- Revenus, dépenses ou transferts.
- Montant, marchand/description, catégorie, compte, date, external ID, catégorisation IA, statut de sync, statut de validation.
- Contrainte d'unicité sur `externalId`.

#### `categories`

- Catégories de transactions.
- Icône, couleur, mots-clés JSON, catégorie parente, catégorie système, limite de budget, ordre et sync.
- Seed initial de catégories adaptées au marché gabonais : Alimentation, Transport, Factures, Santé, Transferts, Loisirs, Épargne, Autre.

#### `goals`

- Objectifs d'épargne.
- Montant cible, montant épargné, icône, deadline, état complété.

#### `debts`

- Dettes, créances et factures.
- Type, échéance, statut, personne/organisme, notes, récurrence, notification locale, sync.

#### `budgets`

- Budget global et sous-budgets.
- Catégorie, parent, montant, période, dates, état actif, seuil d'alerte, sync.

## Contraintes et hypothèses visibles dans le code

- Devise par défaut : XAF/FCFA.
- Locale principale : `fr_FR`.
- Les comptes prédéfinis reflètent Airtel Money, Moov Money, UBA et Cash.
- PowerSync est présent dans les dépendances et un schéma existe, mais `main.dart` indique que PowerSync est désactivé au profit d'un `AutoSyncService` direct vers Supabase.
- Les suppressions offline ne sont pas toutes mises en file d'attente ; plusieurs TODO indiquent qu'une file de suppression reste à implémenter.

