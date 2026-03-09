# Cahier des Charges Technique et Fonctionnel (CDCF) — SIKA

> **Version** : 1.2.0  
> **Dernière mise à jour** : 17 février 2026  
> **Plateforme** : Android (prioritaire) — Flutter  
> **Marché cible** : Gabon / Afrique Centrale (devise FCFA/XAF)

---

## 1. Présentation Générale

**SIKA** est une application mobile de gestion financière personnelle conçue pour le marché gabonais et africain. Elle fonctionne en **mode offline-first** avec synchronisation cloud, intègre une **IA Coach financier** et un **scanner de factures par OCR** pour faciliter l'enregistrement des transactions.

---

## 2. Spécifications Fonctionnelles

### 2.1. Écran d'Accueil (HomeScreen)
- **Design Neo-Bank Pro** inspiré Apple Wallet / Revolut (1315 lignes).
- **Cartes de comptes dynamiques** : `PageView` horizontal avec un slide par compte, affichant le solde calculé en temps réel (balance initiale + ∑ transactions).
- **Health Score Badge** : Indicateur visuel de santé financière (0–100) intégré dans le header.
- **Quick Actions** : Accès rapide à l'ajout de transaction, objectif, dette.
- **Timeline des transactions récentes** avec tuiles cliquables.
- **Navigation Bottom Nav** : 4 onglets — Accueil, Transactions, Objectifs, Dettes.
- **Header personnalisé** : Salutation dynamique selon l'heure (Bonjour/Bonsoir) + prénom Google.

### 2.2. ~~Module d'Analyse SMS (Core)~~ — DÉPRÉCIÉ

> ⚠️ **SUPPRIMÉ** (mars 2026) : Ce module a été entièrement retiré suite aux contraintes OS (Android/iOS). Les packages `flutter_sms_inbox`, `easy_sms_receiver` et `permission_handler` sont **bannis** du projet. Toute la saisie passe désormais par la saisie manuelle et le scan OCR.

### 2.3. Module Transactions
- **CRUD complet** : Créer, Lire, Modifier, Supprimer.
- **Écran d'ajout** (1075 lignes) avec :
  - **NumberPad personnalisé** : Clavier numérique custom (pas de clavier système).
  - **TextPad personnalisé** : Clavier texte custom pour les notes.
  - **Sélection de catégorie** : Grille avec icônes FontAwesome et couleurs.
  - **Sélection de compte** : Liste des comptes actifs avec icône et solde.
  - **Sélection de date** : DatePicker natif.
  - **Scanner OCR de facture** (détail §2.8).
  - **Types** : Revenu (`income`), Dépense (`expense`).
- **Liste des transactions** : Triée par date, groupée par période.
- **Édition** : Écran dédié `EditTransactionScreen`.
- **Catégorisation IA** : Flag `isAiCategorized` pour les catégories assignées par le Smart Labeling.

### 2.4. Module Comptes Bancaires
- **Multi-comptes** : Gestion de plusieurs sources d'argent.
- **Types supportés** : Banque (`bank`), Mobile Money (`mobileMoney`), Espèces (`cash`).
- **Solde calculé dynamiquement** : Balance initiale + somme algébrique des transactions liées (`accountId`).
- **Solde total** : Agrégation de tous les comptes via `totalAccountsBalanceProvider`.
- **Devise** : XAF (FCFA) par défaut, extensible.
- **Détection pays/devise** : Helper `_getCountryAndCurrency` basé sur la locale.
- **Écran de configuration** : `AccountSetupScreen` pour l'ajout initial après connexion.
- **Vérification de setup** : `AccountSetupChecker` redirige vers le setup si aucun compte n'existe.

