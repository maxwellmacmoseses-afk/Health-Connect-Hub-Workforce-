const SUPABASE_URL = "https://vnocplsafzgzucixeswi.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_uA5yLqZx1TmZQkkWhXrUrw_yECndg_d";

const supabaseClient = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);
