# Système de gamification SIKA

## Objectif du système

Le système de gamification de SIKA sert à encourager les bonnes habitudes financières. Il transforme les actions clés de l'utilisateur en points d'expérience (XP), puis utilise ces XP pour attribuer un rang, afficher une progression, déclencher des animations et alimenter un classement temps réel.

Le système est implémenté principalement dans :

- `lib/features/analytics/domain/models/rank_model.dart`
- `lib/features/analytics/data/services/xp_service.dart`
- `lib/features/analytics/data/services/rank_service.dart`
- `lib/features/analytics/data/providers/rank_providers.dart`
- `lib/features/transactions/presentation/screens/home_screen.dart`

## Boucle principale

1. L'utilisateur réalise une action financière dans l'application.
2. Le code appelle `XPService().awardXP(...)` ou `XPService().awardCustomXP(...)`.
3. Les XP sont ajoutés au total local stocké via `SettingsService`.
4. Le total XP est plafonné à `10000`.
5. Le rang est recalculé via `RankDefinitions.getRankForXP(totalXP)`.
6. Si l'utilisateur est connecté, les XP et le rang sont synchronisés dans Supabase, table `user_ranks`.
7. L'interface affiche le rang, la progression et, si nécessaire, une animation de montée ou baisse de rang.
8. Le classement lit `user_ranks` en temps réel via Supabase Realtime.

## Actions qui donnent des XP

| Action technique | Libellé utilisateur | XP |
|---|---:|---:|
| `addTransaction` | Transaction ajoutée | 5 |
| `dailyLogin` | Connexion quotidienne | 3 |
| `streak7Days` | Streak 7 jours | 20 |
| `streak30Days` | Streak 30 jours | 100 |
| `createGoal` | Objectif créé | 10 |
| `feedGoal` | Objectif alimenté | 15 |
| `reachGoal` | Objectif atteint | 50 |
| `createBudget` | Budget créé | 10 |
| `respectBudget` | Budget respecté | 25 |
| `addDebt` | Engagement ajouté | 5 |
| `payDebt` | Engagement réglé | 20 |
| `addAccount` | Compte ajouté | 15 |
| `healthScoreBonus` | Bonus santé financière | 10 dans la table, mais le code utilise un bonus dynamique |

## Déclencheurs observés dans le code

### Transactions

Quand une transaction manuelle est ajoutée, `TransactionRepositoryImpl.addManualTransaction` attribue :

- `addTransaction` : +5 XP.

### Comptes

Quand un compte est créé via `AccountRepository.createAccount`, le système attribue :

- `addAccount` : +15 XP.

### Budgets

Quand un budget global mensuel est créé pour la première fois via `BudgetRepository.createOrUpdateGlobalBudget`, le système attribue :

- `createBudget` : +10 XP.

Dans l'accueil, `_checkBudgetRespect` vérifie le budget global et les sous-budgets. Si un budget n'est pas dépassé, le système attribue :

- `respectBudget` : +25 XP par budget respecté.

Si un budget est dépassé, le code déclenche une notification de dépassement au lieu d'attribuer l'XP.

### Objectifs d'épargne

Quand un objectif est créé via `GoalRepository.addGoal`, le système attribue :

- `createGoal` : +10 XP.

Quand un objectif est alimenté via `GoalRepository.feedGoal`, le système attribue :

- `feedGoal` : +15 XP.

Quand un objectif devient complété via `GoalRepository.addSavings`, le système attribue :

- `reachGoal` : +50 XP.

Lorsqu'un objectif est supprimé avec remboursement via `deleteGoalWithRefund`, le code attribue aussi :

- `feedGoal` : +15 XP.

### Dettes, créances et factures

Quand une dette/facture est ajoutée via `DebtRepositoryImpl.addDebt`, le système attribue :

- `addDebt` : +5 XP.

Quand une dette/facture est marquée comme payée via `DebtRepositoryImpl.markAsPaid`, le système attribue :

- `payDebt` : +20 XP.

### Connexion quotidienne et streak

Dans l'accueil, `_checkRankTransition` appelle `XPService().checkDailyLogin()`.

Cette méthode :

- attribue `dailyLogin` : +3 XP si l'utilisateur ne s'est pas déjà connecté aujourd'hui ;
- augmente le streak si la dernière connexion date d'hier ;
- remet le streak à 1 si l'utilisateur revient après plus d'un jour ;
- attribue `streak7Days` : +20 XP quand le streak atteint exactement 7 jours ;
- attribue `streak30Days` : +100 XP quand le streak atteint exactement 30 jours.

### Bonus de santé financière

Dans `HomeScreen._checkRankTransition`, le score de santé financière est stocké puis converti en bonus :

```text
healthBonus = round(healthScore / 10)
```

Si ce bonus est supérieur à 0, le code appelle :

```text
awardCustomXP(healthBonus, 'Bonus santé financière')
```

Le bonus dépend donc du score courant, avec une valeur attendue de 1 à 10 XP pour un score de 10 à 100.

## Rangs

Les rangs sont définis statiquement dans `RankDefinitions.all`.

| Niveau | Rang | Seuil XP | Label carte |
|---:|---|---:|---|
| 1 | Novice | 0 à 2499 XP | STANDARD |
| 2 | Apprenti Économe | 2500 à 4999 XP | SILVER |
| 3 | Gestionnaire | 5000 à 7499 XP | GOLD |
| 4 | Stratège | 7500 à 9999 XP | PLATINUM |
| 5 | Sika Boss | 10000 XP | BLACK |

