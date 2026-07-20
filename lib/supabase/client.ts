import { createBrowserClient } from '@supabase/ssr';

/**
 * Supabase client for use in the browser (client components).
 * Reads the two PUBLIC env vars — safe to expose, protected by
 * Row Level Security policies defined in supabase/schema.sql.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
