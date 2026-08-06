#!/usr/bin/env bash
set -e

if [ ! -f package.json ]; then
  echo "ERROR: no package.json here. cd into the project root first."
  exit 1
fi

echo "Applying vkv.form updates — remove debug logging + reuse a single Supabase client (fixes server crashes)..."

mkdir -p "lib/supabase"
cat > "lib/supabase/client.ts" << '__VKV_PATCH_EOF__'
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
__VKV_PATCH_EOF__
echo "  updated: lib/supabase/client.ts"

mkdir -p "lib/supabase"
cat > "lib/supabase/server.ts" << '__VKV_PATCH_EOF__'
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

/**
 * Server-side Supabase client — created fresh per request (it has to be,
 * since it reads/writes that specific request's cookies), but no longer
 * prints the URL/key to the logs on every single call. That debug
 * logging was left over from early setup and was flooding the runtime
 * logs on every page load in production.
 */
export function createClient() {
  const cookieStore = cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value;
        },
        set(name: string, value: string, options: any) {
          try {
            cookieStore.set({ name, value, ...options });
          } catch {
            // Called from a Server Component — safe to ignore since
            // middleware refreshes the session on navigation.
          }
        },
        remove(name: string, options: any) {
          try {
            cookieStore.set({ name, value: '', ...options });
          } catch {
            // Same as above.
          }
        },
      },
    }
  );
}
__VKV_PATCH_EOF__
echo "  updated: lib/supabase/server.ts"

echo "Done. git add -A && git commit -m \"Fix Supabase client: singleton + remove debug logging\" && git push"