const { createClient } = require('@supabase/supabase-js');

const supabaseNew = createClient(
  process.env.SUPABASE_NEW_URL,
  process.env.SUPABASE_NEW_SECRET_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  }
);

module.exports = supabaseNew;