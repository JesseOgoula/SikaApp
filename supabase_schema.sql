-- =============================================================================
-- SIKA - Script SQL Supabase
-- Phase 16: Backend Cloud PostgreSQL
-- =============================================================================
-- Ce script crée les tables miroirs de l'app locale avec sécurité RLS
-- À exécuter dans l'éditeur SQL de Supabase Dashboard
-- =============================================================================

-- =============================================================================
-- 1. EXTENSIONS
-- =============================================================================

-- Active l'extension pour générer des UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 2. TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table: categories
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL CHECK (char_length(name) >= 1 AND char_length(name) <= 50),
    icon_key TEXT DEFAULT 'category',
    color TEXT DEFAULT '#9E9E9E',
    keywords_json TEXT DEFAULT '{}',
    parent_id TEXT REFERENCES public.categories(id) ON DELETE SET NULL,
    is_system BOOLEAN DEFAULT FALSE,
    budget_limit REAL,
    sort_order INTEGER DEFAULT 0,
    sync_status INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);

-- Commentaire descriptif
COMMENT ON TABLE public.categories IS 'Catégories de transactions (Alimentation, Transport, etc.)';

-- -----------------------------------------------------------------------------
-- Table: budgets
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.budgets (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id text NOT NULL,
  category_name text NOT NULL,
  parent_budget_id uuid REFERENCES public.budgets(id) ON DELETE CASCADE,
  amount numeric(12,2) NOT NULL,
  period_type text NOT NULL DEFAULT 'monthly',
  start_date timestamptz NOT NULL,
  end_date timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  alert_threshold numeric(5,2) NOT NULL DEFAULT 80.0,
  sync_status smallint NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS budgets_user_id_idx ON public.budgets (user_id);
CREATE INDEX IF NOT EXISTS budgets_category_id_idx ON public.budgets (category_id);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own budgets"
  ON public.budgets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own budgets"
  ON public.budgets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own budgets"
  ON public.budgets FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own budgets"
  ON public.budgets FOR DELETE
  USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Table: user_ranks
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_ranks (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp integer NOT NULL DEFAULT 0,
  health_score integer NOT NULL DEFAULT 0,
  rank_level integer NOT NULL DEFAULT 1,
  rank_name text NOT NULL DEFAULT 'Novice',
  display_name text,
  avatar_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_ranks_total_xp_idx ON public.user_ranks (total_xp DESC);

ALTER TABLE public.user_ranks ENABLE ROW LEVEL SECURITY;

-- Tout le monde peut lire le classement
CREATE POLICY "Anyone can view user_ranks"
  ON public.user_ranks FOR SELECT
  USING (true);

-- Les utilisateurs peuvent modifier leur propre rang
CREATE POLICY "Users can update their own rank"
  ON public.user_ranks FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert their own rank"
  ON public.user_ranks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Table: accounts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.accounts (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL CHECK (char_length(name) >= 1 AND char_length(name) <= 100),
    type TEXT NOT NULL CHECK (type IN ('bank', 'mobileMoney', 'cash')),
    balance REAL DEFAULT 0.0,
    currency TEXT DEFAULT 'XAF',
    phone_number TEXT,
    icon_key TEXT DEFAULT 'wallet',
    color TEXT DEFAULT '#4CAF50',
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    sync_status INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts(user_id);

-- Commentaire descriptif
COMMENT ON TABLE public.accounts IS 'Comptes financiers (Bank, Mobile Money, Cash)';

-- -----------------------------------------------------------------------------
-- Table: transactions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    amount REAL NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    merchant_name TEXT,
    category_id TEXT REFERENCES public.categories(id) ON DELETE SET NULL,
    account_id TEXT REFERENCES public.accounts(id) ON DELETE SET NULL,
    to_account_id TEXT REFERENCES public.accounts(id) ON DELETE SET NULL,
    debt_id TEXT REFERENCES public.debts(id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL,
    sms_sender TEXT,
    sms_raw_content TEXT,
    external_id TEXT UNIQUE,
    is_ai_categorized BOOLEAN DEFAULT FALSE,
    sync_status INTEGER DEFAULT 0,
    validation_status INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(date);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON public.transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);

-- Commentaire descriptif
COMMENT ON TABLE public.transactions IS 'Transactions financières (revenus, dépenses, transferts)';

-- -----------------------------------------------------------------------------
-- Table: goals
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.goals (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    target_amount REAL NOT NULL,
    saved_amount REAL DEFAULT 0,
    icon_key TEXT,
    deadline TIMESTAMPTZ,
    is_completed BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_goals_user_id ON public.goals(user_id);

-- Commentaire descriptif
COMMENT ON TABLE public.goals IS 'Objectifs d''épargne de l''utilisateur';

-- =============================================================================
-- 3. SÉCURITÉ - ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- RLS pour categories
-- -----------------------------------------------------------------------------
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- Suppression des anciennes politiques si elles existent
DROP POLICY IF EXISTS "Users can view their own categories" ON public.categories;
DROP POLICY IF EXISTS "Users can insert their own categories" ON public.categories;
DROP POLICY IF EXISTS "Users can update their own categories" ON public.categories;
DROP POLICY IF EXISTS "Users can delete their own categories" ON public.categories;

-- Politique SELECT: Les utilisateurs ne voient que leurs propres catégories
CREATE POLICY "Users can view their own categories"
    ON public.categories FOR SELECT
    USING (auth.uid() = user_id);

-- Politique INSERT: Les utilisateurs ne peuvent créer que leurs propres catégories
CREATE POLICY "Users can insert their own categories"
    ON public.categories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Politique UPDATE: Les utilisateurs ne peuvent modifier que leurs propres catégories
CREATE POLICY "Users can update their own categories"
    ON public.categories FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Politique DELETE: Les utilisateurs ne peuvent supprimer que leurs propres catégories
CREATE POLICY "Users can delete their own categories"
    ON public.categories FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RLS pour accounts
-- -----------------------------------------------------------------------------
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can insert their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can update their own accounts" ON public.accounts;
DROP POLICY IF EXISTS "Users can delete their own accounts" ON public.accounts;

CREATE POLICY "Users can view their own accounts"
    ON public.accounts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own accounts"
    ON public.accounts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own accounts"
    ON public.accounts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own accounts"
    ON public.accounts FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RLS pour transactions
-- -----------------------------------------------------------------------------
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can update their own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can delete their own transactions" ON public.transactions;

CREATE POLICY "Users can view their own transactions"
    ON public.transactions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transactions"
    ON public.transactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own transactions"
    ON public.transactions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own transactions"
    ON public.transactions FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- RLS pour goals
-- -----------------------------------------------------------------------------
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own goals" ON public.goals;
DROP POLICY IF EXISTS "Users can insert their own goals" ON public.goals;
DROP POLICY IF EXISTS "Users can update their own goals" ON public.goals;
DROP POLICY IF EXISTS "Users can delete their own goals" ON public.goals;

CREATE POLICY "Users can view their own goals"
    ON public.goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own goals"
    ON public.goals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own goals"
    ON public.goals FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own goals"
    ON public.goals FOR DELETE
    USING (auth.uid() = user_id);

-- =============================================================================
-- 4. AUTOMATISATION - TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Fonction: auto_set_user_id
-- Remplit automatiquement user_id avec auth.uid() si non fourni
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_set_user_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- FORCER le user_id à celui de l'utilisateur authentifié.
  -- Ne jamais faire confiance à ce que le client envoie.
  NEW.user_id := auth.uid();
  RETURN NEW;
END;
$$;

-- -----------------------------------------------------------------------------
-- Fonction: auto_update_timestamp
-- Met à jour automatiquement updated_at lors d'une modification
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Triggers pour categories
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_categories_user_id ON public.categories;
CREATE TRIGGER trigger_categories_user_id
    BEFORE INSERT ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

DROP TRIGGER IF EXISTS trigger_categories_updated_at ON public.categories;
CREATE TRIGGER trigger_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- -----------------------------------------------------------------------------
-- Triggers pour accounts
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_accounts_user_id ON public.accounts;
CREATE TRIGGER tr_budgets_auto_set_user_id
  BEFORE INSERT ON public.budgets
  FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

CREATE TRIGGER tr_budgets_auto_update_timestamp
  BEFORE UPDATE ON public.budgets
  FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

CREATE TRIGGER tr_user_ranks_auto_update_timestamp
  BEFORE UPDATE ON public.user_ranks
  FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

CREATE TRIGGER tr_accounts_auto_set_user_id
    BEFORE INSERT ON public.accounts
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

DROP TRIGGER IF EXISTS trigger_accounts_updated_at ON public.accounts;
CREATE TRIGGER trigger_accounts_updated_at
    BEFORE UPDATE ON public.accounts
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- -----------------------------------------------------------------------------
-- Triggers pour transactions
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_transactions_user_id ON public.transactions;
CREATE TRIGGER trigger_transactions_user_id
    BEFORE INSERT ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

DROP TRIGGER IF EXISTS trigger_transactions_updated_at ON public.transactions;
CREATE TRIGGER trigger_transactions_updated_at
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- -----------------------------------------------------------------------------
-- Triggers pour goals
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_goals_user_id ON public.goals;
CREATE TRIGGER trigger_goals_user_id
    BEFORE INSERT ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

DROP TRIGGER IF EXISTS trigger_goals_updated_at ON public.goals;
CREATE TRIGGER trigger_goals_updated_at
    BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- =============================================================================
-- 5. GRANTS (Permissions pour le rôle anon/authenticated)
-- =============================================================================

-- Permissions pour les utilisateurs authentifiés
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON public.categories TO authenticated;
GRANT ALL ON public.accounts TO authenticated;
GRANT ALL ON public.transactions TO authenticated;
GRANT ALL ON public.goals TO authenticated;

-- -----------------------------------------------------------------------------
-- Table: debts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.debts (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL CHECK (char_length(name) >= 1 AND char_length(name) <= 100),
    amount REAL NOT NULL,
    paid_amount REAL DEFAULT 0,
    type TEXT NOT NULL, -- 'bill', 'debt_out', 'debt_in'
    due_date TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
    person_name TEXT,
    notes TEXT,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule TEXT,
    notification_id INTEGER,
    sync_status INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_debts_user_id ON public.debts(user_id);
CREATE INDEX IF NOT EXISTS idx_debts_status ON public.debts(status);
CREATE INDEX IF NOT EXISTS idx_debts_due_date ON public.debts(due_date);

-- Commentaire descriptif
COMMENT ON TABLE public.debts IS 'Dettes, créances et factures de l''utilisateur';

-- -----------------------------------------------------------------------------
-- RLS pour debts
-- -----------------------------------------------------------------------------
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;

-- Suppression des anciennes politiques si elles existent
DROP POLICY IF EXISTS "Users can view their own debts" ON public.debts;
DROP POLICY IF EXISTS "Users can insert their own debts" ON public.debts;
DROP POLICY IF EXISTS "Users can update their own debts" ON public.debts;
DROP POLICY IF EXISTS "Users can delete their own debts" ON public.debts;

CREATE POLICY "Users can view their own debts"
    ON public.debts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own debts"
    ON public.debts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own debts"
    ON public.debts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own debts"
    ON public.debts FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- Triggers pour debts
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_debts_user_id ON public.debts;
CREATE TRIGGER trigger_debts_user_id
    BEFORE INSERT ON public.debts
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

DROP TRIGGER IF EXISTS trigger_debts_updated_at ON public.debts;
CREATE TRIGGER trigger_debts_updated_at
    BEFORE UPDATE ON public.debts
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- Permissions
GRANT ALL ON public.debts TO authenticated;

-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================

-- Vérification: Affiche les tables créées
SELECT table_name, 
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as columns_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_name IN ('categories', 'accounts', 'transactions', 'goals', 'debts', 'budgets', 'user_ranks')
ORDER BY table_name;

-- =============================================================================
-- SYNC CONFLICT RESOLUTION (TIMESTAMP MERGE)
-- =============================================================================

-- Trigger de protection contre l'écrasement par des données locales obsolètes
CREATE OR REPLACE FUNCTION public.protect_newer_updates()
RETURNS TRIGGER AS $$
BEGIN
  -- Si l'enregistrement entrant (NEW) a un updated_at plus vieux que ce qu'on a
  -- déjà en base (OLD), on refuse silencieusement l'update (retourne OLD).
  IF NEW.updated_at < OLD.updated_at THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Application du trigger sur toutes les tables de données synchronisées
DROP TRIGGER IF EXISTS trigger_transactions_protect_newer ON public.transactions;
CREATE TRIGGER trigger_transactions_protect_newer
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();

DROP TRIGGER IF EXISTS trigger_accounts_protect_newer ON public.accounts;
CREATE TRIGGER trigger_accounts_protect_newer
    BEFORE UPDATE ON public.accounts
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();

DROP TRIGGER IF EXISTS trigger_categories_protect_newer ON public.categories;
CREATE TRIGGER trigger_categories_protect_newer
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();

DROP TRIGGER IF EXISTS trigger_goals_protect_newer ON public.goals;
CREATE TRIGGER trigger_goals_protect_newer
    BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();

DROP TRIGGER IF EXISTS trigger_debts_protect_newer ON public.debts;
CREATE TRIGGER trigger_debts_protect_newer
    BEFORE UPDATE ON public.debts
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();

DROP TRIGGER IF EXISTS trigger_budgets_protect_newer ON public.budgets;
CREATE TRIGGER trigger_budgets_protect_newer
    BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.protect_newer_updates();