### 2.5. Module Objectifs d'Épargne
- **Création** : Nom, montant cible, date limite, icône personnalisable.
- **Alimentation** : Bottom sheet (`FeedGoalBottomSheet`) pour alimenter depuis un compte spécifique, avec vérification du solde disponible.
- **Transaction liée** : L'alimentation crée une transaction `expense` avec `accountId` pour déduire le solde du compte source.
- **Progression** : Barre de progression et pourcentage en temps réel.
- **Objectifs atteints** :
  - Restent visibles dans la liste (provider `watchAllGoals()`).
  - Style distinct : opacité 70%, fond gris `#F0F1F3`, pas d'ombre.
  - Touche de vert modérée : icône check, badge "Atteint" et barre de progression en `AppTheme.success`.
  - Texte (nom, montant) reste en gris `textSecondary`/`textPrimary`.
  - Tap désactivé (impossible d'alimenter un objectif complété).
  - Triés après les objectifs actifs (`ORDER BY is_completed ASC, created_at DESC`).
- **Synchronisation** : Champ `is_completed` synchronisé vers Supabase.

### 2.6. Module Dettes & Factures
- **Types** :
  - `bill` — Facture récurrente (loyer, abonnement, électricité…)
  - `debt_in` — Créance (on me doit)
  - `debt_out` — Dette (je dois)
- **Statuts** : `pending`, `paid`, `overdue`.
- **Récurrence** : Champ `isRecurring` + `recurrenceRule` (ex: `monthly`).
- **Rappels de notification** : ID notification stocké dans `notificationId`, programmés J-7, J-3, J-1, Jour J.
- **Écran d'ajout** : `AddDebtScreen` avec formulaire complet.
- **Écran liste** : `DebtsScreen` avec filtres par type/statut.

### 2.7. Module Budgets
- **Limites par catégorie** : Plafond de dépenses mensuel configurable dans `budget_limit` de la catégorie.
- **Table dédiée** : `BudgetsTable` pour stockage persistant.
- **Suivi** : Barre de progression consommé vs limite.
- **Indicateur de statut** : Widget `_buildBudgetStatusIndicator` dans le dashboard analytics.
- **Alertes** : Notification de dépassement de budget.
- **Écran** : `BudgetsScreen` accessible depuis le profil.

### 2.8. Module IA & Intelligence Artificielle

#### 2.8.1. Coach IA (Gemini 1.5 Flash)
- **Service** : `GeminiService` — singleton utilisant `google_generative_ai`.
- **Modèle** : `gemini-1.5-flash` (température 0.7, max 256 tokens).
- **Fonctionnalité** : Analyse des dépenses par catégorie et retourne 1 conseil personnalisé, contextuel au marché gabonais (FCFA, tutoiement).
- **Prompt** : Inclut total dépenses, revenus optionnels, répartition par catégorie en JSON.
- **Widget** : `AiInsightCard` — carte avec bouton "Analyser mes dépenses", loading state, affichage du conseil avec icône `lightbulb`.

#### 2.8.2. Scanner de Factures OCR (OpenRouter / Gemini 3 Flash)
- **Service** : `ReceiptScannerService` via API OpenRouter.
- **Modèle** : `google/gemini-3-flash-preview` (température 0.1, max 500 tokens).
- **Flux** :
  1. Capture photo via `image_picker` (caméra ou galerie).
  2. Encodage base64 de l'image.
  3. Envoi au modèle multimodal avec prompt structuré.
  4. Extraction JSON : montant (TTC en FCFA), description, catégorie suggérée.
  5. Pré-remplissage du formulaire d'ajout de transaction.
- **Result** : `ReceiptScanResult` (amount, description, suggestedCategory).

### 2.9. Module Analytics (Dashboard Premium)
- **Écran** : `StatisticsScreen` — 1418 lignes, design premium.
- **Sélecteur de période** : 24h, 7 jours, Ce mois, 3 mois, Année.
- **Financial Health Score** : Note 0–100 avec couleur progressive (rouge → vert), label (Critique/Faible/Moyenne/Bonne/Excellent), description contextuelle, jauge circulaire animée.
- **Vue d'ensemble** : Cartes revenus, dépenses, solde avec tendance (%).
- **Graphique LineChart** : Évolution du solde sur la période (fl_chart).
- **Graphique BarChart** : Dépenses par semaine/jour.
- **PieChart** : Répartition par catégorie.
- **Top dépenses** : Classement des plus grosses transactions.
- **Timeline** : Fil chronologique des transactions récentes.
- **Indicateur budgets** : Statut des budgets en cours.

### 2.10. Module Notifications Locales
- **Service** : `NotificationService` basé sur `flutter_local_notifications`.
- **Préférences** : `NotificationPreferences` — contrôle granulaire par type de notification.
- **Icône** : `ic_stat_notification` — logo Sika monochrome blanc sur fond transparent.
- **Style** : Textes épurés sans emojis, titres avec tiret cadratin, corps informatifs et concis.
- **Types** :
  - Rappels d'échéances dettes/factures (J-7, J-3, J-1, Jour J)
  - Alerte solde faible
  - Rappels d'objectifs d'épargne
  - Objectif atteint (célébration)
  - Résumé hebdomadaire (programmé + immédiat avec données)
  - Budget dépassé
- **Permissions** : Gestion Android 13+ (`POST_NOTIFICATIONS`).

### 2.11. Module Profil & Paramètres
- **Header** : Photo Google, prénom, email sur carte gradient Bleu Nuit.
- **Sections** :
  - Paramètres : Budgets, Notifications.
  - Données : Effacer toutes les données (local + cloud).
  - Compte : À propos, Déconnexion, Suppression de compte.
- **Popups uniformes** : Tous les dialogues de confirmation (suppression données, suppression compte, déconnexion, à propos) utilisent le même style épuré :
  - Icône gris `textSecondary`
  - Texte structuré sans emojis ni bullet points
  - Bouton Annuler en gris, bouton d'action en `primaryColor` Bleu Nuit arrondi
- **Notif Settings** : `NotificationSettingsScreen` (écran dédié).

### 2.12. Module Authentification
- **Provider** : Supabase Auth + Google Sign-In.
- **Écran** : `LoginScreen` — design Finance App moderne avec features preview.
- **Contrôleur** : `AuthController` (Riverpod) pour login/logout.
- **Repository** : `AuthRepository` — gestion auth, suppression compte, suppression données.
- **AuthGate** : Dans `main.dart` — stream `onAuthStateChange` pour basculer Login ↔ Home.

### 2.13. Module Sécurité
- **Biométrie** : `SecurityService` utilisant `local_auth` — empreinte digitale / Face Unlock.
- **Intégrité appareil** : Détection root/jailbreak via `safe_device`.
- **Privacy Shield** : `PrivacyShield` widget — masque le contenu avec le logo Sika Bleu Nuit quand l'app passe en arrière-plan (protection vie privée dans l'app switcher).
- **Splash Screen** : Écran de démarrage animé.

