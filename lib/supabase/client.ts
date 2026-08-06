import { createBrowserClient } from '@supabase/ssr';

/**
 * Browser Supabase client — a single shared instance, reused across the
 * whole page instead of a fresh client per call. Every component that
 * used to call createClient() was creating (and logging) a brand new
 * client on every render; on a small hosting container that adds up
 * fast and was very likely contributing to the server running out of
 * memory and crashing (exit code 128 in the runtime logs). The debug
 * console.log lines that printed the Supabase URL/key on every single
 * call are removed for the same reason — they were never meant to stay
 * in past the very first setup step.
 */
let browserClient: ReturnType<typeof createBrowserClient> | null = null;

export function createClient() {
  if (browserClient) return browserClient;

  browserClient = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  return browserClient;
}
