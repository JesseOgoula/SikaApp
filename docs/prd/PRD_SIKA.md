# Product Requirements Document (PRD) - SIKA

## 1. Vision du Produit
**SIKA** est une application de gestion financière personnelle "Neo-Bank style" conçue spécifiquement pour le marché gabonais. Elle vise à simplifier radicalement le suivi des dépenses via la saisie manuelle assistée, le scan OCR de factures et la catégorisation intelligente par IA.

## 2. Problématique
Au Gabon, la majorité des transactions se font par Mobile Money ou cash. Les utilisateurs n'ont pas d'outil consolidé pour :
- Visualiser leur budget global.
- Catégoriser automatiquement leurs dépenses.
- Suivre leurs économies vers des objectifs précis.
- Anticiper les factures récurrentes (SEEG, loyers).

## 3. Objectifs Stratégiques
- **Simplicité** : Saisie rapide via NumberPad personnalisé et scan OCR de factures.
- **Accessibilité** : Fonctionnement hors-ligne prioritaire avec synchronisation cloud transparente.
- **Éducation Financière** : Fournir un "Financial Health Score" pour inciter à une meilleure gestion.

## 4. Personas
- **L'actif urbain** : Utilise Airtel Money quotidiennement pour tout (courses, taxi, factures).
- **L'étudiant/Freelance** : Reçoit des virements et doit gérer un budget serré.
- **Le petit entrepreneur** : Doit séparer ses dépenses personnelles des transactions liées à son activité.

## 5. Fonctionnalités Clés (MVP)
### 5.1. Onboarding & Auth
- Connexion via Google Sign-In.
- Qualification du profil (Ville, profession, revenus estimés).

### 5.2. Saisie de Transactions

> ⚠️ **DÉPRÉCIÉ** : Le module "Smart SMS Parser" (lecture automatique des SMS, `flutter_sms_inbox`, `easy_sms_receiver`, `permission_handler`) a été **supprimé** suite aux contraintes imposées par Android/iOS. Toute la saisie passe désormais par :

- Saisie manuelle via NumberPad personnalisé.
- Scan OCR de factures via l'IA (Gemini 3 Flash).
- Catégorisation intelligente par Smart Labeling IA.

### 5.3. Dashboard & Analyse
- Solde disponible dynamique (Revenus - Dépenses - Factures engagées).
- Graphiques par catégories (Alimentation, Transport, Shopping, etc.).
- Score de santé financière basé sur le ratio épargne/dépense.

### 5.4. Objectifs d'Épargne (Goals)
- Création d'objectifs avec barre de progression.
- Versement manuel ou via transactions catégorisées "Épargne".

### 5.5. Dettes & Factures
- Gestion des factures à venir (Bills) et des dettes (entrantes/sortantes).
- Notifications de rappel à échéance.

## 6. Guide de Style & UX
- **Couleurs** : Midnight Blue (#1A237E), Gold Amber (#FFC107).
- **Aesthetic** : Glassmorphism, cartes épurées, micro-animations fluides.
- **Typographie** : Poppins / Inter.

## 7. Indicateurs de Succès (KPIs)
- Nombre de transactions enregistrées par utilisateur.
- Fréquence d'utilisation du dashboard.
- Montant total épargné via la fonction "Goals".
