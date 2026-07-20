import { createClient as createSupabaseClient } from '@supabase/supabase-js';

/**
 * Admin/service-role Supabase client. This bypasses Row Level Security,
 * so it must NEVER be imported into a client component and the
 * SUPABASE_SERVICE_ROLE_KEY must never be prefixed with NEXT_PUBLIC_.
 *
 * Used for: the admin dashboard's product CRUD (after verifying the
 * caller is an admin) and the Stripe webhook that writes paid orders.
 */
export function createAdminClient() {
  return createSupabaseClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  );
}
