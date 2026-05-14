const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://zioljqtwcoqvkojohpzl.supabase.co';

const supabaseKey = 'sb_publishable_MJREutfgMmp6RYzEcMQpWQ_aQKinL0p';

const supabase = createClient(supabaseUrl, supabaseKey);

module.exports = supabase;