---

## 3. Architecture Technique

### 3.1. Stack Technologique

| Couche | Technologie | Version |
|--------|-------------|---------|
| **Framework** | Flutter (Dart) | SDK ^3.10.1 |
| **État** | Riverpod + flutter_riverpod | ^2.6.1 |
| **BDD Locale** | Drift (SQLite) | ^2.22.1 |
| **Sync Offline** | PowerSync | ^1.17.0 |
| **Backend (BaaS)** | Supabase (Auth, Database, Edge Functions) | ^2.8.0 |
| **Auth** | Google Sign-In + Supabase Auth | ^6.2.1 |
| **IA Coach** | Google Generative AI (Gemini 1.5 Flash) | ^0.4.6 |
| **OCR Scanner** | OpenRouter API (Gemini 3 Flash) via HTTP | ^1.2.2 |
| **Graphiques** | fl_chart | ^0.69.2 |
| **Icônes** | font_awesome_flutter | ^10.7.0 |
| **Police** | Google Fonts (Poppins) | ^6.3.3 |
| **Notifications** | flutter_local_notifications | ^18.0.1 |
| ~~SMS~~ | ~~flutter_sms_inbox + easy_sms_receiver~~ | **SUPPRIMÉ** (mars 2026) |
| **Background** | flutter_background_service | ^5.0.5 |
| **Sécurité** | local_auth, safe_device, flutter_secure_storage | — |
| **Connexion** | connectivity_plus | ^7.0.0 |
| **Caméra** | image_picker | ^1.1.2 |
| **Preferences** | shared_preferences | ^2.3.3 |
| **Génération code** | build_runner + drift_dev + riverpod_generator | — |

### 3.2. Architecture Clean Architecture (simplifiée)

```
lib/
├── core/
│   ├── constants/        # API keys, URLs Supabase
│   ├── database/         # Drift DB, tables, PowerSync schema, Supabase connector
│   ├── models/           # Modèles partagés
│   ├── providers/        # Providers globaux (PowerSync)
│   ├── services/         # Services transversaux (7 services)
│   ├── theme/            # AppTheme (couleurs, gradients, typography)
│   ├── utils/            # Logger, encryption
│   └── widgets/          # Widgets partagés (PrivacyShield)
├── features/
│   ├── accounts/         # Comptes bancaires
│   ├── ai_coach/         # IA Coach (Gemini)
│   ├── analytics/        # Dashboard statistiques
│   ├── auth/             # Authentification
│   ├── budgets/          # Budgets par catégorie
│   ├── debts/            # Dettes & factures
│   ├── goals/            # Objectifs d'épargne
│   ├── profile/          # Profil & paramètres
│   ├── splash/           # Splash screen
│   └── transactions/     # Transactions (Home, CRUD, widgets)
├── utils/                # Utilitaires (time_utils)
└── main.dart             # Entry point, providers, AuthGate
```

Chaque feature suit le pattern `data/` → `domain/` → `presentation/` (screens + widgets).

### 3.3. Modèle de Données (6 tables Drift)

