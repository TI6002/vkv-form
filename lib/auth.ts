import { createClient } from '@/lib/supabase/server';

/**
 * Returns the signed-in user's profile (with role) or null.
 * "Admin" is just a row in public.profiles with role = 'admin' —
 * see supabase/schema.sql. Promote your own account by hand once
 * in the Supabase Table Editor after your first sign-up.
 */
export async function getCurrentProfile() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, email, role')
    .eq('id', user.id)
    .single();

  return profile ?? null;
}

export async function requireAdmin() {
  const profile = await getCurrentProfile();
  return profile?.role === 'admin' ? profile : null;
}