Le rang est calculé en parcourant les seuils du plus haut vers le plus bas. Le premier rang dont `minXP` est inférieur ou égal au total XP est retenu.

## Progression dans un rang

Chaque rang expose deux méthodes :

- `progressInRank(int xp)` : retourne une progression de `0.0` à `1.0`.
- `xpToNextRank(int xp)` : retourne le nombre d'XP restant avant le rang suivant.

Pour le niveau 5, `xpToNextRank` retourne `0`, car c'est le rang maximum.

## Transitions de rang

Le système détecte les transitions via :

```text
RankDefinitions.detectTransition(oldXP, newXP)
```

Il compare le rang avant et après changement d'XP :

- si le nouveau niveau est supérieur, la transition est `levelUp`;
- si le nouveau niveau est inférieur, la transition est `levelDown`;
- si le niveau ne change pas, aucune transition n'est retournée.

Dans l'accueil, la transition est aussi vérifiée à partir du `previousRankLevel` stocké dans `SettingsService`.

UI associée :

- `LevelUpOverlay.show(...)` pour une montée de rang.
- `LevelDownNotification.show(...)` pour une baisse de rang.
- `RankBadgeWidget` pour afficher le badge de rang.
- `HealthScoreCard` pour afficher score, XP et progression.

## Score de santé financière

Le score de santé financière est calculé sur 100 points. Le code de l'accueil et de l'analyse utilise les composantes suivantes :

| Composante | Poids max | Logique déduite |
|---|---:|---|
| Taux d'épargne | 30 | Plus l'épargne mensuelle représente une part élevée des revenus, plus le score monte. |
| Ratio dépenses | 20 | Des dépenses plus faibles par rapport aux revenus améliorent le score. |
| Ratio dette | 20 | Des dettes/factures faibles par rapport aux revenus améliorent le score. |
| Coussin de sécurité | 20 | Le score augmente selon le nombre de mois de dépenses couverts par les soldes. |
| Diversification des comptes | 10 | 2 comptes donnent 5 points, 3 comptes ou plus donnent 10 points. |

Ce score influence :

- l'affichage de santé financière ;
- la synchronisation cloud dans `user_ranks.health_score` ;
- le bonus XP dynamique via `healthScore / 10`.

## Classement

Le classement est géré par `RankService` et la table Supabase `user_ranks`.

### Données synchronisées

À chaque synchronisation de rang, le code upsert :

- `user_id`
- `total_xp`
- `health_score`
- `rank_level`
- `rank_name`
- `display_name`
- `avatar_url`
- `updated_at`

### Lecture du classement

Le classement récupère les 50 meilleurs utilisateurs :

```text
order by total_xp desc
limit 50
```

Le classement temps réel utilise :

```text
Supabase stream sur user_ranks avec primaryKey: ['user_id']
```

L'écran `LeaderboardScreen` affiche :

- le top 3 en podium ;
- les autres utilisateurs en liste ;
- un style distinct pour l'utilisateur courant ;
- le rang, le niveau et le total XP.

## Stockage local

Les valeurs de gamification locales sont stockées via `SettingsService`, qui repose sur `SharedPreferences`.

Données utilisées :

- total XP ;
- streak quotidien ;
- date de dernière connexion ;
- niveau de rang précédent ;
- score de santé ;
- dernier mois de vérification du budget.

## Restauration cloud

`AutoSyncService.restoreFromCloud()` appelle `_restoreXP`, qui lit la table Supabase `user_ranks` pour récupérer `total_xp`, puis le sauvegarde localement via `SettingsService.setTotalXP`.

La restauration cloud actuelle ne restaure pas explicitement le streak, le dernier login ou le niveau précédent depuis Supabase.

## Règles de plafonnement

Le total XP est plafonné dans `XPService` :

```text
newXP = (currentXP + points).clamp(0, 10000)
```

Conséquence :

- l'utilisateur ne peut pas dépasser 10000 XP ;
- 10000 XP correspond au rang maximum `Sika Boss`.

## Points d'attention

1. Le bonus de santé financière peut être attribué à chaque passage par l'accueil selon l'état de `_rankChecked`, sans garde quotidienne visible comparable à `dailyLogin`.
2. `healthScoreBonus` existe dans `ActionType`, mais le code utilise surtout `awardCustomXP(healthBonus, ...)`.
3. Les XP de respect du budget sont vérifiés une fois par mois via `lastBudgetCheckMonth`, mais la clé utilisée correspond au mois courant.
4. Le score de santé financière est calculé dans plusieurs écrans, ce qui peut créer des divergences.
5. Les XP sont synchronisés vers Supabase à chaque attribution, ce qui peut générer plusieurs upserts rapprochés.
6. Le classement dépend de la présence et de la sécurité RLS de la table `user_ranks`, mais le script SQL principal analysé ne décrit pas complètement cette table.
7. Le code permet une transition `levelDown`, mais le flux d'attribution XP ne diminue pas les XP. Une baisse ne peut donc venir que d'une restauration, modification externe ou reset.

## Recommandations spécifiques

1. Centraliser le calcul du score de santé financière dans un service unique.
2. Ajouter une garde quotidienne ou mensuelle claire pour le bonus de santé financière.
3. Documenter et migrer officiellement la table Supabase `user_ranks`.
4. Ajouter une table locale ou cloud d'historique des gains XP pour auditer les points.
5. Afficher à l'utilisateur les raisons récentes de gain XP.
6. Débouncer la synchronisation du rang pour éviter plusieurs upserts successifs.
7. Ajouter des tests unitaires pour les seuils de rang, les streaks, le plafonnement à 10000 XP et le respect budget.

