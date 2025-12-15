-- =============================================================================
-- SIKA - Fonction de suppression de compte utilisateur
-- =============================================================================
-- Cette fonction permet à un utilisateur de supprimer son propre compte
-- À exécuter dans Supabase Dashboard > SQL Editor
-- =============================================================================

-- 1. Créer la fonction RPC pour supprimer le compte utilisateur
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id uuid;
  result json;
BEGIN
  -- Récupérer l'ID de l'utilisateur connecté
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'User not authenticated');
  END IF;

  -- 1. Supprimer les transactions de l'utilisateur
  DELETE FROM public.transactions WHERE user_id = current_user_id;
  
  -- 2. Supprimer les objectifs de l'utilisateur
  DELETE FROM public.goals WHERE user_id = current_user_id;
  
  -- 3. Supprimer les catégories de l'utilisateur
  DELETE FROM public.categories WHERE user_id = current_user_id;
  
  -- 4. Supprimer les comptes de l'utilisateur (si la table existe)
  BEGIN
    DELETE FROM public.accounts WHERE user_id = current_user_id;
  EXCEPTION WHEN undefined_table THEN
    -- La table n'existe pas, on ignore
    NULL;
  END;

  -- 5. Supprimer l'utilisateur de auth.users
  -- Note: Cette opération nécessite SECURITY DEFINER et accès à auth schema
  DELETE FROM auth.users WHERE id = current_user_id;

  result := json_build_object(
    'success', true,
    'message', 'User account deleted successfully',
    'user_id', current_user_id::text
  );
  
  RETURN result;
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'user_id', current_user_id::text
  );
END;
$$;

-- 2. Donner les permissions pour appeler cette fonction
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

-- 3. Ajouter un commentaire descriptif
COMMENT ON FUNCTION public.delete_user_account() IS 
'Supprime le compte utilisateur courant et toutes ses données. IRRÉVERSIBLE!';
