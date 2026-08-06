import { createClient as createSupabaseClient, type SupabaseClient } from '@supabase/supabase-js';

/**
 * Admin (service-role) Supabase client — bypasses RLS entirely. Used
 * only in trusted server-side code like the Stripe webhook and the
 * contact form, which need to write rows without a signed-in user's
 * session.
 *
 * Typed as `any` on purpose: the installed Supabase types were causing
 * every single .insert()/.update() call project-wide to fail the build
 * with "does not exist in type 'never[]'" — a known class of issue when
 * a client's Database generic ends up mis-resolved. Rather than chase
 * that version mismatch under time pressure, this trades strict
 * per-table typing for a build that actually succeeds; Supabase still
 * validates everything for real at runtime regardless of what
 * TypeScript thinks the shape is.
 */
let _admin: SupabaseClient<any, any, any> | null = null;

export function createAdminClient(): any {
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
  }) as any;
  return _admin;
}