| Table | Champs clés |
|-------|-------------|
| **TransactionsTable** | id (UUID), amount (REAL), type (income/expense), merchantName, categoryId (FK), accountId (FK), date, externalId (unique), isAiCategorized, validationStatus (0/1/2), syncStatus (0/1/2) |
| **CategoriesTable** | id, name, iconKey, color, keywordsJson, isSystem, budgetLimit, sortOrder, syncStatus |
| **AccountsTable** | id, name, type (bank/mobileMoney/cash), balance, currency (XAF), phoneNumber, iconKey, color, isDefault, isActive, syncStatus |
| **GoalsTable** | id, name, targetAmount, savedAmount, deadline, iconKey, isCompleted, syncStatus |
| **DebtsTable** | id, userId, name, amount, type (bill/debt_in/debt_out), dueDate, status (pending/paid/overdue), personName, notes, isRecurring, recurrenceRule, notificationId, syncStatus |
| **BudgetsTable** | id, categoryId, limit, spent, period |

### 3.4. Synchronisation

- **Couche 1 — Drift (local)** : Source de vérité. Toute écriture est locale d'abord.
- **Couche 2 — PowerSync** : Schéma de sync `powersync_schema.dart` + `SupabaseConnector`.
- **Couche 3 — AutoSyncService** :
  - Sync automatique au démarrage + retour réseau + intervalle 5 min.
  - `forceSync()` après chaque action utilisateur.
  - Entités synchronisées : catégories, transactions, comptes, dettes, objectifs.
  - Stratégie upsert vers Supabase (pas de diff, envoi complet).
- **Couche 4 — SyncService** : Service alternatif pour sync manuelle.
- **SettingsService** : Track du dernier sync (`lastSyncDate`).

### 3.5. Charte Graphique — Neo-Bank Pro

| Élément | Valeur |
|---------|--------|
| **Primaire (Bleu Nuit)** | `#1A237E` |
| **Secondaire (Ambre/Or)** | `#FFC107` |
| **Fond (Gris Perle)** | `#F4F6F8` |
| **Cartes** | `#FFFFFF` |
| **Texte principal** | `#1A1A2E` |
| **Texte secondaire** | `#6B7280` |
| **Succès (Vert)** | `#10B981` (usage modéré) |
| **Erreur (Rouge)** | `#EF4444` |
| **Gradient cartes premium** | `#1A237E` → `#311B92` |
| **Police** | Poppins (Google Fonts) |
| **Coins arrondis** | 20px (cartes), 12px (boutons), 24px (containers premium) |

### 3.6. Sécurité
- **Authentification** : JWT via Supabase Auth + Google OAuth.
- **RLS (Row Level Security)** : Politiques PostgreSQL — chaque utilisateur voit uniquement ses données.
- **Biométrie** : Empreinte digitale / Face Unlock au lancement.
- **Intégrité** : Détection root/jailbreak (bloque l'accès si compromis).
- **Privacy Shield** : Masquage du contenu avec logo Sika en arrière-plan.
- **Stockage sécurisé** : `flutter_secure_storage` pour clés sensibles.

---

## 4. Catégories par Défaut (Marché Gabonais)

L'app seed automatiquement des catégories système avec mots-clés pour le Smart Labeling :
- Alimentation, Transport, Logement, Santé, Éducation, Loisirs, Shopping, Communication & Internet, Énergie, Transferts, Revenus, Restaurant & Bar, Beauté & Soins, Épargne, Autres.

Chaque catégorie embarque : icône FontAwesome, couleur hex, keywords JSON pour catégorisation automatique.

---

## 5. Contraintes Techniques
- **Performance** : Slivers pour listes longues, Streams Drift pour réactivité instantanée.
- **Notifications** : Permission `POST_NOTIFICATIONS` Android 13+.
- **Connectivité** : `connectivity_plus` pour détecter le réseau et déclencher le sync.
- **Génération code** : `build_runner` obligatoire après modification des tables Drift ou des providers Riverpod.

---

## 6. Déploiement & Maintenance
- **Plateforme** : Android (APK signé, min SDK 21).
- **Infrastructure cloud** : Supabase (PostgreSQL + Auth + Edge Functions).
- **Version actuelle** : 1.0.0+1 (beta).
- **Monitoring** : Logs de services intégrés (`SikaLogger`) pour parsing, sync, OCR, et sécurité.
- **CI/CD** : Launcher icons (`flutter_launcher_icons`), native splash (`flutter_native_splash`).

---

## 7. Roadmap Technique (prévisionnel)

| Priorité | Fonctionnalité |
|----------|----------------|
| P1 | Tests unitaires et d'intégration |
| P1 | Support iOS |
| P2 | Exports & rapports PDF/CSV |
| P3 | Mode sombre (dark theme) |
| P3 | Widget Android (solde rapide) |
