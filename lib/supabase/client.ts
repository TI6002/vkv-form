import { createBrowserClient } from '@supabase/ssr';

/**
 * Browser Supabase client — a single shared instance, reused across the
 * whole page instead of a fresh client per call.
 *
 * Typed as `any` on purpose — see lib/supabase/admin.ts for why: the
 * installed Supabase types were making every .insert()/.update() call
 * in the whole project fail the production build with a spurious
 * "does not exist in type 'never[]'" error.
 */
let browserClient: any = null;

export function createClient(): any {
  if (browserClient) return browserClient;

  browserClient = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  return browserClient;
}
