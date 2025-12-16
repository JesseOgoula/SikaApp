-- =============================================================================
-- SIKA - Script SQL Supabase : Gestion des Dettes et Factures
-- Phase 21: Financial Commitments
-- =============================================================================
-- Ce script crée la table 'debts' pour gérer les dettes et factures
-- À exécuter dans l'éditeur SQL de Supabase Dashboard
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Table: debts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.debts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL CHECK (char_length(name) >= 1 AND char_length(name) <= 100),
    amount REAL NOT NULL CHECK (amount >= 0),
    
    -- Type d'engagement :
    -- 'debt_in'  : On me doit de l'argent (Créance)
    -- 'debt_out' : Je dois de l'argent (Dette)
    -- 'bill'     : Facture récurrente ou unique (Loyer, Abonnement...)
    type TEXT NOT NULL CHECK (type IN ('debt_in', 'debt_out', 'bill')),
    
    due_date TIMESTAMPTZ NOT NULL,
    
    -- Statut :
    -- 'pending' : En attente / Non payé
    -- 'paid'    : Payé / Réglé
    -- 'overdue' : En retard (calculé, mais peut être stocké pour cache)
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
    
    person_name TEXT, -- Nom de la personne (pour dettes) ou organisme (pour factures)
    notes TEXT,
    
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_rule TEXT, -- Ex: 'monthly', 'weekly' (optionnel pour v1)
    
    notification_id INTEGER, -- ID pour la notification locale
    
    sync_status INTEGER DEFAULT 0, -- Pour PowerSync
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_debts_user_id ON public.debts(user_id);
CREATE INDEX IF NOT EXISTS idx_debts_due_date ON public.debts(due_date);
CREATE INDEX IF NOT EXISTS idx_debts_status ON public.debts(status);

COMMENT ON TABLE public.debts IS 'Engagements financiers : Dettes, Créances et Factures';

-- -----------------------------------------------------------------------------
-- 2. Sécurité RLS (Row Level Security)
-- -----------------------------------------------------------------------------
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;

-- SELECT
CREATE POLICY "Users can view their own debts"
    ON public.debts FOR SELECT
    USING (auth.uid() = user_id);

-- INSERT
CREATE POLICY "Users can insert their own debts"
    ON public.debts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- UPDATE
CREATE POLICY "Users can update their own debts"
    ON public.debts FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- DELETE
CREATE POLICY "Users can delete their own debts"
    ON public.debts FOR DELETE
    USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 3. Triggers (Automatisation)
-- -----------------------------------------------------------------------------

-- Trigger pour user_id automatique
DROP TRIGGER IF EXISTS trigger_debts_user_id ON public.debts;
CREATE TRIGGER trigger_debts_user_id
    BEFORE INSERT ON public.debts
    FOR EACH ROW EXECUTE FUNCTION public.auto_set_user_id();

-- Trigger pour updated_at automatique
DROP TRIGGER IF EXISTS trigger_debts_updated_at ON public.debts;
CREATE TRIGGER trigger_debts_updated_at
    BEFORE UPDATE ON public.debts
    FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();

-- -----------------------------------------------------------------------------
-- 4. Permissions
-- -----------------------------------------------------------------------------
GRANT ALL ON public.debts TO authenticated;

-- Confirmation
SELECT 'Table debts créée avec succès' as result;
