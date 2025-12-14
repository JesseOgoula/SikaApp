// Supabase Edge Function: delete-user
// Déployer avec: supabase functions deploy delete-user
// 
// Cette fonction supprime l'utilisateur de Supabase Auth
// Elle doit être appelée par l'utilisateur authentifié lui-même

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Créer le client Supabase avec le service_role (admin)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Récupérer le token JWT de l'utilisateur
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')

    // Vérifier l'utilisateur
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'User not found or invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = user.id

    console.log(`Deleting user: ${userId}`)

    // 1. Supprimer les données de l'utilisateur dans les tables
    await supabaseAdmin.from('transactions').delete().eq('user_id', userId)
    await supabaseAdmin.from('goals').delete().eq('user_id', userId)
    await supabaseAdmin.from('categories').delete().eq('user_id', userId)
    
    try {
      await supabaseAdmin.from('accounts').delete().eq('user_id', userId)
    } catch (e) {
      console.log('Accounts table may not exist:', e)
    }

    console.log('User data deleted from tables')

    // 2. Supprimer l'utilisateur de Supabase Auth
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId)

    if (deleteError) {
      console.error('Error deleting auth user:', deleteError)
      return new Response(
        JSON.stringify({ error: 'Failed to delete auth user', details: deleteError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log('Auth user deleted successfully')

    return new Response(
      JSON.stringify({ success: true, message: 'User deleted successfully' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
