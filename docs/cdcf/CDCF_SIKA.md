# Cahier des Charges Technique et Fonctionnel (CDCF) - SIKA

## 1. Spécifications Fonctionnelles

### 1.1. Module d'Analyse SMS (Core)
- **Détection** : Intercepter ou importer les SMS dont l'expéditeur appartient à la liste blanche (Airtel, Moov, UBAGAB).
- **Extraction** : Utiliser des expressions régulières (Regex) pour extraire le montant, le marchand/destinataire, le type (crédit/débit) et l'ID de transaction (TID/Ref).
- **Validation** : Permettre à l'utilisateur de valider manuellement une transaction suspecte ou de laisser l'enregistrement automatique pour les formats certifiés.

### 1.2. Module de Gestion Financière
- **Transactions** : CRUD complet (Créer, Lire, Mettre à jour, Supprimer).
- **Catégorisation** : Système de catégories avec icônes FontAwesome et couleurs dédiées.
- **Rapports** : Calculs automatiques des totaux par période (Jour, Semaine, Mois, Année).

### 1.3. Module de Synchronisation & Offline
- **Mode Offline** : Toutes les données sont écrites localement d'abord.
- **Sync** : Synchronisation bidirectionnelle dès qu'une connexion est disponible.
- **Suppression** : Option "Effacer tout" purgeant le local, le cache sync et le cloud.

## 2. Architecture Technique

### 2.1. Stack Technologique
- **Frontend** : Flutter (Dart) - Framework multi-plateforme.
- **Gestion d'État** : Riverpod - Pour une réactivité granulaire (StreamProviders).
- **Base de Données Locale** : Drift (SQLite) - Persistance performante.
- **Couche de Synchronisation** : PowerSync - Synchronisation SQLite <> Postgres.
- **Backend (BaaS)** : Supabase - Auth, Database (PostgreSQL), Edge Functions.

### 2.2. Modèle de Données (Schéma simplifié)
- **Transactions** : id, amount, category_id, type (income/expense/transfer), date, merchant, validation_status.
- **Categories** : id, name, icon, color, is_system.
- **Goals** : id, target_amount, saved_amount, deadline.
- **Debts** : id, contact_name, amount, due_date, type (bill/debt_in/debt_out).

### 2.3. Sécurité
- **Authentification** : JWT via Supabase Auth + Google Provider.
- **RLS (Row Level Security)** : Politiques PostgreSQL pour garantir que l'utilisateur ne voit que ses propres données.
- **Local Storage** : Chiffrement des clés sensibles si nécessaire.

## 3. Contraintes Techniques
- **Performance** : Utilisation de Slivers pour le défilement fluide des listes de transactions.
- **Réactivité** : Mise à jour instantanée des balances via Streams.
- **Parsing** : Robustesse des Regex face aux évolutions des formats SMS opérateurs.

## 4. Déploiement & Maintenance
- **Platforme cible** : Android (prioritaire pour la lecture automatique des SMS).
- **Infrastructure** : Cloud Supabase (Region : EU Central ou équivalent).
- **Monitoring** : Logs de services intégrés pour le débogage du parsing.
