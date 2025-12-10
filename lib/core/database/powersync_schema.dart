import 'package:powersync/powersync.dart';

/// Schéma PowerSync pour SIKA
///
/// Définit les tables qui seront synchronisées entre le local et le cloud.
/// Doit correspondre exactement aux tables Supabase.
const schema = Schema([
  // Table des catégories
  Table('categories', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('icon_key'),
    Column.text('color'),
    Column.text('keywords_json'),
    Column.text('parent_id'),
    Column.integer('is_system'),
    Column.real('budget_limit'),
    Column.integer('sort_order'),
    Column.integer('sync_status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Table des comptes
  Table('accounts', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('type'),
    Column.real('balance'),
    Column.text('currency'),
    Column.text('phone_number'),
    Column.text('icon_key'),
    Column.text('color'),
    Column.integer('is_default'),
    Column.integer('is_active'),
    Column.integer('sync_status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Table des transactions
  Table('transactions', [
    Column.text('user_id'),
    Column.real('amount'),
    Column.text('type'),
    Column.text('merchant_name'),
    Column.text('category_id'),
    Column.text('account_id'),
    Column.text('date'),
    Column.text('sms_sender'),
    Column.text('sms_raw_content'),
    Column.text('external_id'),
    Column.integer('is_ai_categorized'),
    Column.integer('sync_status'),
    Column.integer('validation_status'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  // Table des objectifs
  Table('goals', [
    Column.text('user_id'),
    Column.text('name'),
    Column.real('target_amount'),
    Column.real('saved_amount'),
    Column.text('icon_key'),
    Column.text('deadline'),
    Column.integer('is_completed'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
]);
