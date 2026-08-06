import { createClient as createSupabaseClient } from '@supabase/supabase-js';

/**
 * Admin (service-role) Supabase client — bypasses RLS entirely. Used
 * only in trusted server-side code like the Stripe webhook, which needs
 * to write an order row without a signed-in user's session (Stripe
 * calls this endpoint directly, there's no browser session involved).
 * Never import this into anything that runs in the browser.
 */
let _admin: ReturnType<typeof createSupabaseClient> | null = null;

export function createAdminClient() {
  if (_admin) return _admin;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not set.'
    );
  }

  _admin = createSupabaseClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return _admin;
}
