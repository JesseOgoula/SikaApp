# Recommandations produit, performance et sécurité

## Améliorations produit

1. Clarifier le mode local
   - Le contrôleur d'authentification expose `skipLogin`, mais une partie importante de la synchronisation, du classement et des restaurations dépend de Supabase. Il faudrait définir explicitement ce qui fonctionne hors compte cloud et adapter l'interface aux limites du mode local.

2. Finaliser la cohérence des suppressions offline
   - Les suppressions de transactions et objectifs sont faites localement puis tentées sur Supabase. Si l'utilisateur est offline, le cloud peut conserver l'élément supprimé. Ajouter une table/file locale de suppressions en attente avec retry.

3. Harmoniser PowerSync et AutoSync
   - Le projet contient un schéma PowerSync, des dépendances PowerSync et des providers de statut, mais `main.dart` indique une synchronisation directe Supabase. Décider d'une seule stratégie de synchronisation pour réduire la complexité et les risques de divergence.

4. Étendre le PRD cloud aux tables réellement utilisées
   - Le SQL principal couvre `categories`, `accounts`, `transactions`, `goals`, `debts`, mais le code utilise aussi `budgets` et `user_ranks`. Ajouter les scripts SQL complets, politiques RLS, index et triggers pour ces tables.

5. Améliorer la gestion des récurrences
   - Les dettes/factures ont `isRecurring` et `recurrenceRule`, mais le code visible ne génère pas automatiquement les prochaines occurrences. Ajouter un moteur de récurrence fiable.

6. Ajouter une catégorisation locale automatique
   - Les catégories stockent des mots-clés JSON pour du smart labeling, mais l'ajout manuel ne semble pas exploiter ces mots-clés pour pré-catégoriser une note ou un reçu. Utiliser ces mots-clés avant ou en complément de l'IA distante.

7. Rendre le coach IA plus visible
   - Le service Gemini et un widget `ai_insight_card` existent, mais le parcours produit pourrait mieux intégrer les conseils IA dans l'analyse ou l'accueil avec états de chargement, erreur et rafraîchissement.

8. Mieux séparer facture, dette sortante et créance
   - Le paiement d'une dette crée toujours une dépense si un compte est fourni. Pour une créance encaissée, il faudrait créer un revenu.

## Performance

1. Remplacer certaines agrégations en mémoire par des requêtes SQL
   - Plusieurs totaux sont calculés en chargeant les lignes puis en faisant des `fold` côté Dart. Pour les gros volumes, privilégier des agrégations SQL Drift : `SUM`, `GROUP BY`, filtres par date et catégorie.

2. Indexer les tables locales sur les requêtes fréquentes
   - La table Supabase `transactions` a des index, mais les tables Drift locales déclarent peu d'index. Ajouter des index locaux sur `date`, `type`, `categoryId`, `accountId`, `syncStatus`, `dueDate` et `status`.

3. Éviter les scans complets en synchronisation
   - `AutoSyncService` synchronise tous les comptes et tous les objectifs, alors que d'autres tables utilisent `syncStatus`. Ajouter un `syncStatus` ou une stratégie `updatedAt` cohérente pour objectifs et comptes.

4. Paginer/restreindre les restaurations cloud
   - `restoreFromCloud` sélectionne toutes les données par table. Pour les comptes anciens, prévoir pagination, limite par date ou sync incrémentale.

5. Mutualiser les calculs de santé financière
   - La logique du score apparaît dans l'accueil et dans l'analyse. Extraire un service unique évitera les divergences et réduira le coût de maintenance.

6. Optimiser le scanner OCR
   - L'image est encodée entièrement en base64 et envoyée à OpenRouter. Ajouter validation de taille, compression explicite, timeout HTTP et messages d'erreur différenciés.

7. Réduire les appels cloud de XP/rang
   - `awardXP` synchronise immédiatement vers Supabase. Grouper ou débouncer certaines synchronisations pour éviter plusieurs upserts successifs lors de l'ouverture de l'accueil.

## Sécurité

1. Déplacer les identifiants hors du code source
   - `SupabaseConstants` contient l'URL Supabase, l'anon key et le Google Web Client ID en dur. Même si l'anon key n'est pas un secret serveur, centraliser ces valeurs dans `.env` facilite les rotations et environnements.

2. Retirer le DSN Sentry codé en dur
   - Le DSN Sentry est dans `main.dart`. Le charger depuis `.env` comme les clés IA.

3. Renforcer la suppression de compte
   - L'app appelle une RPC `delete_user_account`, tandis que le dépôt contient aussi une Edge Function `delete-user`. Choisir un mécanisme unique, documenté, testé, avec retour d'erreur explicite.

4. Restreindre le CORS de l'Edge Function
   - `delete-user` autorise `Access-Control-Allow-Origin: *`. Pour une fonction sensible utilisant un service role côté serveur, limiter les origines si elle est appelée depuis un client web ou documenter pourquoi l'ouverture est acceptable pour l'app mobile.

5. Compléter la suppression cloud
   - L'Edge Function `delete-user` supprime transactions, goals, categories et accounts, mais pas `debts`, `budgets` ni `user_ranks`. Cela peut laisser des données utilisateur après suppression du compte.

6. Ne pas laisser passer en cas d'échec critique de sécurité
   - `SecurityService` laisse passer si le contrôle d'intégrité ou la biométrie échoue par exception. Pour une app financière, prévoir une politique plus stricte ou au minimum un mode dégradé explicite.

7. Saler le PIN
   - Le PIN est hashé en SHA-256 sans sel visible. Ajouter un sel unique par installation/utilisateur, stocké en secure storage, ou utiliser un mécanisme KDF adapté.

8. Chiffrer réellement la base locale
   - `EncryptionUtils` génère une clé, mais `AppDatabase.encrypted` ignore la clé et la connexion SQLite actuelle n'utilise pas SQLCipher. Implémenter un stockage chiffré réel ou retirer l'illusion de chiffrement.

9. Réduire les logs sensibles
   - Certains logs mentionnent emails, tokens présents ou réponses IA brutes. Auditer les logs avant production pour éviter l'exposition de données financières ou personnelles.

10. Vérifier les politiques RLS de toutes les tables
   - Ajouter des tests SQL ou checks de migration pour garantir que chaque table utilisateur (`budgets`, `user_ranks` inclus) est protégée par RLS adaptée.

## Qualité et maintenabilité

1. Ajouter des tests de repositories
   - Tester les flux critiques : ajout de transaction, calcul de solde, alimentation d'objectif, paiement d'une dette, budget dépassé, sync pending.

2. Ajouter des tests de migration Drift
   - Le schéma local est en version 8. Les migrations devraient être testées depuis des versions antérieures avec données existantes.

3. Générer et valider les scripts Supabase
   - Mettre les migrations SQL sous une convention unique et vérifier qu'elles correspondent aux tables Drift et au schéma de synchronisation.

4. Uniformiser les types de dette
   - Le code convertit parfois `debtIn/debtOut` vers `debt_in/debt_out`, tandis que l'entité utilise aussi des enums. Standardiser le format en local et cloud.

5. Centraliser les formats monétaires et dates
   - Plusieurs méthodes formatent les montants manuellement. Créer un helper unique FCFA/XAF pour éviter les différences d'affichage.

6. Formaliser les états d'erreur utilisateur
   - Beaucoup de `catch` ignorent silencieusement les erreurs. Ajouter des retours UX pour les actions critiques : sync, suppression, restauration, OCR, notifications.

